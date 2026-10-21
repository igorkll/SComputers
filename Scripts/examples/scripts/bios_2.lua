--more detailed instructions are here: https://igorkll.github.io/SComputers/scriptableOS.html

local autoboot_timer = 40 * 4
local min_res = 64
local prohibit_manual_open_bootmenu = false
local auto_open_bootmenu = false
local title_logo = "BIOS 2"
local title_bootmenu = "BOOT MENU"
local title_setupmenu = "SETUP"
local prohibit_setup = false
local defaultSetupTable = {}
local setupTableKey = "BIOS_2"

-----------------------------------------

do
    local dataTable = getTable()
    if not dataTable[setupTableKey] then
        defaultSetupTable[setupTableKey] = true
        setTable(defaultSetupTable)
    end
end
debug(getTable())

local processlibrary = require("process")
local timerlibrary = require("timer")

local colors = require("colors")
local utils = require("utils")
local enlua = require("enlua")
local guilib = require("gui")
local styles = require("styles")
local objs = require("objs")
local fonts = require("fonts")

local processhost = processlibrary.createHost()
local timerhost = timerlibrary.createHost()

-----------------------------------------

local userInterfaces = {}
local bootTimer
local manualBoot = false

-----------------------------------------

local function setupButton(button, oldButton)
    button:setPbgColor(0x000000)
    button:setPfgColor(0xffffff)
end

local function bootmenu_setup(gui, scene_menu)
    local buttonSizeY = 7

    local scene_setup = gui:createScene("0000ff")
    scene_setup:createLabel(1, 1, scene_setup.sizeX - 2, objHeight, title_setupmenu, 0xffffff, 0x0000ff)

    local backButton = scene_setup:createButton(0, 0, nil, buttonSizeY, false, "< BACK", 0xffffff, 0x0000ff)
    setupButton(backButton)
    backButton:setBorderDown(1)
    backButton:setBorderLeft(1)
    function backButton:onDropInZone()
        scene_menu:select()
    end

    local posY = buttonSizeY + 2 + 1
    local stepY = 7

    scene_setup:createText(1, posY, "ADMIN PASSWD", 0xffffff, 0x0000ff)
    posY = posY + stepY

    local setAdminPasswdButton = scene_setup:createButton(1, posY, 16, buttonSizeY, false, "SET", 0xffffff, 0x0000ff)
    setupButton(setAdminPasswdButton)
    function setAdminPasswdButton:onDropInZone()
        
    end

    local setAdminPasswdButton = scene_setup:createButton(1 + setAdminPasswdButton.sizeX + 1, posY, 32, buttonSizeY, false, "CLEAR", 0xffffff, 0x0000ff)
    setupButton(setAdminPasswdButton)
    function setAdminPasswdButton:onDropInZone()
        
    end

    return scene_setup
end

local function bootmenu_buttons(scene_menu, refreshComponents, scene_setup)
    local buttonSizeY = 7
    local buttonSizeX = (scene_menu.sizeX / 2) - 3

    local refreshButton = scene_menu:createButton(0, 0, buttonSizeX, buttonSizeY, false, "REFRESH", 0xffffff, 0x0000ff)
    setupButton(refreshButton)
    if scene_menu.sizeX <= 64 then
        refreshButton:setFontParameters(fonts.lgc_3x3, 3, 3, 1)
    end
    refreshButton:setBorderDown(2 + buttonSizeY + 2)
    refreshButton:setBorderLeft(2)
    function refreshButton:onDropInZone()
        refreshComponents()
    end

    local bootButton = scene_menu:createButton(0, 0, buttonSizeX, buttonSizeY, false, "BOOT", 0xffffff, 0x0000ff)
    setupButton(bootButton, refreshButton)
    bootButton:setBorderDown(2)
    bootButton:setBorderRight(2)
    function bootButton:onDropInZone()
        manualBoot = true
    end

    local rebootButton = scene_menu:createButton(0, 0, buttonSizeX, buttonSizeY, false, "REBOOT", 0xffffff, 0x0000ff)
    setupButton(rebootButton, bootButton)
    rebootButton:setBorderDown(2)
    rebootButton:setBorderLeft(2)
    function rebootButton:onDropInZone()
        reboot()
    end

    if not prohibit_setup then
        local settingsButton = scene_menu:createButton(0, 0, buttonSizeX, buttonSizeY, false, "SETUP", 0xffffff, 0x0000ff)
        setupButton(settingsButton, rebootButton)
        settingsButton:setBorderDown(2 + buttonSizeY + 2)
        settingsButton:setBorderRight(2)
        function settingsButton:onDropInZone()
            scene_setup:select()
        end
    end
end

