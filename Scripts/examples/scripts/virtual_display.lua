--makes a holographic display from a holographic projector (in fact, you'd better use a separate part of the holographic display for this)
local vdisplay = require("vdisplay")
local holo = getComponent("holoprojector")
holo.reset()
holo.clear()
holo.flush()

local width, height = 32, 32
local idBuffer = {}

local callbacks = {
    set = function (self, x, y, color)
        local index = x + (y * width)
        if idBuffer[index] then holo.delVoxel(idBuffer[index]) end
        idBuffer[index] = holo.addVoxel(x - (width / 2), (((height - 1) - y) - (height / 2)) + 20, 0, color, 2)
    end,
    flush = function (self, isForce)
        holo.flush()
    end
}
setComponentApi("display", vdisplay.create(callbacks, width, height)) --this line will cause your computer to be identified by other computers as a display

function callback_loop()
    if _endtick then
        holo.reset()
        holo.clear()
        holo.flush()
        return
    end

    callbacks.update()

    --[[ an example of simulated clicks
    callbacks.pushClick({0, 0, "pressed", 1})
    callbacks.pushClick({0, 0, "released", 1})
    ]]

    --[[ if you know that someone is not looking at your screen now, then it is better to inform the library about it
    if mySecretSource_thereIsNoOneAround then
        callbacks.updateAudience(0)
    else
        callbacks.updateAudience(1)
    end
    ]]
end