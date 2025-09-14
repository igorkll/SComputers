local motors = getComponents("motor")
local motor1 = motors[1]
local motor2 = motors[2]

motor1.setSoundType(1)
motor1.setStrength(200)
motor1.setAngle(nil)
motor1.setActive(true)

motor2.setSoundType(1)
motor2.setStrength(200)
motor2.setVelocity(200)
motor2.setAngle(0)
motor2.setActive(true)

function callback_loop()
    local sin = math.sin(math.rad(getUptime()))

    motor1.setVelocity(sin * 5)
    motor2.setAngle(sin)
end