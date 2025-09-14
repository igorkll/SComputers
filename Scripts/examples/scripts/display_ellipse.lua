local display = getComponent("display")
display.reset()
local rx, ry = display.getSize()

display.clear()
display.fillEllipse(16, 16, rx - 32, ry - 32, 15, 0xff0000)
display.drawEllipse(16, 16, rx - 32, ry - 32, 15, 0xff00ff)
display.flush()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
    end
end