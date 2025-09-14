local timerhost = require("timer").createHost()

local display = getComponent("display")
display.reset()
display.clear()
display.setSkipAtNotSight(true) --in order for the picture not to be updated for those who do not look at the screen

local camera = getComponent("camera")
local fov = math.rad(120)
camera.setNonSquareFov(fov * (display.getWidth() / display.getHeight()), fov)
camera.setStep(512)

local maxDownScale = 16
local downScale = 1

local function updateDownScale()
    camera.setDownScale(downScale)
    downScale = downScale + 1
    if downScale > maxDownScale then
        downScale = 1
    end
end

timerhost:createTimer(40 * 3, true, updateDownScale):setEnabled(true)
updateDownScale()

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    timerhost:tick()

    if display.getAudience() > 0 then --if no one is looking at the screen at all, then the camera will not work
        camera.drawAdvanced(display, true)
        display.flush()
    end
end