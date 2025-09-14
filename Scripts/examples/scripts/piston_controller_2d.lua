local pistonController = getComponent("pistonController")
local speed = 3
local height = 4
local side = math.floor(math.sqrt(pistonController.getPistonsCount()) + 0.5)

function onTick(dt)
    local tick = getUptime() * speed
    for i = 0, pistonController.getPistonsCount() - 1 do
        local ii = i % side
        pistonController.setLength(i, ((math.sin(math.rad(tick - (ii * 16) - (math.floor(i / side) * 16))) + 1) / 2) * height)
        pistonController.setVelocity(i, pistonController.getMaxVelocity(i))
    end
end

_enableCallbacks = true