local colors = require("colors")
local display = getComponent("display")

function drawGradient()
    local width = display.getWidth()
    local height = display.getHeight()

    for x = 0, width - 1 do
        display.fillRect(x, 0, 1, height, colors.combineColorToNumber(x / (width - 1), colors.pack(colors.hsvToRgb256(255 - (getUptime() % 256), 255, 255)), colors.pack(colors.hsvToRgb256(getUptime() % 256, 255, 255))))
    end

    display.flush()
end

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    drawGradient()
end