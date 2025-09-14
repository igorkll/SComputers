--full documentation for the library: https://igorkll.github.io/nbs.html

local nbs = require("nbs")

local synthesizers = getComponents("synthesizer")
local disk = getComponent("disk")

local player = nbs.create()
--player.instrumentTable = {} --uncomment if you want everything to be played with one instrument
--player:load(disk, "as.nbs")
--player:load(disk, "axelf.nbs")
--player:load(disk, "bad_apple.nbs")
--player:load(disk, "clocks.nbs")
--player:load(disk, "despacito.nbs")
--player:load(disk, "dr_mario.nbs")
--player:load(disk, "dsm.nbs")
--player:load(disk, "fireflies.nbs")
--player:load(disk, "ground_yellow.nbs")
--player:load(disk, "mario.nbs")
--player:load(disk, "mario_world.nbs")
--player:load(disk, "mario3.nbs")
--player:load(disk, "nyan_cat.nbs")
--player:load(disk, "pokemon_theme.nbs")
--player:load(disk, "pv.nbs")
--player:load(disk, "rockstar.nbs")
--player:load(disk, "smash.nbs")
--player:load(disk, "tetrisA.nbs")
player:load(disk, "tetrisB.nbs") --all the nbs that are contained in the standard example on the disk. but you can upload your own
--player:load(disk, "turkish_march.nbs")
--player:load(disk, "whatislove.nb")
player:setSynthesizers(synthesizers)
player:setSpeed(1)
player:setNoteShift(-39)
player:setNoteAligment(1)
player:setVolume(0.1)
player:setDefaultInstrument(4)
player:setNoteDuration(10, true, true)

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