local colors = require("colors")

local fov = math.rad(120)
                    
local display = getComponent("display")
display.reset()
display.clear()
display.setSkipAtNotSight(true) --in order for the picture not to be updated for those who do not look at the screen
local width, height = display.getSize()

local camera = getComponent("camera")
camera.setNonSquareFov(fov * (width / height), fov)
camera.setStep(512)

local paddingX, paddingY = math.ceil(width / 16), math.ceil(height / 16)
local viewportSX, viewportSY, viewportEX, viewportEY = paddingX, paddingY, width - paddingX - 1, height - paddingY - 1
camera.setViewport(viewportSX, viewportSY, (viewportEX - viewportSX) + 1, (viewportEY - viewportSY) + 1)

for x = 0, width - 1 do
    for y = 0, height - 1 do
        if x < viewportSX or x > viewportEX or y < viewportSY or y > viewportEY then
            local r = x / width
            local g = y / height
            local b = 0.5
            display.drawPixel(x, y, colors.packFloat(r, g, b))
        end
    end
end
display.forceFlush()

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    if display.getAudience() > 0 then --if no one is looking at the screen at all, then the camera will not work
        camera.setImageRotation(math.rad(getUptime() / 8))
        camera.drawAdvanced(display, true)
        display.flush()
    end
end