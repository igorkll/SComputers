local display = getComponent("display")
local width, height = display.getSize()

function onTick(dt)
    for ix = 0, width - 1 do
        for iy = 0, height - 1 do
            display.drawPixel(ix, iy, math.random(0, 0xffffff))
        end
    end
    display.flush()
end

_enableCallbacks = true