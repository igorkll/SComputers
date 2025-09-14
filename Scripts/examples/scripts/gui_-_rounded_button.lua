--example for display 128x96

local display = getComponents("display")[1]
display.reset()
display.clearClicks()
display.setSkipAtLags(false)
display.setClicksAllowed(true)
local rx, ry = display.getWidth(), display.getHeight()

local gui = require("gui").new(display)
local styles = require("styles")

local scene = gui:createScene("7abfa0")
local button = scene:createButton(16, 16, rx - 32, ry - 32, true, "ROUNDED!!", "444444", "ffffff", "44b300", "ffffff")
button:setCustomStyle(styles.rounded)
scene:select()

--button.cornerRadius = 5 --you can set your own, but the default is 30 percent. the cornerRadius is set in pixels
button:setStColor(0xffffff)
button:setPstColor(0x03ca6e)
--button:setIstColor(0x88ff88)
--button:setIbgColor(0xffffff)
--button:setIfgColor(0x000000)

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        out(false)
        return
    end

    gui:tick()

    out(button:getState())

    if gui:needFlush() then
        gui:draw()
        display.flush()
    end
end