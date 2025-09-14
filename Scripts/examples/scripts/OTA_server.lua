--example of an OTA server
--this allows you to update device firmware remotely, while encrypting the code on the server side

local enlua = require("enlua")
local port = getComponent("port")
local timerhost = require("timer").createHost()

local function makeOTAupdate(version)
    return string.format([[local version = %i
local port = getComponent("port")
port.clear()

logPrint("self version: " .. version)

function callback_loop()
    local package = port.nextTable()
    if package then
        if package.type == "OTA" then
            setEncryptedCode(package.bytecode, "version: " .. package.version) --updating the firmware to the new version
            reboot() --reboot to a new firmware version
            return
        end
    end
end]], version)
end

local function sendOTAupdate(code, version)
    port.sendTable({
        type = "OTA",
        bytecode = assert(enlua.compile(code)), --encrypting the code on the server side
        version = version
    })
end

local firmwareVersion = 0
timerhost:task(40, function (timer) --we are releasing an update every second
    firmwareVersion = firmwareVersion + 1
    sendOTAupdate(makeOTAupdate(firmwareVersion), firmwareVersion)
end)

function callback_loop()
    timerhost:tick()
end