local function bootmenu_menu(gui)
    local scene_menu = gui:createScene("0000ff")
    scene_menu:createLabel(1, 1, scene_menu.sizeX - 2, objHeight, title_bootmenu, 0xffffff, 0x0000ff)

    local buttonSizeY = 7
    local posY = buttonSizeY + 2 + 1
    local arrowButtonsSize = 25
    local arrowButtonsFontSize = 30
    local bootButtonsContainer = scene_menu:createWindow(1, posY, scene_menu.sizeX - 2, scene_menu.sizeY - posY - ((buttonSizeY + 2) * 2) - 2, 0xffffff)
    bootButtonsContainer:setAutoViewport(true)

    local arrowPosX = bootButtonsContainer.sizeX - arrowButtonsSize - 1
    local arrowSizeY = bootButtonsContainer.sizeY / 4

    local arrowUp = bootButtonsContainer:createButton(arrowPosX, 0, arrowButtonsSize, arrowSizeY, false, "5", 0x000000, 0xffffff)
    arrowUp:setBorderUp(1)
    arrowUp:setPbgColor(0x0000ff)
    arrowUp:setPfgColor(0xffffff)
    arrowUp:setFontParameters(fonts.webdings_32, arrowButtonsFontSize, arrowButtonsFontSize)
    
    local arrowDown = bootButtonsContainer:createButton(arrowPosX, 0, arrowButtonsSize, arrowSizeY, false, "6", 0x000000, 0xffffff)
    arrowDown:setBorderDown(1)
    arrowDown:setPbgColor(0x0000ff)
    arrowDown:setPfgColor(0xffffff)
    arrowDown:setFontParameters(fonts.webdings_32, arrowButtonsFontSize, arrowButtonsFontSize)

    local bootButtons = {}
    local bootButtonPosY = 1

    local baseScroll = 1
    local scrollStep = buttonSizeY + 1
    local baseScrollMax = 1
    local baseScrollMin = 1

    local function incBootButtonPosY()
        bootButtonPosY = bootButtonPosY + buttonSizeY + 1
    end

    local function setScrollButtons(offset)
        bootButtonPosY = offset
        for _, bootButton in ipairs(bootButtons) do
            bootButton:setPositionY(bootButtonPosY)
            incBootButtonPosY()
        end
    end

    local function clearBootButtons()
        bootButtonPosY = 1
        baseScrollMin = 1
        baseScroll = 1

        for _, bootButton in ipairs(bootButtons) do
            bootButton:destroy()
        end

        bootButtons = {}
    end

    function arrowUp:onDropInZone()
        baseScroll = baseScroll + scrollStep
        if baseScroll > baseScrollMax then baseScroll = baseScrollMax end
        setScrollButtons(baseScroll)
    end

    function arrowDown:onDropInZone()
        baseScroll = baseScroll - scrollStep
        if baseScroll < baseScrollMin then baseScroll = baseScrollMin end
        setScrollButtons(baseScroll)
    end

    local oldBootButtonSelected
    local function updateBootButtonColor(bootButton, currentBootable)
        bootButton:setPbgColor(0x0000ff)
        bootButton:setPfgColor(currentBootable and 0xff00ff or 0xffffff)
        bootButton:setFgColor(currentBootable and 0xff00ff or 0xffffff)
        if currentBootable then
            oldBootButtonSelected = bootButton
        end
    end

    local function addBootButton(title, callback, currentBootable)
        local bootButton = bootButtonsContainer:createButton(1, bootButtonPosY, arrowPosX - 2, buttonSizeY, false, title, 0x000000, 0xffffff)
        updateBootButtonColor(bootButton, currentBootable)

        if #bootButtons > 0 then
            baseScrollMin = baseScrollMin - buttonSizeY - 1
        end

        table.insert(bootButtons, bootButton)
        incBootButtonPosY()

        function bootButton:onDropInZone()
            callback()
        end

        return bootButton
    end

    local function addDiskButton(index, component)
        local dataTable = getTable()
        local currentBootable = dataTable.bootDeviceType == component.type and dataTable.bootDeviceIndex == index

        local diskButton
        diskButton = addBootButton(component.type .. ":" .. index, function()
            if oldBootButtonSelected then
                updateBootButtonColor(oldBootButtonSelected, false)
            end
            updateBootButtonColor(diskButton, true)
            setBootDevice(component)
        end, currentBootable)
    end

    local function refreshComponents()
        clearBootButtons()

        for index, component in ipairs(getComponents("disk")) do
            if isBootDevice(component) then
                addDiskButton(index, component)
            end
        end

        for index, component in ipairs(getComponents("rom")) do
            if isBootDevice(component) then
                addDiskButton(index, component)
            end
        end
    end

    return scene_menu, refreshComponents
end

local function bootmenu(gui)
    local scene_menu, refreshComponents = bootmenu_menu(gui)
    local scene_setup = bootmenu_setup(gui, scene_menu)

    refreshComponents()

    bootmenu_buttons(scene_menu, refreshComponents, scene_setup)

    return scene_menu
end

