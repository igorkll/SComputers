--example for display 256x256
--full fonts list: https://igorkll.github.io/fonts.html

local fonts = require("fonts")
local display = getComponent("display")

display.reset()
display.setTextSpacing(6) --in such large fonts, it would be more logical to spread the characters a little more than 1 pixel apart
display.setFontScale(1.8, 1.8) --is 32x32 small? you can make any font bigger!
display.clear()
local posY = 1
local text = "TEST"

display.setFont(fonts.impact_32)
local boxX, boxY = display.calcTextBox(text)
display.fillRect(1, posY, boxX, boxY, 0x00ff00)
display.drawText(1, posY, text, 0xff0000)
posY = posY + display.getFontHeight() + 3

display.setFont(fonts.verdana_32)
local boxX, boxY = display.calcTextBox(text)
display.fillRect(1, posY, boxX, boxY, 0x00ff00)
display.drawText(1, posY, text, 0xff0000)
posY = posY + display.getFontHeight() + 3

display.setFont(fonts.seguibl_32)
local boxX, boxY = display.calcTextBox(text)
display.fillRect(1, posY, boxX, boxY, 0x00ff00)
display.drawText(1, posY, text, 0xff0000)
posY = posY + display.getFontHeight() + 3

display.setFont(fonts.arial_32)
local boxX, boxY = display.calcTextBox(text)
display.fillRect(1, posY, boxX, boxY, 0x00ff00)
display.drawText(1, posY, text, 0xff0000)
posY = posY + display.getFontHeight() + 3

display.flush()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end
end