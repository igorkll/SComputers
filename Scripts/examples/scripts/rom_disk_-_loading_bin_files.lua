--full documentation: https://igorkll.github.io/rom.html

local nbs = require("nbs")

local synthesizers = getComponents("synthesizer")
local rom = getComponent("rom") --specify the path in the ROM disk: $CONTENT_DATA/ROM/gamedisks/nbs.json (the path to the files of the standard nbs example in SComputers)

local disk = rom.openFilesystemImage() --interprets the contents of a ROM disk as a filesystem

local player = nbs.create()
--player.instrumentTable = {} --uncomment if you want everything to be played with one instrument
player:load(disk, "tetrisA.nbs")
player:setSynthesizers(synthesizers)
player:setSpeed(1)
player:setNoteShift(-39)
player:setNoteAligment(1)
player:setVolume(0.1)
player:setDefaultInstrument(4)
player:setNoteDuration(0) --you can try to increase this value if your chosen NBS is playing poorly on standard settings

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