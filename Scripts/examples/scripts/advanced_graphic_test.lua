--written for a 640x360 display
--you can find this screen in the addon: https://steamcommunity.com/sharedfiles/filedetails/?edit=true&id=3344779247

local timerhost = require("timer").createHost()
local fonts = require("fonts")
local graphic = require("graphic")

local display = getComponent("display")
display.reset()
display.clear()
display.flush()

local deltaValue

local mode = 1
local modes = {
    function (first)
        if first then
            display.clear()
            display.setFont(fonts.impact_32)
            graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), "graphic test\nline 1\nline 2", 0xff0000, true, true)
        end
    end,
    function (first)
        if first then
            display.clear()
            display.setFont(fonts.impact_72)
            graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), "graphic test\nline 1\nline 2", 0xff0000, true, true)
        end
    end,
    function (first)
        if first then
            display.clear()
            display.setFont(fonts.GOST_A_32)
            graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), "graphic test\nGOST A", 0xff0000, true, true)
        end
    end,
    function (first)
        if first then
            display.clear()
            display.setFont(fonts.GOST_A_72)
            graphic.textBox(display, 0, 0, display.getWidth(), display.getHeight(), "graphic test\nGOST A", 0xff0000, true, true)
        end
    end,
    function (first, data)
        display.clear()
        display.setFont(fonts.impact_32)
        local text = "TEST display.calcTextBox"
        local sx, sy = display.calcTextBox(text)
        display.fillRect(1, 1, sx, sy, 0x00ff00)
        display.drawText(1, 1, text, 0xff0000)
    end,
    function (first, data)
        display.clear()
        display.setFont(fonts.impact_32)
        local text = {"real", "time", "font", "scaling"}
        local currentY = 1
        for i, t in ipairs(text) do
            display.setFontScale(i / 2, i / 2)
            display.drawText(1, currentY, t, 0xff0000)
            currentY = currentY + display.getFontHeight()
        end
        display.setFontScale(1, 1)
        display.flush()
    end,
    function (first, data)
        data.size = data.size or 1
        display.clear()
        display.setFont(fonts.impact_32)
        display.drawText(1, 1, "display.drawRect test", 0xff0000)
        display.drawRect(16, 72, display.getWidth() - 32, display.getHeight() - (72 * 2), 0xff0000, data.size)
        display.flush()
        data.size = data.size + deltaValue
    end,
    function (first, data)
        data.size = data.size or 1
        display.clear()
        display.setFont(fonts.impact_32)
        display.drawText(1, 1, "display.drawCircleVeryEvenly test", 0xff0000)
        display.drawCircleVeryEvenly(display.getWidth() / 2, display.getHeight() / 2, math.min(display.getSize()) / 3, 0xff0000, data.size)
        display.flush()
        data.size = data.size + deltaValue
    end,
    function (first, data)
        data.size = data.size or 1
        display.clear()
        display.setFont(fonts.impact_32)
        display.drawText(1, 1, "display.drawWidePoly test (round off)", 0xff0000)
        local width = display.getWidth()
        local height = display.getHeight()
        local width4 = display.getWidth() / 4
        local height4 = display.getHeight() / 4
        display.drawWidePoly(0xff0000, data.size, false, width4, height4, width4, height - height4, width - width4, height - height4)
        display.flush()
        data.size = data.size + deltaValue
    end,
    function (first, data)
        data.size = data.size or 1
        display.clear()
        display.setFont(fonts.impact_32)
        display.drawText(1, 1, "display.drawWidePoly test (round on)", 0xff0000)
        local width = display.getWidth()
        local height = display.getHeight()
        local width4 = display.getWidth() / 4
        local height4 = display.getHeight() / 4
        display.fillWidePoly(0xff0000, data.size, true, width4, height4, width4, height - height4, width - width4, height - height4)
        display.flush()
        data.size = data.size + deltaValue
    end,
    function (first, data)
        data.size = data.size or 1
        display.clear()
        display.setFont(fonts.impact_32)
        display.drawText(1, 1, "display.drawLine test (round off)", 0xff0000)
        local width = display.getWidth()
        local height = display.getHeight()
        local width4 = display.getWidth() / 4
        local height4 = display.getHeight() / 4
        display.drawLine(height4, height4, width - height4, height - height4, 0xff0000, data.size)
        display.flush()
        data.size = data.size + deltaValue
    end,
    function (first, data)
        data.size = data.size or 1
        display.clear()
        display.setFont(fonts.impact_32)
        display.drawText(1, 1, "display.drawLine test (round on)", 0xff0000)
        local width = display.getWidth()
        local height = display.getHeight()
        local width4 = display.getWidth() / 4
        local height4 = display.getHeight() / 4
        display.drawLine(height4, height4, width - height4, height - height4, 0xff0000, data.size, true)
        display.flush()
        data.size = data.size + deltaValue
    end
}

local firstFlag = true
local stateData = {}
local timer = timerhost:createTimer(40 * 2, true, function (timer)
    firstFlag = true
    stateData = {}
    mode = mode + 1
    if mode > #modes then
        mode = 1
    end
end)

timerhost:setEnabledAll(true)

local skippedTicks = 0
function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    timerhost:tick()

    if getLagScore() > 10 then
        skippedTicks = skippedTicks + getSkippedTicks() + 1
        return
    end

    deltaValue = 1 + getSkippedTicks() + skippedTicks
    skippedTicks = 0
    modes[mode](firstFlag, stateData)
    firstFlag = false
    display.flush()
end