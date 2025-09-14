local nbs = require("nbs")

local synthesizers = getComponents("synthesizer")
local disk = getComponent("disk")

local player = nbs.create()
player:load(disk, "despacito.nbs")
player:setSynthesizers(synthesizers)
player:setSpeed(1)
player:setNoteShift(-39)
player:setNoteAligment(1)
player:setVolume(0.1)
player:setDefaultInstrument(4)
player:setNoteDuration(10, true, true)

player:setAltBeep(function(_, synthesizer, instrument, note, fullnote, duration, volume)
    return synthesizer.ballBeep(fullnote / 2, duration)
end)

function callback_loop()
    if _endtick then
        player:stop()
        return
    end
    if not player:isPlaying() then
        player:start()
    end
    player:tick()
end