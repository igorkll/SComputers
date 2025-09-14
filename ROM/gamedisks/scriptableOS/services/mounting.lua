local system = require("system")

local disksAttachCheck = {}
local romsAttachCheck = {}
function onTick()
    system.checkAttachDetachComponents("disk", disksAttachCheck, function (attach, component, data)
        if attach then
            system.mount("disk", data.index, component)
        else
            system.fs:unmount(component)
        end
    end)

    system.checkAttachDetachComponents("rom", romsAttachCheck, function (attach, component, data)
        if attach then
            local ok, result = pcall(component.openFilesystemImage)
            if ok and type(result) == "table" then
                data.fs = result
            else
                local ok, result = pcall(component.openFilesystemDump)
                if ok and type(result) == "table" then
                    data.fs = result
                end
            end

            if data.fs then
                system.mount("rom", data.index, data.fs)
            end
        elseif data.fs then
            system.fs:unmount(data.fs)
        end
    end)
end

_enableCallbacks = true