--the sample api requires a betterAPI to work!
--https://steamcommunity.com/sharedfiles/filedetails/?id=3177944610
--https://igorkll.github.io/synthesizer.html

local synthesizer = getComponent("synthesizer")

synthesizer.loadSampleFromURL(1, "https://raw.githubusercontent.com/igorkll/trashfolder/refs/heads/main/sound/1.mp3")
synthesizer.loopSample(1, true)
synthesizer.setSampleVolume(1, 0.5)
synthesizer.startSample(1)

function callback_loop()
    if _endtick then
        synthesizer.loopSample(1, false)
        synthesizer.stopSample(1)
        return
    end
end