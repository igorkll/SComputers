--example for display 128x128
local display = getComponents("display")[1]
display.reset()
display.clearClicks()
display.setClicksAllowed(true)
local rx, ry = display.getWidth(), display.getHeight()

local gui = require("gui").new(display)
local styles = require("styles")
local objs = require("objs")
local scene = gui:createScene("777777")

local horizontalTabBar = scene:createCustom(0, 0, rx, 8, objs.tabbar, 0x444444, false, nil, 3)

for ix = 1, 4 do
    local window = horizontalTabBar:createOtherspaceWindow()
    local verticleTabBar = window:createCustom(0, 0, 26, ry - horizontalTabBar.sizeY, objs.tabbar, 0x444444, true, nil, 3)
    for iy = 1, 4 do
        local window2 = verticleTabBar:createOtherspaceWindow()
        verticleTabBar:addTab("VTAB" .. iy, window2)

        window2:createLabel(0, 0, window2.sizeX, window2.sizeY, "HTAB: " .. ix .. "\n" .. "VTAB: " .. iy, 0x000088, 0xffffff)
    end
    horizontalTabBar:addTab("HTAB" .. ix, window)
end

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