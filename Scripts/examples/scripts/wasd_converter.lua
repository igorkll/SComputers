local wasd = getComponents("wasd")[1]
local display = getComponents("display")[1]
display.reset()
display.clear()

function drawLabel(x, y, char, state, color)
    display.fillRect(x, y, (#char * 5) + 1, 7, state and color or "000000")
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

    local currentY = 1
    local yStep = 7

    drawLabel(5,  currentY, "W", wasd.isW(), color)
    currentY = currentY + yStep

    drawLabel(5,  currentY, "S", wasd.isS(), color)
    drawLabel(-1, currentY, "A", wasd.isA(), color)
    drawLabel(11, currentY, "D", wasd.isD(), color)
    currentY = currentY + yStep * 2

    drawLabel(-1, currentY, "W-S: " .. wasd.getWSvalue(), wasd.getWSvalue() ~= 0, color)
    currentY = currentY + yStep
    drawLabel(-1, currentY, "A-D: " .. wasd.getADvalue(), wasd.getADvalue() ~= 0, color)
    currentY = currentY + yStep * 2

    drawLabel(-1, currentY, "L", wasd.isMouseL(), color)
    drawLabel(5, currentY, "C", wasd.isMouseC(), color)
    drawLabel(11, currentY, "R", wasd.isMouseR(), color)
    currentY = currentY + yStep * 2

    drawLabel(-1, currentY, "Q", wasd.isMouseL(), color)
    drawLabel(11, currentY, "R", wasd.isMouseR(), color)
    currentY = currentY + yStep * 2

    drawLabel(-1, currentY, "SPRINT", wasd.isSprint(), color)

    display.flush()
end