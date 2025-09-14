--more detailed instructions are here: https://igorkll.github.io/SComputers/scriptableOS.html

local colors = require("colors")
local utils = require("utils")
local enlua = require("enlua")
local processlibrary = require("process")

local roms = getComponents("rom")
local disks = getComponents("disk")
local processhost = processlibrary.createHost()

-----------------------------------------

local function graphic_clear()
    for _, display in ipairs(getComponents("display")) do
        display.reset()
        display.clear()
        display.flush()
    end

    for _, terminal in ipairs(getComponents("terminal")) do
        terminal.clear()
    end
end

local function graphic_error(text)
    local bsodBackground = colors.sm.Blue[2]
    local bsodForeground = colors.sm.Gray[1]
    local bsodLabelBackground = colors.sm.Gray[1]
    local bsodLabelForeground = colors.sm.Blue[2]

    for _, display in ipairs(getComponents("display")) do
        local sx = display.getWidth()
        local fsx, fsy = display.getFontWidth() + 1, display.getFontHeight() + 1
        local strMaxSize = math.floor(sx / fsx)

        local function centerPrint(text, y, color)
            display.drawText((sx / 2) - ((utf8.len(text) / 2) * fsx), y, text, color)
        end

        display.reset()
        display.clear(bsodBackground)
        display.fillRect(0, 0, sx, fsy + 1, bsodLabelBackground)
        centerPrint("ERROR", 1, bsodLabelForeground)
        local index = 1
        for _, str in ipairs(utils.split(utf8, tostring(text):upper(), "\n")) do
            local partsCount = 0
            for _, lstr in ipairs(utils.splitByMaxSizeWithTool(utf8, str, strMaxSize)) do
                centerPrint(lstr, (index * fsy) + 2, bsodForeground)
                index = index + 1
                partsCount = partsCount + 1
            end
            if partsCount == 0 then
                index = index + 1
            end
        end
        display.forceFlush()
    end

    local coloredError = "#ff0000ERROR: " .. text

    for _, terminal in ipairs(getComponents("terminal")) do
        terminal.clear()
        terminal.write(coloredError)
    end

    log(coloredError)
end

-----------------------------------------

local targetFile = "/init.lua"
local targetKey = "init"

local initProcess

function onStart()
    graphic_clear()

    local initCode
    local initArg
    local lastError
    local initFs

    local function tryBootFromFilesystem(fs)
        if fs.hasFile(targetFile) then
            initCode = fs.readFile(targetFile)
            initArg = fs
            initFs = fs
            return true
        end
    end

    local function tryBootFromRom(rom, tbl)
        if type(tbl["init"]) == "string" then
            initCode = tbl["init"]
            initArg = rom
            return true
        end
    end

    local function tryOpenRom(rom, method, hasFilesystem)
        local ok, result = pcall(rom[method])
        if ok and type(result) == "table" then
            if hasFilesystem then
                if tryBootFromFilesystem(result) then return true end
            else
                if tryBootFromRom(rom, result) then return true end
            end
        end
    end

    for _, rom in ipairs(roms) do
        if tryOpenRom(rom, "openFilesystemImage", true) then break end
        if tryOpenRom(rom, "openFilesystemDump", true) then break end
        if tryOpenRom(rom, "open", false) then break end
    end

    if not initCode then
        for _, disk in ipairs(disks) do
            if tryBootFromFilesystem(disk) then break end
        end
    end

    if initCode then
        local function rawWriteInitCode(code)
            if initFs and not initFs.isReadOnly() then
                if not initFs.hasFile(targetFile) then
                    initFs.createFile(targetFile)
                end
                initFs.writeFile(targetFile, code)
            end
        end

        local codeEncrypted
        local virtualData

        initProcess = processhost:create(function ()
            local env = processlibrary.createEnv()

            function env.setCode(code)
                checkArg(1, code, "string")
                rawWriteInitCode(code)
                initCode = code
                codeEncrypted = false
            end

            function env.getCode()
                if codeEncrypted then
                    return "THIS CODE WAS ENCRYPTED"
                end
                return initCode
            end

            function env.setData(code)
                checkArg(1, code, "string")
                if initFs then
                    initFs.setData(code)
                else
                    virtualData = code
                end
            end

            function env.getData()
                if initFs then
                    return initFs.getData()
                end
                return virtualData or ""
            end

            function env.setEncryptedCode(bytecode, message)
                checkArg(1, bytecode, "string")
                checkArg(2, message, "string", "nil")
                rawWriteInitCode(bytecode)
                codeEncrypted = true
            end

            function env.encryptCode(message)
                checkArg(1, message, "string", "nil")
                if codeEncrypted then
                    return false
                end
                local bytecode = enlua.compile(initCode)
                if bytecode then
                    rawWriteInitCode(bytecode)
                    codeEncrypted = true
                    return true
                end
                return false
            end

            function env.isCodeEncrypted()
                return codeEncrypted
            end
    
            env.biosenv = _G
            return env
        end)

        if enlua.load(initCode) then
            codeEncrypted = true
            initProcess:enluaLoad(initCode, initArg)
        else
            codeEncrypted = false
            initProcess:load(initCode, "=init", nil, initArg)
        end
    else
        graphic_error("no bootable medium found" .. (lastError and ("\n" .. lastError) or ""))
    end
end

function onTick()
    processhost:tick()
    if initProcess then
        local error = initProcess:getError()
        if error then
            graphic_error(error)
            initProcess:destroy()
            initProcess = nil
        end
    end
end

function onStop()
    processhost:stop()
    graphic_clear()
end

_enableCallbacks = true