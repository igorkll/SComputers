local display = getComponents("display")[1]
display.reset()
display.clearClicks()
display.setClicksAllowed(true)
local rx, ry = display.getWidth(), display.getHeight()

local gui = require("gui").new(display)
local styles = require("styles")

local scene = gui:createScene("0000ff")
local switch = scene:createButton(4, (ry / 2) - 16, rx - 8, 32, true, nil, "444444", "ffffff", "44b300", "ffffff")
switch:setCustomStyle(styles.switch)
scene:select()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        out(false)
        return
    end

    gui:tick()

    out(switch:getState())

    if gui:needFlush() then
        gui:draw()
        display.flush()
    end
end