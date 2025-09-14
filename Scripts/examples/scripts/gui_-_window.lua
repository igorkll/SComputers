--the example was created for a 128x128 screen
local display = getComponents("display")[1]
display.reset()
display.clearClicks()
display.setClicksAllowed(true)
local rx, ry = display.getWidth(), display.getHeight()

local gui = require("gui").new(display)
local styles = require("styles")
local scene = gui:createScene("777777")

local function addWindow()
    local window = scene:createWindow(16, 16, 64, 64, "2d2d2d")
    window:upPanel("058db8", "ffffff", "test window", true)
    window:setDraggable(true)

    local closeButton = window:panelButton(7, false, "X", "00a2d5", "0054a1", "00c2ff", "0085ff")
    closeButton:attachCallback(function(self, state, inZone)
        if not state and inZone then
            window:destroy()
        end
    end)

    local oldText
    for i = 1, 4 do
        local text = window:createText(nil, nil, "switch " .. i .. ": ")
        if oldText then text:setDown(oldText) end
        local switch = window:createButton(nil, nil, 8, 4, true, nil, "444444", "ffffff", "44b300", "ffffff")
        switch:setCustomStyle(styles.switch)
        switch:setRight(text)
        oldText = text
    end

    local window2 = window:createWindow(nil, nil, 32, 16, "333377")
    window2:setDown(oldText)
    window2:upPanel("058db8", "ffffff", "test", true)
    window2:minimize(true)
    local switch = window2:createButton(nil, nil, 14, 8, true, nil, "444444", "ffffff", "44b300", "ffffff")
    switch:setCustomStyle(styles.switch)
end

local addWindowButton = scene:createButton(nil, nil, 32, 32, false, "WINDOW")
addWindowButton:attachCallback(function(self, state, inZone)
    if state then
        addWindow()
    end
end)

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    gui:tick()
    if gui:needFlush() then
        gui:draw()
        display.flush()
    end
end