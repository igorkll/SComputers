--the picture on the display under water can be very blurred
--this is how game shaders work. However, if you switch the material to 2 (plastic), the display will be visible underwater. this can be used for example in a submarine

local graphic = require("graphic")
local display = getComponent("display")

function onStart()
    display.setMaterial(2) --the display must be visible underwater
    display.clear(0x0000ff)
    graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), "display for underwater use", 0x00ffff, true, true)
    display.flush()
end

function onStop()
    display.clear()
    display.flush()
end

_enableCallbacks = true