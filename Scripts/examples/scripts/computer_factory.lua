--it flashes all connected computers with the firmware at once in encrypted form
--this can be used for automated production of devices with pre-installed firmware

local encryptCode = true
local lockComputer = false

local enlua = require("enlua")

local function makeCode(version)
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

local function flashComputer(computer, version)
    local firmware = makeCode(version)
    if encryptCode then
        computer.env.setEncryptedCode(enlua.compile(firmware), "version: " .. version)
    else
        computer.env.setCode(firmware)
    end
    if lockComputer then
        computer.env.setLock(true)
        computer.env.setInvisible(true) --when you turn on your computer, it will be impossible to detect using getParentComputers and getChildComputers. however, you can still provide the API using setComponentApi
    end
    computer.env.setAlwaysOn(true)
end

local function checkComputer(computer)
    if not computer.env.getAlwaysOn() then
        flashComputer(computer, 0)
    end
end

function callback_loop()
    for _, computer in ipairs(getParentComputers()) do
        checkComputer(computer)
    end

    for _, computer in ipairs(getChildComputers()) do
        checkComputer(computer)
    end
end