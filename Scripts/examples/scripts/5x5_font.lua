--example for display 256x256
--full fonts list: https://igorkll.github.io/fonts.html

local fonts = require("fonts")
local display = getComponent("display")

display.reset()
display.setFont(fonts.lgc_5x5)
display.setUtf8Support(true)
display.clear()

local posY = 1
local function drawText(text)
    local boxX, boxY = display.calcTextBox(text)
    display.fillRect(1, posY, boxX, boxY, 0x005500)
    display.drawText(1, posY, text)
    posY = posY + display.getFontHeight() + 3
end

drawText("font - 5x5")
drawText("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
drawText("abcdefghijklmnopqrstuvwxyz")
drawText("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
drawText("абвгдеёжзийклмнопрстуфхцчшщъыьэюя")
drawText("0123456789")
drawText("+-*/\\\"'@#!<>?{}[]()&^%$#")
display.flush()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end
end