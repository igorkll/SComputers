local scriptData = ...
local system = require("system")
local terminal = scriptData.args.terminal

function onStart()
    terminal.write("hello, world!\n")
    system.closeApp(scriptData)
end

_enableCallbacks = true