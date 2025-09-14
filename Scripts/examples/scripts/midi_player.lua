--plays a midi file from a disk
--for this example to work, import the "midis" example to disk

local midi = require("midi")

local synthesizers = getComponents("synthesizer")
local disk = getComponent("disk")

local player = midi.create()
player:load(disk, "2.mid")
player:setSynthesizers(synthesizers)
player:setSpeed(1)
player:setNoteShift(-50)
player:setNoteAlignment(1)
player:setVolume(0.1)
player:setDefaultInstrument(4)
player:start()

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