local colors = require("colors")
local display = getComponent("display")

function callback_loop()
    local inputs = ninput()
    display.clear()
    for i = 1, #inputs do
        display.drawText(0, (i - 1) * (display.getFontHeight() + 1), inputs[i])
    end
    display.flush()
end