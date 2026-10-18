--more detailed instructions are here: https://igorkll.github.io/SComputers/scriptableOS.html

local autoboot_timer = 40 * 4

-----------------------------------------

local processlibrary = require("process")
local timerlibrary = require("timer")

local colors = require("colors")
local utils = require("utils")
local enlua = require("enlua")
local guilib = require("gui")
local styles = require("styles")
local objs = require("objs")

local roms = getComponents("rom")
local disks = getComponents("disk")
local processhost = processlibrary.createHost()
local timerhost = timerlibrary.createHost()

-----------------------------------------

local userInterfaces = {}
local bootTimer

-----------------------------------------

local function create_gui(display)
    local selfTbl

    display.reset()
    display.clearClicks()
    display.setClicksAllowed(true)
    local rx, ry = display.getWidth(), display.getHeight()

    local gui = guilib.new(display)
    local scene_logo, scene_ignore, scene_menu

    local function addLogo(scene)
        local logo = scene:createLabel(0, 0, math.round(rx * 0.9), ry / 4, "BIOS 2", 0xffffff, 0xff00ff)
        logo:setFontParameters(nil, 8, 10, 3)
        logo:setCenter()
    end

    do
        scene_logo = gui:createScene("000000")

        function scene_logo:onTick(click)
            if click then
                selfTbl.openUi()
            end
        end
        
        local label = scene_logo:createText(0, 0, "TOUCH TO DISPLAY")
        label:setBorderDown(2 + 6)
        label:setBorderLeft(2)

        local label1 = scene_logo:createText(0, 0, "TO OPEN BOOT MENU")
        label1:setBorderDown(2)
        label1:setBorderLeft(2)

        addLogo(scene_logo)
    end

    do
        scene_ignore = gui:createScene("000000")
        
        local label = scene_ignore:createText(0, 0, "BOOT MENU OPENED")
        label:setBorderDown(2 + 6)
        label:setBorderLeft(2)

        local label1 = scene_ignore:createText(0, 0, "ON OTHER DISPLAY")
        label1:setBorderDown(2)
        label1:setBorderLeft(2)

        addLogo(scene_ignore)
    end

    do
        scene_menu = gui:createScene("0000ff")

    end

    local function openUi()
        bootTimer:setEnabled(false)
        bootTimer:reset()

        for _, userInterface in ipairs(userInterfaces) do
            if userInterface ~= selfTbl then
                userInterface.ignoreUi()
            end
        end

        scene_menu:select()
    end

    local function ignoreUi()
        display.clearClicks()
        display.setClicksAllowed(false)
        scene_ignore:select()
    end

    selfTbl = {
        onTick = function()
            gui:tick()
            if gui:needFlush() then
                gui:draw()
                display.flush()
            end
        end,
        openUi = openUi,
        ignoreUi = ignoreUi
    }

    table.insert(userInterfaces, selfTbl)
end

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

function getBootDevice(component)
    local initCode
    local initArg
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

    if component then
        if component.type == "rom" then
            for i = 1, 1 do
                if tryOpenRom(component, "openFilesystemImage", true) then break end
                if tryOpenRom(component, "openFilesystemDump", true) then break end
                if tryOpenRom(component, "open", false) then break end
            end
        elseif component.type == "disk" then
            tryBootFromFilesystem(component)
        end
    else
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
    end

    return {
        initCode = initCode,
        initArg = initArg,
        initFs = initFs
    }
end

function tryBoot()
    graphic_clear()
    userInterfaces = {}
    
    local bootCode = getBootDevice()

    if bootCode.initCode then
        local function rawWriteInitCode(code)
            if bootCode.initFs and not bootCode.initFs.isReadOnly() then
                if not bootCode.initFs.hasFile(targetFile) then
                    bootCode.initFs.createFile(targetFile)
                end
                bootCode.initFs.writeFile(targetFile, code)
            end
        end

        local codeEncrypted
        local virtualData

        initProcess = processhost:create(function ()
            local env = processlibrary.createEnv()

            function env.setCode(code)
                checkArg(1, code, "string")
                rawWriteInitCode(code)
                bootCode.initCode = code
                codeEncrypted = false
            end

            function env.getCode()
                if codeEncrypted then
                    return "THIS CODE WAS ENCRYPTED"
                end
                return bootCode.initCode
            end

            function env.setData(code)
                checkArg(1, code, "string")
                if bootCode.initFs then
                    bootCode.initFs.setData(code)
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
                local bytecode = enlua.compile(bootCode.initCode)
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

        if enlua.load(bootCode.initCode) then
            codeEncrypted = true
            initProcess:enluaLoad(bootCode.initCode, bootCode.initArg)
        else
            codeEncrypted = false
            initProcess:load(bootCode.initCode, "=init", nil, bootCode.initArg)
        end
    else
        graphic_error("no bootable medium found")
    end
end

function onStart()
    graphic_clear()

    for _, display in ipairs(getComponents("display")) do
        create_gui(display)
    end

    if #userInterfaces == 0 then
        tryBoot()
    else
        bootTimer = timerhost:createTimer(autoboot_timer, false)
        bootTimer:setEnabled(true)
        bootTimer:reset()
    end
end

function onTick()
    processhost:tick()
    timerhost:tick()

    if bootTimer and bootTimer:isTriggered() then
        tryBoot()
    end
    
    if initProcess then
        local error = initProcess:getError()
        if error then
            graphic_error(error)
            initProcess:destroy()
            initProcess = nil
        end
    end

    for _, userInterface in ipairs(userInterfaces) do
        userInterface.onTick()
    end
end

function onStop()
    processhost:stop()
    graphic_clear()
end

_enableCallbacks = true