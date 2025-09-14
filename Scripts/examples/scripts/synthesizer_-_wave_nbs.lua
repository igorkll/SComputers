--it plays like it would in minecraft
--requires betterAPI: https://steamcommunity.com/sharedfiles/filedetails/?id=3177944610

local nbs = require("nbs")

local synthesizers = getComponents("synthesizer")
local disk = getComponent("rom").openFilesystemImage()

local player = nbs.create()
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
--player:load(disk, "tetrisB.nbs")
player:load(disk, "turkish_march.nbs")
--player:load(disk, "whatislove.nb")
player:setSynthesizers(synthesizers)
player:setVolume(0.5)
player:configWaveSamples()

if not isBetterAPI() then
    warning("this example requires a betterAPI!")
end

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