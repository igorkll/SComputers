--causes the object in front of the cannon to be repainted

local colors = require("colors")
local paint = getComponent("paint")

function callback_loop()
    if sm.game.getCurrentTick() % 10 == 0 then
        paint.shot(sm.color.new(colors.hsvToRgb((getUptime() % 160) / 160, 1, 1)))
    end
end