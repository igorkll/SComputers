function onStart()
    global.better.filesystem.makeDirectory("/SComputers_soundplay_example")
    global.better.filesystem.writeFile("/SComputers_soundplay_example/readme.txt", "put your mp3 file here and name it as test.mp3")
    global.better.filesystem.show("/SComputers_soundplay_example")
end

function onTick()
    clientInvoke([[
        local fileExists = global.better.filesystem.exists("/SComputers_soundplay_example/test.mp3")
        if audio then
            if fileExists then
                audio:updateSpatialSound(sm.localPlayer.getPlayer().character.worldPosition, {{self.shape.worldPosition, 25}}, sm.camera.getDirection())
            else
                audio:destroy()
                audio = nil
            end
        elseif fileExists then
            audio = global.better.audio.createFromFile("/SComputers_soundplay_example/test.mp3")
            audio:setVolume(0.5)
            audio:start()
        end
    ]])
end

function onStop()
    clientInvoke("if audio then audio:destroy() end")
end

function onError()
    onStop()
end

_enableCallbacks = true