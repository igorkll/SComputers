local scriptData = ...
local system = require("system")
local terminal = scriptData.args.terminal

local runnedApplication

local function typeStart()
    terminal.write("> ")
end

local function clear()
    terminal.clear()
    terminal.write("#00ff00scriptableOS terminal shell\n")
end

local function printAppInfo(appinfo)
    local tags = {}
    local config = system.getAppConfig(appinfo)
    if config.terminal then
        table.insert(tags, "terminal")
    end
    if config.display then
        table.insert(tags, "full screen")
    end
    if config.gui then
        table.insert(tags, "windowed")
    end
    if config.hidden then
        table.insert(tags, "hidden")
    end
    if system.isSystemApp(appinfo) then
        table.insert(tags, "system")
    end
    terminal.write(appinfo.name .. " : " .. appinfo.exec .. " - " .. table.concat(tags, " & ") .. "\n")
end

local function errorSplash(err)
    terminal.write("#ff0000" .. err .. "\n")
end

local function findAppByName(name)
    if not name then
        errorSplash("specify the name of the application")
        return
    end

    local appinfo = system.findAppByName(name)
    if appinfo then
        return appinfo
    end

    errorSplash("failed to find app")
end

local commands
commands = {
    ["close"] = {
        description = "closes the currently running application (can be executed while the application is running)",
        runningApplication = true,
        runningShell = false,
        func = function()
            system.closeApp(runnedApplication)
        end
    },
    ["current"] = {
        description = "clears the terminal (can be executed while the application is running)",
        runningApplication = true,
        runningShell = false,
        func = function()
            terminal.write(runnedApplication.appinfo.name .. "\n")
        end
    },
    ["clear"] = {
        description = "outputs the name of the currently running application (can be executed while the application is running)",
        runningApplication = true,
        runningShell = true,
        func = function()
            clear()
        end
    },
    ["applist"] = {
        description = "displays a list of applications",
        runningApplication = false,
        runningShell = true,
        func = function()
            for _, appinfo in ipairs(system.filteredApps({terminal=true})) do
                printAppInfo(appinfo)
            end
        end
    },
    ["allapplist"] = {
        description = "displays a list of all applications, including those that cannot be run in the terminal and hidden",
        runningApplication = false,
        runningShell = true,
        func = function()
            for _, appinfo in ipairs(system.installedApps()) do
                printAppInfo(appinfo)
            end
        end
    },
    ["uninstall"] = {
        description = "deletes the app",
        runningApplication = false,
        runningShell = true,
        func = function(args)
            local appinfo = findAppByName(args[1])
            if appinfo then
                if system.isSystemApp(appinfo) then
                    errorSplash("to remove the system application, use forceUninstall")
                else
                    system.uninstallApp(appinfo)
                end
            end
        end
    },
    ["forceUninstall"] = {
        description = "deletes applications, allows you to delete system applications",
        runningApplication = false,
        runningShell = true,
        func = function(args)
            local appinfo = findAppByName(args[1])
            if appinfo then
                system.uninstallApp(appinfo)
            end
        end
    },
    ["help"] = {
        description = "displays a list of all the commands",
        runningApplication = false,
        runningShell = true,
        func = function(args)
            local commandsList = {}
            for cmd in pairs(commands) do
                table.insert(commandsList, cmd)
            end
            table.sort(commandsList)
            for _, cmd in ipairs(commandsList) do
                local description = commands[cmd].description
                terminal.write(cmd .. (description and (". " .. description) or "") .. "\n")
            end
        end
    }
}

local _terminal_read = terminal.read
local lastTerminalRead
function terminal.read()
    local str = lastTerminalRead
    lastTerminalRead = nil
    return str
end

function onStart()
    _terminal_read()
    clear()
    typeStart()
end

function onTick()
    if runnedApplication then
        if not system.isRunning(runnedApplication) then
            typeStart()
            runnedApplication = nil
        end
    end
    
    local command = _terminal_read()
    if command then
        local args = system.parseCommand(command)
        local cmd = table.remove(args, 1)
        if cmd then
            local commandTable = commands[cmd]
            if runnedApplication then
                lastTerminalRead = command
                if commandTable and commandTable.runningApplication then
                    commandTable.func(args)
                end
            else
                terminal.write(command .. "\n")
                if commandTable then
                    if commandTable.runningApplication and not commandTable.runningShell then
                        errorSplash("this command requires a running application")
                    else
                        commandTable.func(args)
                    end
                    typeStart()
                else
                    lastTerminalRead = nil
                    args.terminal = terminal
                    local scriptData, err = system.execute(cmd, args)
                    if scriptData then
                        runnedApplication = scriptData
                    else
                        errorSplash(err)
                        typeStart()
                    end
                end
            end
        else
            terminal.write("\n")
            typeStart()
        end
    end
end

_enableCallbacks = true