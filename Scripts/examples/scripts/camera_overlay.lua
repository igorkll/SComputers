local fastmode = false
                    
local display = getComponent("display")
display.reset()
display.clear()
display.setSkipAtNotSight(true) --in order for the picture not to be updated for those who do not look at the screen

local camera = getComponent("camera")
local fov = math.rad(60)
camera.setNonSquareFov(fov * (display.getWidth() / display.getHeight()), fov)
camera.setStep(512)

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    if display.getAudience() > 0 then --if no one is looking at the screen at all, then the camera will not work
        camera.drawOverlay(display, camera.drawAdvanced, {fastmode}, function(x, y, raydata)
            if not raydata then return end
            if raydata.type == "shape" then
                return sm.color.new(math.random(), 0, 0)
            elseif raydata.type == "character" then
                return sm.color.new(0, math.random(), 0)
            end
        end, {})
        display.flush()
    end
end