local rootfs = ...

local vfs = require("vfs")
local ramfs = require("ramfs")
local process = require("process")
local enlua = require("enlua")
local json = require("json")

local system = {}
system.initializedApps = {}
system.appDirs = {"/apps", "/user/apps"}
system.libDirs = {"/libs"}
system.loadedLibs = {system = system}

system.fs = vfs.createHost()
system.fs:mount("/", rootfs)
system.fs:mount("/root", rootfs)
system.fs:mount("/tmp", ramfs.create(1024 * 1024))

system.processhost = process.createHost()

local function makeComponentPrimary(components, component)
    for i = #components, 1, -1 do
        if components[i] == component then
            table.remove(components, i)
            table.insert(components, 1, component)
            break
        end
    end
end

local function rawExecute(path, args)
    args = args or {}

    local appCode = system.fs:pReadFile(path)
    if not appCode then
        return
    end

    local appdirPath = vfs.path(path)
    local appdataPath = vfs.concat(appdirPath, ".appdata")

    local codeEncrypted
    local virtualData = ""

    local createEnv
    createEnv = function ()
        local env = process.createEnv()
        env.loadfile = loadfile
        env.require = require
        env.dofile = dofile

        function env.getComponents(name)
            local components = getComponents(name)
            if name == "terminal" then
                if args.terminal then
                    makeComponentPrimary(components, args.terminal)
                end
            elseif name == "display" then
                if args.display then
                    makeComponentPrimary(components, args.display)
                end
            end
            return components
        end

        function env.getComponent(name)
            return env.getComponents(name) or error("the \"" .. name .. "\" component is missing", 2)
        end

        function env.setCode(code)
            checkArg(1, code, "string")
            vfs:pWriteFile(path, code)
            appCode = code
            codeEncrypted = false
        end

        function env.getCode()
            if codeEncrypted then
                return "THIS CODE WAS ENCRYPTED"
            end
            return appCode
        end

        function env.setData(code)
            checkArg(1, code, "string")
            if appdataPath then
                vfs:pWriteFile(appdataPath, code)
            end
            virtualData = code
        end

        function env.getData()
            return vfs:pReadFile(appdataPath) or virtualData
        end

        function env.setEncryptedCode(bytecode, message)
            checkArg(1, bytecode, "string")
            checkArg(2, message, "string", "nil")
            vfs:pWriteFile(path, bytecode)
            codeEncrypted = true
        end

        function env.encryptCode(message)
            checkArg(1, message, "string", "nil")
            if codeEncrypted then
                return false
            end
            local bytecode = enlua.compile(appCode)
            if bytecode then
                vfs:pWriteFile(path, bytecode)
                codeEncrypted = true
                return true
            end
            return false
        end

        function env.isCodeEncrypted()
            return codeEncrypted
        end

        env.systemenv = _G
        return env
    end

    local appProcess = system.processhost:create(createEnv)

    local appinfo
    for _, localAppinfo in ipairs(system.installedApps()) do
        if system.fs:equals(localAppinfo.dir, appdirPath) then
            appinfo = localAppinfo
            break
        end
    end

    local scriptData = {
        args = args,
        type = "app",
        process = appProcess,
        appinfo = appinfo,
        selfScriptPath = path,
        selfScriptDirectory = vfs.path(path)
    }

    if enlua.load(appCode) then
        codeEncrypted = true
        appProcess:enluaLoad(appCode, scriptData)
    else
        codeEncrypted = false
        appProcess:load(appCode, "=" .. path, nil, scriptData)
    end
    
    return scriptData
end

function system.execute(name, args)
    local result
    local function try(path)
        local func = loadfile(path)
        if func then
            result = rawExecute(path, args)
            return true
        end
    end

    if try(name) then return result end
    for _, dir in ipairs(system.appDirs) do
        if try(vfs.concat(dir, name .. ".app", "main.lua")) then
            return result
        end
    end

    return nil, "failed to find app"
end

function system.initApp(appinfo)
    for i = #system.initializedApps, 1, -1 do
        local localInitappinfo = system.initializedApps[i]
        if localInitappinfo.appinfo.dir == appinfo.dir then
            return false
        end
    end

    local serviceProcess

    local servicePath = vfs.concat(appinfo.dir, "service.lua")
    if system.fs:pHasFile(servicePath) then
        serviceProcess = system.execute(servicePath)
    end

    local initappinfo = {
        appinfo = appinfo,
        serviceProcess = serviceProcess
    }
    
    table.insert(system.initializedApps, initappinfo)
    return true
end

