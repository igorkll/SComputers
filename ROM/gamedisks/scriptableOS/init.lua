local rootfs = ...

do
    local function raw_loadfile(path)
        return load(rootfs.readFile(path), "=" .. path)
    end

    local system = assert(raw_loadfile("/libs/system.lua"))(rootfs)
end

local system = require("system")
local vfs = require("vfs")

function onStart()
    -- launching system services
    local servicesPath = "/services"
    for _, file in ipairs(system.fs:getFileList(servicesPath)) do
        assert(system.execute(vfs.concat(servicesPath, file)))
    end

    -- applications initialization
    for _, appinfo in ipairs(system.installedApps()) do
        system.initApp(appinfo)
    end
end

function onTick()
    system.processhost:tick()

    for _, process in ipairs(system.processhost:list()) do
        local err = process:getError()
        if err then
            error(err, 2)
        end
    end
end

function onStop()
    system.processhost:destroy()
end

_enableCallbacks = true