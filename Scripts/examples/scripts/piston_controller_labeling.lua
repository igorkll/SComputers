local p1 = getComponentByLabel("pistonController", "1")
local p2 = getComponentByLabel("pistonController", "2")

function onTick(dt)
    local state = getTick() % 40 >= 20
    p1.setVelocity(0, p1.getMaxVelocity(0))
    p2.setVelocity(0, p2.getMaxVelocity(0))
    p1.setLength(0, state and 4 or 0)
    p2.setLength(0, state and 0 or 4)
end

_enableCallbacks = true