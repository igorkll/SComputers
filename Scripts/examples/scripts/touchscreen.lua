local display = getComponent("display")
local width, height = display.getSize()
local minSide = math.min(width, height)
local ballRadius = minSide / 32
local fontScale = minSide / 128
if fontScale < 2 then fontScale = 1 end
display.setClicksAllowed(true)
display.setFontScale(fontScale, fontScale)
display.setTextSpacing(math.ceil(fontScale))

function onTick()
    local touchs = display.getTouchs()

    display.clear()
    for _, touch in ipairs(touchs) do
        if touch then
            display.fillCircle(touch.x, touch.y, ballRadius, touch.button ~= 1 and 0x0000ff or 0xff0000)
            display.drawCenteredText(touch.x, touch.y + (ballRadius * 1.2), touch.nickname, 0xffffff, true, false)
        end
    end
    display.flush()
end

function onStop()
    display.clear()
    display.flush()
end

_enableCallbacks = true