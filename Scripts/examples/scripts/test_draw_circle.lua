local display = getComponent("display")
local side = display.getWidth()
local haldSize = side / 2
local counter = 0
local timer = -math.huge

function callback_loop()
    local uptime = getUptime()
    if uptime - timer > 160 then
        local drawMethod = counter % 3
        local currentSide = haldSize
        if counter >= 3 then
            currentSide = currentSide - 1
        end

        display.clear()
        display.fillCircle(haldSize, haldSize, currentSide, 0x888888)
        if drawMethod == 0 then
            display.drawCircle(haldSize, haldSize, currentSide, 0xff0000)
            display.drawText(1, 1, "DRAW", 0x00ffff)
            display.drawText(1, 1 + 6, "CIRCLE", 0x00ffff)
        elseif drawMethod == 1 then
            display.drawCircleEvenly(haldSize, haldSize, currentSide, 0xff0000)
            display.drawText(1, 1, "DRAW", 0x00ffff)
            display.drawText(1, 1 + 6, "CIRCLE", 0x00ffff)
            display.drawText(1, 1 + 6 + 6, "EVENLY", 0x00ffff)
        elseif drawMethod == 2 then
            display.drawCircleVeryEvenly(haldSize, haldSize, currentSide, 0xff0000)
            display.drawText(1, 1, "DRAW", 0x00ffff)
            display.drawText(1, 1 + 6, "CIRCLE", 0x00ffff)
            display.drawText(1, 1 + 6 + 6, "VERY", 0x00ffff)
            display.drawText(1, 1 + 6 + 6 + 6, "EVENLY", 0x00ffff)
        end
        display.drawText(1, display.getHeight() - 6, counter >= 3 and "odd radius" or "even radius", 0xffff00)
        display.forceFlush()

        timer = uptime
        counter = counter + 1
        if counter > 5 then
            counter = 0
        end
    end
end