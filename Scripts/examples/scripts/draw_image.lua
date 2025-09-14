local disk = getDisks()[1]
local display = getDisplays()[1]
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
img:draw(display)
display.flush()

function callback_loop()
    if _endtick then
        display.clear()
        display.flush()
    end
end