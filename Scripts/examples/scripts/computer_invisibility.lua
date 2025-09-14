--the invisibility flag makes it so that other computers cannot see this computer using the getParentComputers and getChildComputers methods
--this is necessary in order to protect the computer from direct external interference
--let's say you have blocked the computer's GUI. the computer code can still be read and written using another computer
--to protect against this, there is an invisibility flag
--if you need to protect your code from direct reading/writing to ENV, but you need to communicate with other computers,
--then you can use the network port or use the setComponentApi method so that your computer simulates the behavior
--of the component and your API is accessible via getComponents

--now you will not be able to interact with this computer using getParentComputers and getChildComputers
setInvisible(true)
--now you can't open the gui of the computer
setLock(true)

setComponentApi("tunnel", {
    unlock = function()
        --my unlock condition
        setInvisible(false)
        setLock(false)
    end
})

--to unlock it, you can now use the following code on another
--this is somewhat similar to unlocking the bootloader on Xiaomi phone
--[[
local tunnel = getComponent("tunnel")
tunnel.unlock()

function callback_loop()
    
end
]]

--if the invisibility flag is not set, then it would be possible to unlock the computer bypassing your API with your checks
--[[
for _, computer in ipairs(getParentComputers()) do
    computer.env.setLock(false)
end

for _, computer in ipairs(getChildComputers()) do
    computer.env.setLock(false)
end
]]

function callback_loop()
    
end