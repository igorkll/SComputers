--the sample api requires a betterAPI to work!
--https://steamcommunity.com/sharedfiles/filedetails/?id=3177944610
--https://igorkll.github.io/synthesizer.html

local timerhost = require("timer").createHost()
local synthesizer = getComponent("synthesizer")

synthesizer.loadSampleFromTTS(1, "hello world")

local speeds = {0.7, 1, 1.2, 1.4}
local currentSpeed = 1
local timer = timerhost:createTimer(10, true, function ()
    synthesizer.sampleBeep(1, 1, speeds[currentSpeed]) --launching the audio instance instead of simply launching the sample
    currentSpeed = currentSpeed + 1
    if currentSpeed > #speeds then
        currentSpeed = 1
    end
end)
timer:reset()
timer:setEnabled(true)

function callback_loop()
    if _endtick then
        synthesizer.stop()
        return
    end

    timerhost:tick()
end