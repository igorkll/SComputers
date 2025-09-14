--combines many displays into one display
local vdisplay = require("vdisplay")
local displays = getComponents("display")

local numberDisplaysByWidth = 4

setComponentApi("display", vdisplay.bundle(displays, numberDisplaysByWidth))

function callback_loop() end