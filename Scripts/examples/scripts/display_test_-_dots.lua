local display = getComponent("display")
local width, height = display.getSize()

function onTick(dt)
    for i = 1, 2000 do
        display.drawPixel(math.random(0, width - 1), math.random(0, height - 1), math.random(0, 0xffffff))
    end
    display.flush()
end

_enableCallbacks = true