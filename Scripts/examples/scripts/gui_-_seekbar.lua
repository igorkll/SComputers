--the example was created for a 128x128 screen
local objs = require("objs")

local display = getComponent("display")
display.reset()
display.clearClicks()
display.setClicksAllowed(true)
local rx, ry = display.getWidth(), display.getHeight()

local gui = require("gui").new(display)
local scene = gui:createScene("333333")

local offset = 4
local thickness = 16

local seekbar1 = scene:createCustom(offset, offset, rx - (offset * 2), thickness, objs.seekbar, false)
local seekbar2 = scene:createCustom(offset, (offset * 2) + thickness, thickness, ry - thickness - (offset * 3), objs.seekbar, true)

local function onValueChanged(self, value)
    print("value changed: ", self.seekbarNumber, value)
end

seekbar1.onValueChanged = onValueChanged
seekbar2.onValueChanged = onValueChanged
seekbar1.seekbarNumber = 1
seekbar2.seekbarNumber = 2

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