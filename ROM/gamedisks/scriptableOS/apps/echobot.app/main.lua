local scriptData = ...
local system = require("system")
local terminal = scriptData.args.terminal

function onTick()
    local text = terminal.read()
    if text then
        terminal.write(text .. "\n")
    end
end

_enableCallbacks = true