local synthesizer = getComponent("synthesizer")

function onStart()
    synthesizer.stopLoops()
    synthesizer.startLoop(1, "elevator_music")
end

function onStop()
    synthesizer.stopLoops()
end

_enableCallbacks = true