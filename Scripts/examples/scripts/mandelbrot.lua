-- recomended resolution 128x128

local scale = 1
local scaleSpeed = 2
local updateTimer = 1
local maxIterations = 32

------------------------------------------------

local colors = require("colors")
local utils = require("utils")

local display = getComponent("display")
local display_x, display_y = display.getSize()
display.reset()
display.setClicksAllowed(true)
display.setOptimizationLevel(0)

local LOG2 = math.log(2)

local color1 = sm.color.new(0x000088ff)
local color2 = sm.color.new(0xffff00ff)

local function iterate(u, v)
    local zx, zy = u, v
    local temp
    for i=0, maxIterations do
        if zx*zx + zy*zy > 4 then
            return i
        end
        temp = zx
        zx = zx*zx - zy*zy + u
        zy = 2 * temp * zy + v
    end
    return maxIterations
end

local function draw(offsetX, offsetY)
    for y = 0, display_y - 1 do
        local v = y / display_y * 2 - 1
        for x = 0, display_x - 1 do
            local u = x / display_y * 2 - 1
            local iter = iterate(u * scale + offsetX, v * scale + offsetY) / maxIterations
            if iter == 1 then
                display.drawPixel(x, y, 0)
            else
                display.drawPixel(x, y, colors.combineColorToNumber(iter, color1, color2))
            end
        end
    end
    display.flush()
end

function onStart()
    draw(0, 0)
end

local touchX, touchY
local offsetX, offsetY = 0, 0
local clickUptime
function onTick()
    local click = display.getClick()
    if click then
        local uptime = getUptime()
        if click[3] == "pressed" then
            touchX, touchY = click[1], click[2]
            clickUptime = uptime
        elseif click[3] == "drag" then
            local dx, dy = click[1] - touchX, click[2] - touchY
            if click[4] == 2 then
                scale = scale - ((dy / display_y) * scaleSpeed * scale)
                if scale < 0 then scale = 0 end
            else
                dx = dx * scale
                dy = dy * scale
                offsetX, offsetY = offsetX - ((dx / display_x) * 2), offsetY - ((dy / display_y) * 2)
            end
            if uptime - clickUptime >= updateTimer then
                draw(offsetX, offsetY)
                clickUptime = uptime
            end
            touchX, touchY = click[1], click[2]
        elseif click[3] == "released" then
            draw(offsetX, offsetY)
        end
    end
end

function onStop()
    display.clear()
    display.flush()
end

_enableCallbacks = true