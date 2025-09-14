local colors = require("colors")
local display = getComponent("display")

function drawGradient()
    local width = display.getWidth()
    local height = display.getHeight()

    for x = 0, width - 1 do
        for y = 0, height - 1 do
            local r = x / width
            local g = y / height
            local b = 0.5
            display.drawPixel(x, y, colors.packFloat(r, g, b))
        end
    end

    display.flush()
end

drawGradient()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end
end