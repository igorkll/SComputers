local synthesizer = getComponent("synthesizer")

function onStart()
    synthesizer.stopLoops()
    synthesizer.startLoop(1, "chapter2_alarm", {alarm = 2})
end

function onStop()
    synthesizer.stopLoops()
end

_enableCallbacks = true