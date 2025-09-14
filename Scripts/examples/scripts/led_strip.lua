led = getComponent("led")
ledsCount = led.getStripLength()

function clamp(v, min, max)
    return math.max(math.min(v, max), min)
end

function genColorPart(resolution)
    return math.random(0, resolution) / resolution
end

function genColor(resolution, add)
    local r = genColorPart(resolution)
    local g = genColorPart(resolution)
    local b = genColorPart(resolution)
    local rBigger = r > g and r > b
    local gBigger = g > r and g > b
    local bBigger = b > g and b > r

    if rBigger then
        r = r - add
        g = g + add
        b = b + add
    end
    if gBigger then
        r = r + add
        g = g - add
        b = b + add
    end
    if bBigger then
        r = r + add
        g = g + add
        b = b - add
    end

    r = clamp(r, 0, 1)
    g = clamp(g, 0, 1)
    b = clamp(b, 0, 1)

    return r, g, b
end

targetColors = {}
currentColors = {}
for i = 1, ledsCount do
    table.insert(targetColors, {0, 0, 0})
    table.insert(currentColors, {0, 0, 0})
end

tick = 0
function callback_loop()
    if _endtick then
        for i = 0, ledsCount - 1 do
            led.setColor(i, sm.color.new(0, 0, 0))
        end
        return
    end

    if tick % 5 == 0 then
        for i = 1, 4 do
            targetColors[math.random(1, ledsCount)] = {0, 0, 0}
        end
        targetColors[math.random(1, ledsCount)] = {genColor(1, 0.1)}
    end
    
    for index, value in ipairs(targetColors) do
        local r, g, b = value[1], value[2], value[3]
        local cr, cg, cb = currentColors[index][1], currentColors[index][2], currentColors[index][3]
        
        cr = cr + ((r - cr) * 0.1)
        cg = cg + ((g - cg) * 0.1)
        cb = cb + ((b - cb) * 0.1)
    
        currentColors[index][1] = cr
        currentColors[index][2] = cg
        currentColors[index][3] = cb
    end
    
    for index, value in ipairs(currentColors) do
        led.setColor(index - 1, sm.color.new(value[1], value[2], value[3]))
    end
    
    tick = tick + 1
end