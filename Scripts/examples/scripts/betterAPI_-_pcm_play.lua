--this code interacts with betterAPI directly, which requires the use of unsafe mode
--you can activate it in the permission tool
--in this example, the audio API is used on the server side (only the host will hear the sound) and no specific point is set for playback (the sound will be heard all over the map)

local playTime = 2
local sampleRate = 8000
local byteRate = 1
local channelsCount = 2

function onStart()
    local pcm = {}
    for i = 1, playTime * sampleRate * byteRate * channelsCount do
        table.insert(pcm, string.char(math.random(0, 255)))
    end
    pcm = table.concat(pcm)

    audio = global.better.audio.createFromPcm(pcm, sampleRate, byteRate, channelsCount)
    audio:setVolume(1)
    audio:start()
end

function onStop()
    audio:destroy()
end

_enableCallbacks = true