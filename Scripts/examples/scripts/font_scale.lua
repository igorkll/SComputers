local display = getComponent("display")
local chars = {"A", "B", "C", "D"}

display.clear()
local posY = 1
for i = 1, #chars do
    local posX = 1
    for scale = 0.5, 2, 0.25 do
        display.setFontScale(scale, scale)
        display.drawText(posX, posY, chars[i], 0xff0000)
        posX = posX + display.getFontWidth() + 3
    end
    posY = posY + display.getFontHeight() + 3
end
display.flush()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end
end