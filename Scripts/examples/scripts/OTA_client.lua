--this code demonstrates a remote firmware update
--the code accepts the update in encrypted form
--for the first computer firmware, you can use the "computer factory" example.

local version = 0
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
end