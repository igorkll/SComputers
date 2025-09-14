local system = require("system")

local terminalAttachCheck = {}
local displayAttachCheck = {}
function onTick()
    system.checkAttachDetachComponents("terminal", terminalAttachCheck, function (attach, component, data)
        if attach then
            data.scriptData = assert(system.execute("terminal_shell", {
                terminal = component
            }))
        elseif data.scriptData then
            data.scriptData.process:destroy()
        end
    end)

    system.checkAttachDetachComponents("display", displayAttachCheck, function (attach, component, data)
        if attach then
            data.scriptData = assert(system.execute("gui_shell", {
                display = component
            }))
        elseif data.scriptData then
            data.scriptData.process:destroy()
        end
    end)
end

_enableCallbacks = true