local scriptData = ...
local system = require("system")
local terminal = scriptData.args.terminal

local counter = 0

function onStart()
end

function onTick()
    terminal.write(counter .. "\n")
    counter = counter + 1
end

_enableCallbacks = true