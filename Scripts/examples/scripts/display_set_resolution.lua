local display = getComponent("display")
local fonts = require("fonts")
local dx, dy = display.getDefaultResolution()

display.reset()
display.setResolution(dx, dy / 4) --demonstrates the ability to change the screen resolution in real time. you can also distort the geometry by changing it disproportionately
display.setFont(fonts.lgc_5x5)

display.clear()
display.drawText(1, 1, "HELLO, WORLD!")
display.flush()

function callback_loop()
	if _endtick then
		display.clear()
		display.flush()
	end
end