local function userinterface_create_display(display)
    local selfTbl

    display.reset()
    display.clearClicks()
    display.setClicksAllowed(not prohibit_manual_open_bootmenu)
    display.setUtf8Support(true)
    local rx, ry = display.getWidth(), display.getHeight()

    local gui = guilib.new(display)
    local scene_logo, scene_ignore, scene_menu

    local function addLogo(scene)
        local logo = scene:createLabel(0, 0, math.round(rx * 0.9), ry / 4, title_logo, 0xffffff, 0xff00ff)
        local mulSize = math.round(rx / 64)
        logo:setFontParameters(fonts.oc_16x8, math.max(12, 8 * mulSize), math.max(16, 10 * mulSize), 3 * mulSize)
        logo:setCenter()
    end

    do
        scene_logo = gui:createScene("000000")

        function scene_logo:onTick(click)
            if click and click.state == "pressed" then
                if not prohibit_manual_open_bootmenu then
                    selfTbl.openUi()
                end
            end
        end

        if not prohibit_manual_open_bootmenu then
            local label = scene_logo:createText(0, 0, "TAP TO OPEN")
            label:setBorderDown(2 + 6)
            label:setBorderLeft(2)

            local label2 = scene_logo:createText(0, 0, "BOOT MENU")
            label2:setBorderDown(2)
            label2:setBorderLeft(2)
        end

        addLogo(scene_logo)
    end

    do
        scene_ignore = gui:createScene("000000")

        addLogo(scene_ignore)
    end

    scene_menu = bootmenu(gui)

    local function openUi()
        display.clearClicks()
        display.setClicksAllowed(true)
        deleteBootTimer()

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
    local bootDevice
    local bootDeviceIndex

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
            if tryOpenRom(component, "openFilesystemImage", true) or
            tryOpenRom(component, "openFilesystemDump", true) or
            tryOpenRom(component, "open", false) then
                bootDevice = component
                bootDeviceIndex = getComponentIndex("rom", component)
            end
        elseif component.type == "disk" then
            if tryBootFromFilesystem(component) then
                bootDevice = component
                bootDeviceIndex = getComponentIndex("disk", component)
            end
        end
    else
        for componentIndex, rom in ipairs(getComponents("rom")) do
            if tryOpenRom(rom, "openFilesystemImage", true) or
            tryOpenRom(rom, "openFilesystemDump", true) or
            tryOpenRom(rom, "open", false) then
                bootDevice = rom
                bootDeviceIndex = componentIndex
                break
            end
        end

        if not initCode then
            for componentIndex, disk in ipairs(getComponents("disk")) do
                if tryBootFromFilesystem(disk) then
                    bootDevice = disk
                    bootDeviceIndex = componentIndex
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
        bootDevice = bootDevice,
        bootDeviceIndex = bootDeviceIndex
    }
end

function isBootDevice(bootComponent)
    return not not getBootDevice(bootComponent)
end

function getComponentFromIndex(bootDeviceType, bootDeviceIndex)
    if type(bootDeviceType) ~= "string" or type(bootDeviceIndex) ~= "number" then return end
    return getComponents(bootDeviceType)[bootDeviceIndex]
end

function getBootDeviceAuto()
    local dataTable = getTable()

    if dataTable.bootDeviceType and dataTable.bootDeviceIndex then
        local bootComponent = getComponentFromIndex(dataTable.bootDeviceType, dataTable.bootDeviceIndex)
        if bootComponent then
            local bootDevice = getBootDevice(bootComponent)
            if bootDevice then
                return bootDevice
            end
        end
    end

    local bootDevice = getBootDevice()

    if bootDevice then
        dataTable.bootDeviceType = bootDevice.bootDevice.type
        dataTable.bootDeviceIndex = bootDevice.bootDeviceIndex
    else
        dataTable.bootDeviceType = nil
        dataTable.bootDeviceIndex = nil
    end
    setTable(dataTable)

    return bootDevice
end

function setBootDevice(bootComponent)
    local ctype = bootComponent.type
    local dataTable = getTable()
    dataTable.bootDeviceType = ctype
    dataTable.bootDeviceIndex = getComponentIndex(ctype, bootComponent)
    setTable(dataTable)
end

function tryBoot()
    userinterface_clear()
    userInterfaces = {}
    
    local bootDevice = getBootDeviceAuto()

    if bootDevice then
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
        if display.getWidth() >= min_res or display.getHeight() >= min_res then
            userinterface_create_display(display)
        end
    end

    if #userInterfaces == 0 then
        tryBoot()
    else
        bootTimer = timerhost:createTimer(autoboot_timer, false)
        bootTimer:setEnabled(true)
        bootTimer:reset()
    end
end

function deleteBootTimer()
    if bootTimer then
        bootTimer:delete()
        bootTimer = nil
    end
end

function onTick()
    processhost:tick()
    timerhost:tick()

    if not initProcess then
        if bootTimer and bootTimer:isTriggered() then
            local tryBootFlag = true

            if auto_open_bootmenu and #userInterfaces > 0 then
                tryBootFlag = false
                userInterfaces[1].openUi()
            end

            if tryBootFlag then
                tryBoot()
                deleteBootTimer()
            end
        elseif manualBoot then
            tryBoot()
            manualBoot = false
        end
    end
    
    if initProcess then
        local errStr = initProcess:getError()
        if errStr then
            userinterface_error(errStr)
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