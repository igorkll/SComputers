local moveVelocity = 30
local turnVelocity = 20
local strength = 1000

local moveSmoothing = 0.1
local turnSmoothing = 0.4

---------------------------------------

local wasd = getComponent("wasd")
local motors = getComponents("motor")
local leftMotor = motors[1]
local rightMotor = motors[2]

local moveValue = 0
local turnValue = 0

function onStart()
    leftMotor.setActive(true)
    rightMotor.setActive(true)

    leftMotor.setVelocity(0)
    rightMotor.setVelocity(0)

    leftMotor.setStrength(strength)
    rightMotor.setStrength(strength)
end

function onTick(dt)
    local ws = wasd.getWSvalue()
    local ad = wasd.getADvalue()

    moveValue = moveValue + ((ws - moveValue) * moveSmoothing)
    turnValue = turnValue + ((ad - turnValue) * turnSmoothing)

    local velMoveValue = moveValue * moveVelocity
    local velTurnValue = turnValue * turnVelocity

    leftMotor.setVelocity(velMoveValue + velTurnValue)
    rightMotor.setVelocity(velMoveValue - velTurnValue)
end

function onStop()
    leftMotor.setActive(false)
    rightMotor.setActive(false)
end

_enableCallbacks = true