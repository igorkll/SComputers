local wasd = getComponents("wasd")[1]
local display = getComponents("display")[1]
display.reset()
display.clear()

function drawLabel(x, y, char, state, color)
    display.fillRect(x, y, 6, 7, state and color or "000000")
    display.drawText(x + 1, y + 1, char, state and "000000" or color)
end

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    local color = wasd.isSeated() and "00ff00" or "ff0000"
    display.clear()
    drawLabel(5,  1, "W", wasd.isW(), color)
    drawLabel(5,  8, "S", wasd.isS(), color)
    drawLabel(-1, 8, "A", wasd.isA(), color)
    drawLabel(11, 8, "D", wasd.isD(), color)
    display.flush()
end