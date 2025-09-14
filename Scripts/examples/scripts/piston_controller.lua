local pistonController = getComponent("pistonController")
local speed = 3
local height = 4

function onTick(dt)
    local tick = getUptime() * speed
    for i = 0, pistonController.getPistonsCount() - 1 do
        pistonController.setLength(i, ((math.sin(math.rad(tick - (i * 16))) + 1) / 2) * height)
        pistonController.setVelocity(i, pistonController.getMaxVelocity(i))
    end
end

_enableCallbacks = true