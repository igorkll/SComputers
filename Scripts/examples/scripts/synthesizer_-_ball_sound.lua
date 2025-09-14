--full: https://igorkll.github.io/synthesizer.html

local utils = require("utils")
local synthesizer = getComponent("synthesizer")

function onTick(dt)
    local sin = math.sin(math.rad(getTick() * 4))
    synthesizer.ballBeep(utils.map(sin, -1, 1, 25, 40), 5)
end

function onStop()
    synthesizer.stop()
end

_enableCallbacks = true