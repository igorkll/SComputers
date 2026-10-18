-- SC-BIOS v2
local colors = require("colors")
local utils = require("utils")
local enlua = require("enlua")
local processlibrary = require("process")
local timerlibrary = require("timer")
local guilib = require("gui")

local roms = getComponents("rom")
local disks = getComponents("disk")
local processhost = processlibrary.createHost()
local timerhost = timerlibrary.createHost()

local AUTOBOOT_SECONDS = 10
local TICKS_PER_SECOND = 40
local DATA_SEP = "\n"
local DATA_KEY_LAST = "lastBoot"

local initProcess
local bootTimer
local userInterfaces = {}
local fatalError = false
local bootRequested = false

-- ================= persistent data =================
local function loadData()
    local t = {}
    if type(getData) ~= "function" then return t end
    local ok, raw = pcall(getData)
    if not ok or type(raw) ~= "string" then return t end
    for line in raw:gmatch("[^\n]+") do
        local k, v = line:match("^([^=]+)=(.*)$")
        if k then t[k] = v end
    end
    return t
end

local function saveData(t)
    if type(setData) ~= "function" then return end
    local lines = {}
    for k, v in pairs(t) do lines[#lines + 1] = k .. "=" .. tostring(v) end
    pcall(setData, table.concat(lines, DATA_SEP))
end

-- ================= device helpers =================
local function deviceKey(dev) return dev.kind .. ":" .. dev.index end

local function deviceDisplayName(dev)
    local base = (dev.kind == "rom" and "ROM #" or "DISK #") .. dev.index
    local c = dev.component
    if c.getLabel then
        local ok, label = pcall(c.getLabel)
        if ok and type(label) == "string" and label ~= "" then
            return base .. " (" .. label .. ")"
        end
    end
    return base
end

local function checkBootable(dev)
    local c = dev.component
    if dev.kind == "rom" then
        if c.openFilesystemImage then
            local ok, fs = pcall(c.openFilesystemImage, c)
            if ok and type(fs) == "table" and fs.hasFile and fs.hasFile("/init.lua") then return true end
        end
        if c.openFilesystemDump then
            local ok, fs = pcall(c.openFilesystemDump, c)
            if ok and type(fs) == "table" and fs.hasFile and fs.hasFile("/init.lua") then return true end
        end
        if c.open then
            local ok, t = pcall(c.open, c)
            if ok and type(t) == "table" and type(t.init) == "string" then return true end
        end
    else
        if c.hasFile and c.hasFile("/init.lua") then return true end
    end
    return false
end

local function enumerateDevices()
    local out = {}
    for i, rom in ipairs(roms) do
        local d = { component = rom, kind = "rom", index = i }
        d.name = deviceDisplayName(d)
        d.bootable = checkBootable(d)
        out[#out + 1] = d
    end
    for i, disk in ipairs(disks) do
        local d = { component = disk, kind = "disk", index = i }
        d.name = deviceDisplayName(d)
        d.bootable = checkBootable(d)
        out[#out + 1] = d
    end
    return out
end

local function getInitForDevice(dev)
    local c = dev.component
    if dev.kind == "rom" then
        if c.openFilesystemImage then
            local ok, fs = pcall(c.openFilesystemImage, c)
            if ok and type(fs) == "table" and fs.hasFile and fs.hasFile("/init.lua") then
                return fs.readFile("/init.lua"), fs, fs
            end
        end
        if c.openFilesystemDump then
            local ok, fs = pcall(c.openFilesystemDump, c)
            if ok and type(fs) == "table" and fs.hasFile and fs.hasFile("/init.lua") then
                return fs.readFile("/init.lua"), fs, fs
            end
        end
        if c.open then
            local ok, t = pcall(c.open, c)
            if ok and type(t) == "table" and type(t.init) == "string" then
                return t.init, c, nil
            end
        end
    else
        if c.hasFile and c.hasFile("/init.lua") then
            return c.readFile("/init.lua"), c, c
        end
    end
end

-- ================= graphics =================
local function clearDisplays()
    for _, d in ipairs(getComponents("display")) do
        d.reset(); d.clear(); d.flush()
    end
    for _, t in ipairs(getComponents("terminal")) do t.clear() end
end

local function bsod(text)
    fatalError = true
    local bg = colors.sm.Blue[2]
    local fg = colors.sm.Gray[1]
    local lbg = colors.sm.Gray[1]
    local lfg = colors.sm.Blue[2]

    for _, display in ipairs(getComponents("display")) do
        local sx = display.getWidth()
        local fsx, fsy = display.getFontWidth() + 1, display.getFontHeight() + 1
        local maxSize = math.floor(sx / fsx)
        local function cp(t, y, color)
            display.drawText((sx / 2) - ((utf8.len(t) / 2) * fsx), y, t, color)
        end
        display.reset()
        display.clear(bg)
        display.fillRect(0, 0, sx, fsy + 1, lbg)
        cp("ERROR", 1, lfg)
        local idx = 1
        for _, str in ipairs(utils.split(utf8, tostring(text):upper(), "\n")) do
            local parts = 0
            for _, lstr in ipairs(utils.splitByMaxSizeWithTool(utf8, str, maxSize)) do
                cp(lstr, (idx * fsy) + 2, fg)
                idx = idx + 1
                parts = parts + 1
            end
            if parts == 0 then idx = idx + 1 end
        end
        display.forceFlush()
    end

    local colored = "#ff0000ERROR: " .. text
    for _, t in ipairs(getComponents("terminal")) do t.clear(); t.write(colored) end
    log(colored)
end

-- ================= boot process =================
local function bootFromDevice(dev)
    local code, arg, fs = getInitForDevice(dev)
    if not code then bsod("device is not bootable"); return false end

    local initCode = code
    local initFs = fs
    local codeEncrypted = false
    local virtualData
    local initArg = arg

    local function rawWrite(c)
        if initFs and not initFs.isReadOnly() then
            if not initFs.hasFile("/init.lua") then initFs.createFile("/init.lua") end
            initFs.writeFile("/init.lua", c)
        end
    end

    initProcess = processhost:create(function()
        local env = processlibrary.createEnv()
        env.biosenv = _G
        function env.setCode(c) checkArg(1, c, "string"); rawWrite(c); initCode = c; codeEncrypted = false end
        function env.getCode() if codeEncrypted then return "THIS CODE WAS ENCRYPTED" end return initCode end
        function env.setData(d) checkArg(1, d, "string"); if initFs then initFs.setData(d) else virtualData = d end end
        function env.getData() if initFs then return initFs.getData() end return virtualData or "" end
        function env.setEncryptedCode(bc, msg) checkArg(1, bc, "string"); rawWrite(bc); codeEncrypted = true end
        function env.encryptCode(msg)
            if codeEncrypted then return false end
            local bc = enlua.compile(initCode)
            if bc then rawWrite(bc); codeEncrypted = true; return true end
            return false
        end
        function env.isCodeEncrypted() return codeEncrypted end
        return env
    end)

    if enlua.load(initCode) then
        codeEncrypted = true
        initProcess:enluaLoad(initCode, initArg)
    else
        codeEncrypted = false
        initProcess:load(initCode, "=init", nil, initArg)
    end
    return true
end

local function doBoot(dev)
    if bootRequested or not dev then return end
    bootRequested = true
    if bootTimer then bootTimer:setEnabled(false) end
    for _, ui in ipairs(userInterfaces) do ui.deactivate() end
    local data = loadData()
    data[DATA_KEY_LAST] = deviceKey(dev)
    saveData(data)
    bootFromDevice(dev)
end

local function pickAutoBootDevice(devices)
    local data = loadData()
    local lastKey = data[DATA_KEY_LAST]
    if lastKey then
        for _, d in ipairs(devices) do
            if deviceKey(d) == lastKey and d.bootable then return d end
        end
    end
    for _, d in ipairs(devices) do if d.bootable then return d end end
end

-- ================= UI =================
local function clearSceneChildren(scene)
    local children = {}
    for i, o in ipairs(scene.objs) do children[i] = o end
    for i = #children, 1, -1 do children[i]:destroy() end
end

local function createUI(display, shared)
    display.reset(); display.clearClicks(); display.setClicksAllowed(true)
    local rx, ry = display.getWidth(), display.getHeight()
    local gui = guilib.new(display)

    local ui = {
        display = display, gui = gui, rx = rx, ry = ry,
        mode = "logo", active = true, countdown = AUTOBOOT_SECONDS,
        devices = shared.devices,
    }

    ui.logoScene = gui:createScene("000000")
    ui.menuScene = gui:createScene("001a33")

    -- logo
    local title = ui.logoScene:createLabel(0, 0, rx - 4, math.max(12, math.floor(ry / 5)),
        "SC-BIOS v2", 0x1a1a3a, 0x66ccff)
    title:setCenterX(2)
    title:setCenterY(0)
    ui.logoScene:createText(4, ry - 16, "TOUCH TO OPEN BOOT MENU")
    ui.logoCountdownLabel = ui.logoScene:createText(4, ry - 10,
        "AUTO-BOOT IN " .. ui.countdown .. "S")

    function ui.logoScene:onTick(click)
        if click and click[3] == "pressed" then ui.openMenu() end
    end

    -- menu (пересобирается)
    function ui.rebuildMenu()
        clearSceneChildren(ui.menuScene)
        local y = 2
        local h = 10
        ui.menuScene:createLabel(2, y, rx - 4, h, "BOOT MENU", 0x004488, 0xffffff)
        y = y + h + 1
        ui.menuCountdownLabel = ui.menuScene:createLabel(2, y, rx - 4, 8,
            "AUTO-BOOT IN " .. ui.countdown .. "S", 0x002244, 0xffcc00)
        y = y + 9

        if #ui.devices == 0 then
            ui.menuScene:createLabel(2, y, rx - 4, 8, "NO DEVICES", 0x330000, 0xff6666)
        else
            for _, dev in ipairs(ui.devices) do
                if y + h + 2 > ry - 14 then break end
                local label = dev.name .. (dev.bootable and "" or " [N/A]")
                local btn = ui.menuScene:createButton(2, y, rx - 4, h, false, label,
                    0x003366, 0xffffff, 0x0055aa, 0xffffff)
                if not dev.bootable then
                    btn:setDisabled(true)
                else
                    local captured = dev
                    btn:attachCallback(function(_, state, inZone)
                        if not state and inZone then doBoot(captured) end
                    end)
                end
                y = y + h + 1
            end
        end

        local bw = math.floor((rx - 4) / 2) - 1
        local refresh = ui.menuScene:createButton(2, ry - 12, bw, 10, false, "REFRESH",
            0x444444, 0xffffff, 0x666666, 0xffffff)
        refresh:attachCallback(function(_, state, inZone)
            if not state and inZone then
                shared.refreshDevices()
                for _, u in ipairs(userInterfaces) do
                    u.devices = shared.devices
                    if u.mode == "menu" then u.rebuildMenu() end
                end
            end
        end)
        local back = ui.menuScene:createButton(bw + 3, ry - 12, bw, 10, false, "BACK",
            0x444444, 0xffffff, 0x666666, 0xffffff)
        back:attachCallback(function(_, state, inZone)
            if not state and inZone then ui.showLogo() end
        end)
    end

    function ui.openMenu()
        ui.mode = "menu"
        ui.rebuildMenu()
        ui.menuScene:select()
    end

    function ui.showLogo()
        ui.mode = "logo"
        ui.logoScene:select()
    end

    function ui.deactivate() ui.active = false end

    function ui.tick()
        if not ui.active or fatalError then
            if ui.gui then ui.gui:tick() end
            return
        end
        ui.gui:tick()
        if ui.gui:needFlush() then
            ui.gui:draw()
            ui.display.flush()
        end
    end

    userInterfaces[#userInterfaces + 1] = ui
    return ui
end

-- ================= lifecycle =================
function onStart()
    clearDisplays()
    fatalError = false
    bootRequested = false
    userInterfaces = {}
    initProcess = nil

    local shared
    shared = {
        devices = enumerateDevices(),
        refreshDevices = function()
            shared.devices = enumerateDevices()
            return shared.devices
        end,
    }

    local displays = getComponents("display")
    if #displays == 0 then
        local dev = pickAutoBootDevice(shared.devices)
        if dev then doBoot(dev) else bsod("no bootable medium and no display") end
        return
    end

    for _, display in ipairs(displays) do
        createUI(display, shared)
    end

    bootTimer = timerhost:createTimer(TICKS_PER_SECOND, true)
    bootTimer:setEnabled(true)
    bootTimer:reset()
end

function onTick()
    processhost:tick()
    timerhost:tick()

    if initProcess then
        local err = initProcess:getError()
        if err then
            bsod(err)
            initProcess:destroy()
            initProcess = nil
        end
    end

    if fatalError then return end

    if bootTimer and bootTimer:isTriggered() and not bootRequested then
        bootTimer:reset()

        local anyActive = false
        local minCountdown = math.huge
        for _, ui in ipairs(userInterfaces) do
            if ui.active then
                anyActive = true
                ui.countdown = ui.countdown - 1
                if ui.countdown < minCountdown then minCountdown = ui.countdown end
            end
        end

        if anyActive then
            if minCountdown <= 0 then
                local dev = pickAutoBootDevice(userInterfaces[1].devices)
                if dev then doBoot(dev) else bsod("no bootable medium found") end
            else
                for _, ui in ipairs(userInterfaces) do
                    if ui.active then
                        local text = "AUTO-BOOT IN " .. ui.countdown .. "S"
                        if ui.mode == "logo" and ui.logoCountdownLabel then
                            ui.logoCountdownLabel:setText(text)
                        elseif ui.mode == "menu" and ui.menuCountdownLabel then
                            ui.menuCountdownLabel:setText(text)
                        end
                    end
                end
            end
        end
    end

    for _, ui in ipairs(userInterfaces) do ui.tick() end
end

function onStop()
    processhost:stop()
    if bootTimer then bootTimer:setEnabled(false) end
    clearDisplays()
end

_enableCallbacks = true