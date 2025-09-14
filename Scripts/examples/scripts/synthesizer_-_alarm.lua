local timerhost = require("timer").createHost()
local synthesizer = getComponent("synthesizer")

local alarmCurrent = 1
local alarmCount = 4
local timer = timerhost:createTimer(160, true, function ()
    synthesizer.alarmBeep(alarmCurrent)
    alarmCurrent = alarmCurrent + 1
    if alarmCurrent > alarmCount then
        alarmCurrent = 1
    end
end)
timer:reset()
timer:force()
timer:setEnabled(true)

function callback_loop()
    if _endtick then
        synthesizer.stop()
        return
    end

    timerhost:tick()
end