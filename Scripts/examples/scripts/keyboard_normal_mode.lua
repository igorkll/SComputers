--example in normal mode

local graphic = require("graphic")

local keyboard = getComponent("keyboard")
local display = getComponent("display")

keyboard.clear()
keyboard.setPrintMode(false)
keyboard.resetButtons()

display.reset()

local rotation = 0

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    --rotate the image with two virtual buttons in the keyboard GUI
    if keyboard.isEsc() then
        rotation = rotation - 1
        if rotation < 0 then rotation = 3 end
    end
    if keyboard.isEnter() then
        rotation = rotation + 1
        if rotation > 3 then rotation = 0 end
    end
    keyboard.resetButtons()
    display.setRotation(rotation)
    
    --displaying the contents of the keyboard buffer on the screen
    display.clear()
    graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), keyboard.read())
    display.flush()
end