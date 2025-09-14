local colors = require("colors")
local display = getComponent("display")

function callback_loop()
    local strs = {}
    local cols = {}
    if input(colors.str.Red[2]) then
        table.insert(strs, "RED")
        table.insert(cols, 0xff0000)
    end
    if input(colors.str.Green[2]) then
        table.insert(strs, "GREEN")
        table.insert(cols, 0x00ff00)
    end
    if input(colors.str.Blue[2]) then
        table.insert(strs, "BLUE")
        table.insert(cols, 0x0000ff)
    end
    display.clear()
    for i, str in ipairs(strs) do
        display.drawText(0, (i - 1) * (display.getFontHeight() + 1), str, cols[i])
    end
    display.flush()
end