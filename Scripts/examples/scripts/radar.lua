--------------------- settings

local maxdist = 60
local line = false

--------------------- code

local colors = require("colors")
local utils = require("utils")

local radar = getComponents("radar")[1]
local display = getComponents("display")[1]
display.reset()
display.clear()

radar.setHFov(math.rad(16))
radar.setVFov(math.rad(180))

local rx, ry = display.getWidth(), display.getHeight()
local crx, cry = rx / 2, ry / 2
local tick = 0

local points = {}
local idColors = {}

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
        return
    end

    local angle = math.rad(tick % 360)
    radar.setAngle(angle)

    display.clear()
    if line then
        display.drawLine(crx, cry, (math.sin(angle) * crx) + crx, -(math.cos(angle) * cry) + cry)
    end
    for i = #points, 1, -1 do
        local point = points[i]
        if point[3] == angle then
            table.remove(points, i)
        end
    end
    for index, value in ipairs(radar.getTargets()) do
        local id, hangle, vangle, dist, force, ctype = unpack(value)

        local s = (dist / maxdist) * crx

        local x = math.floor(math.sin(hangle) * s + crx)
        local y = math.floor(-math.cos(hangle) * s + crx)

        if not idColors[id] then
            if ctype == "character" then
                idColors[id] = colors.sm.Gray[1]
            else
                idColors[id] = sm.color.new(math.random(), math.random(), math.random())
            end
        end
        for i = #points, 1, -1 do
            local point = points[i]
            if point[4] == id then
                table.remove(points, i)
            end
        end
        table.insert(points, {x, y, angle, id})
    end
    for i = #points, 1, -1 do
        local point = points[i]
        display.drawPixel(point[1], point[2], idColors[ point[4] ])
    end
    for ix = -1, 1 do
        for iy = -1, 1 do
            if ix == 0 or iy == 0 then
                display.drawPixel(crx + ix, cry + iy, (ix == 0 and iy == -1) and "00ff00" or "ff0000")
            end
        end
    end
    display.flush()

    tick = tick + 16
end