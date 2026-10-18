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

local processhost = processlibrary.createHost()
local timerhost = timerlibrary.createHost()

-----------------------------------------

local userInterfaces = {}
local bootTimer

-----------------------------------------

local function userinterface_create_display(display)
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

local function userinterface_clear()
    for _, display in ipairs(getComponents("display")) do
        display.reset()
        display.clear()
        display.flush()
    end

    for _, terminal in ipairs(getComponents("terminal")) do
        terminal.clear()
    end
end

local function userinterface_error(text)
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

function getComponentIndex(ctype, component)
    for componentIndex, _component in ipairs(getComponents(ctype)) do
        if component == _component then
            return componentIndex
        end
    end
end

function getBootDevice(component)
    local initCode
    local initArg
    local initFs
    local initComponent
    local initComponentIndex

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
                if tryOpenRom(component, "openFilesystemImage", true) then
                    initComponent = component
                    initComponentIndex = getComponentIndex("rom", component)
                    break
                end

                if tryOpenRom(component, "openFilesystemDump", true) then
                    initComponent = component
                    initComponentIndex = getComponentIndex("rom", component)
                    break
                end

                if tryOpenRom(component, "open", false) then
                    initComponent = component
                    initComponentIndex = getComponentIndex("rom", component)
                    break
                end
            end
        elseif component.type == "disk" then
            if tryBootFromFilesystem(component) then
                initComponent = component
                initComponentIndex = getComponentIndex("disk", component)
            end
        end
    else
        for componentIndex, rom in ipairs(getComponents("rom")) do
            if tryOpenRom(rom, "openFilesystemImage", true) then
                initComponent = rom
                initComponentIndex = componentIndex
                break
            end

            if tryOpenRom(rom, "openFilesystemDump", true) then
                initComponent = rom
                initComponentIndex = componentIndex
                break
            end

            if tryOpenRom(rom, "open", false) then
                initComponent = rom
                initComponentIndex = componentIndex
                break
            end
        end

        if not initCode then
            for componentIndex, disk in ipairs(getComponents("disk")) do
                if tryBootFromFilesystem(disk) then
                    initComponent = disk
                    initComponentIndex = componentIndex
                    break
                end
            end
        end
    end

    if not initCode then
        return
    end

    return {
        initCode = initCode,
        initArg = initArg,
        initFs = initFs,
        initComponent = initComponent,
        initComponentIndex = initComponentIndex
    }
end

function getComponentFromIndex(initComponentType, initComponentIndex)
    if type(initComponentType) ~= "string" or type(initComponentIndex) ~= "number" then return end
    return getComponents(initComponentType)[initComponentIndex]
end

function getBootDeviceAuto()
    local dataTable = getTable()

    if dataTable.initComponentIndex then
        local bootComponent = getComponentFromIndex(dataTable.initComponentType, bootDevice.initComponentIndex)
        if bootComponent then
            local bootDevice = getBootDevice(bootComponent)
            if bootDevice then
                return bootDevice
            end
        end
    end

    local bootDevice = getBootDevice()

    if bootDevice then
        dataTable.initComponentType = bootDevice.initComponent.type
        dataTable.initComponentIndex = bootDevice.initComponentIndex
    else
        dataTable.initComponentType = nil
        dataTable.initComponentIndex = nil
    end
    setTable(dataTable)

    return bootDevice
end

function tryBoot()
    userinterface_clear()
    userInterfaces = {}
    
    local bootDevice = getBootDevice()

    if bootDevice.initCode then
        local function rawWriteInitCode(code)
            if bootDevice.initFs and not bootDevice.initFs.isReadOnly() then
                if not bootDevice.initFs.hasFile(targetFile) then
                    bootDevice.initFs.createFile(targetFile)
                end
                bootDevice.initFs.writeFile(targetFile, code)
            end
        end

        local codeEncrypted
        local virtualData

        initProcess = processhost:create(function ()
            local env = processlibrary.createEnv()

            function env.setCode(code)
                checkArg(1, code, "string")
                rawWriteInitCode(code)
                bootDevice.initCode = code
                codeEncrypted = false
            end

            function env.getCode()
                if codeEncrypted then
                    return "THIS CODE WAS ENCRYPTED"
                end
                return bootDevice.initCode
            end

            function env.setData(code)
                checkArg(1, code, "string")
                if bootDevice.initFs then
                    bootDevice.initFs.setData(code)
                else
                    virtualData = code
                end
            end

            function env.getData()
                if bootDevice.initFs then
                    return bootDevice.initFs.getData()
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
                local bytecode = enlua.compile(bootDevice.initCode)
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

        if enlua.load(bootDevice.initCode) then
            codeEncrypted = true
            initProcess:enluaLoad(bootDevice.initCode, bootDevice.initArg)
        else
            codeEncrypted = false
            initProcess:load(bootDevice.initCode, "=init", nil, bootDevice.initArg)
        end
    else
        userinterface_error("no bootable medium found")
    end
end

function onStart()
    userinterface_clear()

    for _, display in ipairs(getComponents("display")) do
        userinterface_create_display(display)
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
            userinterface_error(error)
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
    userinterface_clear()
end

_enableCallbacks = true