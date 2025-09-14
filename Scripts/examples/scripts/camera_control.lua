--more detailed instructions are here: https://igorkll.github.io/SComputers/cameraControl.html

local cameraControl = getComponent("cameraControl")

function onTick()
    print("--------------- seated player")
    print("dir: ", cameraControl.getDirection())
    print("pos: ", cameraControl.getPosition())

    print("--------------- nearby player")
    print("dir: ", cameraControl.getDirection(true))
    print("pos: ", cameraControl.getPosition(true))
end

_enableCallbacks = true