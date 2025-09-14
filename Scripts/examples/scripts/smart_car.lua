--the example is made for a 64x48 display

local motor = getComponent("motor")
motor.setActive(true)

local display = getComponent("display")
display.reset()
display.clear()
display.setClicksAllowed(true)

local width, height = display.getWidth(), display.getHeight()

local colors = require("colors")
local gui = require("gui").new(display)
local utils = require("utils")

--------------------------------------------- scene 1

local scene = gui:createScene(colors.sm.Gray[4])
local velocityLabel = scene:createText(1, 1, "", colors.str.Green[2])
local velocityAdd = scene:createButton(width - 7, 1, 6, 5, false, "+")
local velocitySub = scene:createButton(width - 14, 1, 6, 5, false, "-")

local strengthLabel = scene:createText(1, 7, "", colors.str.Green[2])
local strengthAdd = scene:createButton(width - 7, 7, 6, 5, false, "+")
local strengthSub = scene:createButton(width - 14, 7, 6, 5, false, "-")

local loadLabel = scene:createText(1, 7 + 6, "", colors.str.Green[2])
local chargeLabel = scene:createText(1, 7 + 12, "", colors.str.Green[2])

--------------------------------------------- scene 2

local scene2 = gui:createScene(colors.str.Gray[2])
scene2:createTextBox(0, 0, scene2.sizeX, scene2.sizeY, "NO ENERGY!", nil, colors.str.Red[2], true, true)

--------------------------------------------- main

local strength = 100
local velocity = 100

local oldWork

function callback_loop()
    if _endtick then
        motor.setActive(false)

        display.clear()
        display.forceFlush()
        return
    end

    local currentWork = motor.isWorkAvailable()
    if currentWork ~= oldWork then
        if currentWork then
            scene:select()
        else
            scene2:select()
        end
        oldWork = currentWork
    end
    
    velocityLabel:clear()
    velocityLabel:setText("VEL:" .. tostring(velocity))
    velocityLabel:update()

    strengthLabel:clear()
    strengthLabel:setText("PWR:" .. tostring(strength))
    strengthLabel:update()

    loadLabel:clear()
    loadLabel:setText("LOAD:" .. tostring(utils.roundTo((motor.getChargeDelta() / motor.getStrength() / motor.getBearingsCount()) * 100, 1)) .. "%")
    loadLabel:update()

    chargeLabel:clear()
    chargeLabel:setText("CHRG:" .. tostring(motor.getAvailableBatteries() + utils.roundTo(motor.getCharge() / motor.getChargeAdditions())) .. "%")
    chargeLabel:update()
    
    motor.setStrength(strength)
    motor.setVelocity(ninput()[1] * velocity)

    gui:tick()
    if velocityAdd:isPress() then
        velocity = velocity + 25
    elseif velocitySub:isPress() then
        velocity = velocity - 25
    end
    if strengthAdd:isPress() then
        strength = strength + 25
    elseif strengthSub:isPress() then
        strength = strength - 25
    end
    if velocity > motor.maxVelocity() then
        velocity = motor.maxVelocity()
    elseif velocity < 25 then
        velocity = 25
    end
    if strength > motor.maxStrength() then
        strength = motor.maxStrength()
    elseif strength < 25 then
        strength = 25
    end
    
    if gui:needFlush() then
        gui:draw()
        display.flush()
    end
end