--this code does not render the image from the disk immediately so that the computer does not crash
local disk = getComponent("disk")
local display = getComponent("display")
display.reset()

local image = require("image")

--local img = assert(image.load(disk, "/colorbox64.bmp"))
local img = assert(image.load(disk, "/colorbox128.bmp"))
--local img = assert(image.load(disk, "/colorbox256.bmp"))
--local img = assert(image.load(disk, "/lighthouse64.bmp"))
--local img = assert(image.load(disk, "/lighthouse128.bmp"))
--local img = assert(image.load(disk, "/lighthouse256.bmp"))
--local img = assert(image.load(disk, "/mandelbulb64.bmp"))
--local img = assert(image.load(disk, "/mandelbulb128.bmp"))
--local img = assert(image.load(disk, "/mandelbulb256.bmp"))

display.clear()
display.flush()

local drw = img:drawForTicks(display, 40 * 5)
function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
        return
    end

    if drw then
        if drw() then
            drw = nil
        end
        display.flush()
    end
end