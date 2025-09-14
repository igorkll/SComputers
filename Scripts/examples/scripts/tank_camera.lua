--connecting
--green - next camera
--blue - previous camera
--red - zoom
--any - on

--settings
maxdistance = 512 --metrs, one metr - 4 blocks
fov = math.rad(70)
zoomfov = math.rad(5)
drawingSpeed = 256

--code
cameraIndex = 1

function callback_loop()
    display = getDisplays()[1]
    if not display then
        oldDisplay = nil
        return
    end
    if display ~= oldDisplay then
        display.reset()
        display.clear()
        display.setSkipAtNotSight(true) --in order for the picture not to be updated for those who do not look at the screen
        oldDisplay = display
    end

    cameras = getCameras()

    ----------------------------

    if input("19e753ff") and not oldgreen then
        cameraIndex = cameraIndex + 1
        if cameraIndex > #cameras then
            cameraIndex = 1
        end
        camera = cameras[cameraIndex]
    end
    oldgreen = input("19e753ff")

    if input("0a3ee2ff") and not oldblue then
        cameraIndex = cameraIndex - 1
        if cameraIndex < 1 then
            cameraIndex = #cameras
        end
        camera = cameras[cameraIndex]
    end
    oldblue = input("0a3ee2ff")

    if not camera then
        camera = cameras[cameraIndex]
        if not camera then
            cameraIndex = 1
            camera = cameras[cameraIndex]
        end
    end

    if camera then
        if not pcall(function (...)
            camera.setFov(input("d02525ff") and zoomfov or fov)
            camera.setDistance(maxdistance)
            camera.setStep(drawingSpeed)
            camera.drawColorWithDepth(display)
        end) then
            camera = nil
        end
    else
        display.clear("09403cff")
    end

    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    display.flush()
end