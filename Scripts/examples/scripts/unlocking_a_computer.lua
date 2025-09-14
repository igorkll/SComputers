--this code will help you unlock a randomly locked computer
--run this code on another computer and connect it to the blocked one. when you turn on this computer, the lock will disappear from the connected one
--this WILL NOT WORK if the invisibility flag is set on the locked computer (because it makes it invisible to direct access via getParentComputers and getChildComputers)

for _, computer in ipairs(getParentComputers()) do
    computer.env.setLock(false)
end

for _, computer in ipairs(getChildComputers()) do
    computer.env.setLock(false)
end