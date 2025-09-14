--example in print mode
--this mode is great for creating games. In this case, the WASD buttons control the ball on the screen

local keyboard = getComponent("keyboard")
local display = getComponent("display")

keyboard.clear()
keyboard.setPrintMode(true)
keyboard.setSoundEnable(false)
keyboard.resetButtons()

display.reset()

local posX, posY = display.getWidth() / 2, display.getHeight() / 2

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    local buffer = keyboard.read()
    keyboard.clear()

    for i = 1, #buffer do
        local chr = buffer:sub(i, i):lower()
        if chr == "w" then
            posY = posY - 1
        elseif chr == "s" then
            posY = posY + 1
        elseif chr == "a" then
            posX = posX - 1
        elseif chr == "d" then
            posX = posX + 1
        end
    end

    display.clear()
    display.drawCircle(posX, posY, 8)
    display.flush()
end