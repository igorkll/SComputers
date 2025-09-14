--this simplest camera demonstrates the operation of the "image" library
--red button - make photo
--green button - show photo

local image = require("image")
local colors = require("colors")

local imagePath = "/image.scimg8"

local display = getComponent("display")
local disk = getComponent("disk")
local camera = getComponent("camera")

if input(colors.sm.Red[2]) then
    disk.clear()

    local img = image.new(display.getWidth(), display.getHeight(), sm.color.new(0, 0, 0))
    img:fromCameraAll(camera, "drawAdvanced")
    img:save8(disk, imagePath)

    display.clear("0000ff")
    display.drawText(1, 1, "photo maked!")
    display.forceFlush()
elseif input(colors.sm.Green[2]) then
    if disk.hasFile(imagePath) then
        local img = image.load(disk, imagePath)
        display.clear()
        img:draw(display)
        display.forceFlush()
    else
        display.clear("0000ff")
        display.drawText(1, 1, "no photo")
        display.forceFlush()
    end
end

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
    end
end