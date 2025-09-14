--the sample api requires a betterAPI to work!
--https://steamcommunity.com/sharedfiles/filedetails/?id=3177944610
--https://igorkll.github.io/synthesizer.html

local timerhost = require("timer").createHost()
local synthesizer = getComponent("synthesizer")

synthesizer.loadSampleFromTTS(1, "hello world")
synthesizer.loadSampleFromTTS(2, "danger")
synthesizer.loadSampleFromTTS(3, "evacuation")

local timer = timerhost:createTimer(40, false, function ()
    synthesizer.startSample(1)

    local timer = timerhost:createTimer(80, false, function ()
        synthesizer.startSample(2)

        local timer = timerhost:createTimer(40, true, function ()
            synthesizer.startSample(3)
        end)
        timer:reset()
        timer:setEnabled(true)
    end)
    timer:reset()
    timer:setEnabled(true)
end)
timer:reset()
timer:setEnabled(true)

function callback_loop()
    if _endtick then
        synthesizer.stopSample(1)
        synthesizer.stopSample(2)
        synthesizer.stopSample(3)
        return
    end

    timerhost:tick()
end