function system.parseCommand(input)
    local commandTable = {}
    local current = ""
    local inQuotes = false

    for i = 1, #input do
        local char = input:sub(i, i)

        if char == '"' then
            inQuotes = not inQuotes
        elseif char == '\\' and inQuotes then
            local nextChar = input:sub(i + 1, i + 1)
            if nextChar == 'n' then
                current = current .. '\n'
                i = i + 1
            elseif nextChar == '\\' then
                current = current .. '\\'
                i = i + 1
            else
                current = current .. char
            end
        elseif char == ' ' and not inQuotes then
            if #current > 0 then
                table.insert(commandTable, current)
                current = ""
            end
        else
            current = current .. char
        end
    end

    if #current > 0 then
        table.insert(commandTable, current)
    end

    return commandTable
end

function system.uninitApp(appinfo)
    local initappinfo

    for i = #system.initializedApps, 1, -1 do
        local localInitappinfo = system.initializedApps[i]
        if localInitappinfo.appinfo.dir == appinfo.dir then
            initappinfo = localInitappinfo
            table.remove(system.initializedApps, i)
            break
        end
    end

    if initappinfo then
        if initappinfo.serviceProcess then
            initappinfo.serviceProcess:destroy()
            initappinfo.serviceProcess = nil
        end

        return true
    end

    return false
end

function system.uninstallApp(appinfo)
    local exists = system.fs:pHasFolder(appinfo.dir)
    if exists then
        system.uninitApp(appinfo)
        system.fs:recursionDelete(appinfo.dir)
        return not system.fs:pHasFolder(appinfo.dir)
    end
    return false
end

function system.closeApp(scriptData)
    scriptData.process:destroy()
end

function system.isRunning(scriptData)
    return not scriptData.process:isStopped()
end

function system.isSystemApp(appinfo)
    return vfs.concat(system.appDirs[1], appinfo.baseDir)
end

local defaultAppConfig = {
    terminal = true,
    display = true,
    gui = false,
    hidden = false
}

local function configProcess(config)
    for k, v in pairs(defaultAppConfig) do
        if config[k] == nil then
            config[k] = v
        end
    end
    return config
end

function system.getAppConfig(appinfo)
    local configPath = vfs.concat(appinfo.dir, "config.json")
    if system.fs:pHasFile(configPath) then
        local configData = system.fs:pReadFile(configPath)
        local ok, result = pcall(json.nativeDecode, configData)
        if ok then
            return configProcess(result)
        end
    end
    return configProcess({})
end

function system.installedApps()
    local list = {}
    for _, dir in ipairs(system.appDirs) do
        for _, name in ipairs(system.fs:pGetFolderList(dir)) do
            local appdir = vfs.concat(dir, name)
            table.insert(list, {name = vfs.hideExtension(name), dir = appdir, baseDir = dir, exec = vfs.concat(appdir, "main.lua")})
        end
    end
    return list
end

function system.filteredApps(requirements)
    local list = {}
    for _, appinfo in ipairs(system.installedApps()) do
        local config = system.getAppConfig(appinfo)
        if not config.hidden then
            local meetRequirements = true
            for k, v in pairs(requirements) do
                if config[k] ~= v then
                    meetRequirements = false
                    break
                end
            end
            if meetRequirements then
                table.insert(list, appinfo)
            end
        end
    end
    return list
end

function system.findAppByName(name)
    for _, appinfo in ipairs(system.installedApps()) do
        if appinfo.name == name then
            return appinfo
        end
    end
end

function system.mount(tag, index, component)
    local path
    while true do
        path = "/" .. tag .. index
        if not system.fs:hasMount(path) then
            system.fs:mount(path, component)
            return path
        end
        index = index + 1
    end
end

function system.checkAttachDetachComponents(ctype, checkTable, callback)
    for index, component in ipairs(getComponents(ctype)) do
        if not checkTable[component] then
            checkTable[component] = {index = index}
            callback(true, component, checkTable[component])
        end
    end

    for component, data in pairs(checkTable) do
        if not isComponentAvailable(component) then
            callback(false, component, data)
            checkTable[component] = nil
        end
    end
end

function loadfile(path, mode, env)
    local file = system.fs:pReadFile(path)
    if not file then
        return nil, "file not found"
    end

    return load(file, "=" .. path, mode, env)
end

function dofile(path, ...)
    return assert(loadfile(path))(...)
end

local _require = require
function require(name) --redefining the standard require function in the mod to add loading of system libraries
    if system.loadedLibs[name] then
        return system.loadedLibs[name]
    end

    local library
    local function try(path)
        local func = loadfile(path)
        if func then
            library = func({
                selfScriptPath = path,
                selfScriptDirectory = vfs.path(path),
                type = "lib"
            })
            system.loadedLibs[name] = library
            return true
        end
    end

    if try(name) then return library end
    for _, dir in ipairs(system.libDirs) do
        if try(vfs.concat(dir, name .. ".lua")) then
            return library
        end
    end
    
    library = _require(name)
    system.loadedLibs[name] = library
    return library
end

return system