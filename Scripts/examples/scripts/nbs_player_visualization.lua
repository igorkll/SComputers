local nbs = require("nbs")
local colors = require("colors")

local synthesizers = getComponents("synthesizer")
local disk = getComponent("disk")
local display = getComponent("display")

local player = nbs.create()
player:load(disk, "tetrisB.nbs")
player:setSynthesizers(synthesizers)

local points = {}
local pixelsPerTick = 4
local waveTick = 0

local function noteTofreq(n)
    return math.pow(2,(n-69)/12)*440
end

function callback_loop()
    if _endtick then
        player:stop()
        display.clear()
        display.flush()
        return
    end
    if not player:isPlaying() then
        player:start()
    end
    player:tick()

    -- visualization
    for i = 0, pixelsPerTick - 1 do
        local lpoints = {}
        for _, note in ipairs(player:getCurrentNotes()) do
            table.insert(lpoints, {math.sin(math.rad((waveTick / 40) * 360 * noteTofreq(note[2]))) * (display.getHeight() * 0.4), colors.pack(colors.hsvToRgb256((note[1] / 15) * 255, 255, 255))})
        end
        table.insert(points, lpoints)
        if #points > display.getWidth() then
            table.remove(points, 1)
        end
        waveTick = waveTick + 1
    end

    display.clear()
    local oldPoses = {}
    for i, tbl in ipairs(points) do
        local updatedDots = {}
        for i2, v in ipairs(tbl) do
            local oldPos = oldPoses[i2] or {}
            oldPoses[i2] = oldPos
            updatedDots[i2] = true
            local x, y = i - 1, (display.getHeight() / 2) - v[1]
            if oldPos[1] then
                display.drawLine(x, y, oldPos[1], oldPos[2], v[2])
            else
                display.drawPixel(x, y, v[2])
            end
            oldPos[1] = x
            oldPos[2] = y
        end
        for i in pairs(oldPoses) do
            if not updatedDots[i] then
                oldPoses[i] = nil
            end
        end
    end
    display.flush()
end