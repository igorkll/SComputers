--
local smartsign = getComponent("smartsign")

local text = "hello, world! abcdef! TEEEESTTTTTTTTT!>!>!>!>!>!>>"

local currentTheme = 0
local maxTheme = 8

local lenText = #text
local maxText = smartsign.getMaxTextLen()
local textOffset = 0

function onTick()
    local textOffsetFloor = math.floor(textOffset)
    local text = text:sub(1 + textOffsetFloor, maxText + textOffsetFloor)
    while #text < maxText do
        text = text .. "\\"
    end

    smartsign.setText(text)
    smartsign.setTheme((currentTheme % maxTheme) + 1)

    textOffset = textOffset + (0.1 * (getSkippedTicks() + 1))
    if textOffset - 1 >= lenText then
        textOffset = 0
        currentTheme = currentTheme + 1
    end
end

function onStop()
    smartsign.setTheme(1)
    smartsign.setText("")
end

_enableCallbacks = true