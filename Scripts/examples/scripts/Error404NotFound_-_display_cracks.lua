local display = getComponent("display")

local timerHost = require("timer").createHost()

local string_format = string.format

local table_insert = table.insert
local table_remove = table.remove

local math_random = math.random
local math_floor  = math.floor
local math_cos    = math.cos
local math_sin    = math.sin
local math_pi     = math.pi

local fps = 20
local optimizationLevel = 32

local width, height = display.getSize()
local _available = false

display.setOptimizationLevel(optimizationLevel)

local draw_queue = {}
local count = 0

local matrix_damage = {
    columns = {},
    rows = {},
    glitch_pixels = {}
}

local CONFIG = {
    bg_color    = "#222222",
    crack_color = "#7f7f7f",

    growth_speed   = 2000,
    clicksToBreak  = 10,

    rays_count       = 16,
    segments_per_ray = 8,
    segment_len      = 6 * 2,
    branch_chance    = 0.8,
    rings_count      = 4,
    ring_jaggedness  = 1,

    min_segments = 8,
    max_segments = 18,
    length_decay = 0.94 * 2,
    direction_noise = 0.25
}

local function damageAlongLine(x1,y1,x2,y2, energy)

    local w, h = display.getSize()

    -- центр сегмента
    local mx = (x1+x2)/2
    local my = (y1+y2)/2

    -- радиус влияния зависит от энергии
    local radius = 5 + energy * 30

    -- =============================
    -- 1️⃣ Толстые ЧЁРНЫЕ полосы
    -- =============================

    if math_random() < energy * 0.4 then
        local offset = (math_random()^2) * radius
        if math_random() < 0.5 then offset = -offset end
        local col = math_floor(mx + offset)
        if col >= 0 and col < w then
            matrix_damage.columns[col] = {
                color = "#000000",
                width = math_floor(2 + energy * 8)
            }
        end
    end

    if math_random() < energy * 0.3 then
        local offset = (math_random()^2) * radius
        if math_random() < 0.5 then offset = -offset end
        local row = math_floor(my + offset)
        if row >= 0 and row < h then
            matrix_damage.rows[row] = {
                color = "#000000",
                height = math_floor(2 + energy * 6)
            }
        end
    end

    -- =============================
    -- 2️⃣ Цветные вертикальные RGB линии
    -- =============================

    if math_random() < energy * 0.6 then
        local col = math_floor(mx + math_random(-radius/2, radius/2))
        if col >= 0 and col < w then
            matrix_damage.columns[col] = {
                color = string.format("#%02x%02x%02x",
                    math_random(150,255),
                    math_random(0,255),
                    math_random(150,255)
                ),
                width = math_floor(1 + energy * 4)
            }
        end
    end

    -- =============================
    -- 3️⃣ Радужные зоны вокруг трещины
    -- =============================

    local glitchCount = math_floor(energy * 40)

    for i = 1, glitchCount do
        local gx = mx + math_random(-radius, radius)
        local gy = my + math_random(-radius, radius)

        if gx >= 0 and gx < w and gy >= 0 and gy < h then
            table_insert(matrix_damage.glitch_pixels, {
                x = gx,
                y = gy,
                color = string.format("#%02x%02x%02x",
                    math_random(0,255),
                    math_random(0,255),
                    math_random(0,255)
                ),
                life = math_floor(10 + energy * 30)
            })
        end
    end
end

local function createImpact(cx, cy)
    local ray_points = {}

    for i = 1, CONFIG.rays_count do
        local baseAngle = (i / CONFIG.rays_count) * math_pi * 2
        local angle = baseAngle + (math_random() - 0.5) * 0.4
        
        local curX, curY = cx, cy
        ray_points[i] = { {x = curX, y = curY} }
        
        local maxSegments = math_random(CONFIG.min_segments, CONFIG.max_segments)
        local curLength = CONFIG.segment_len * (0.8 + math_random()*0.6)

        for s = 1, maxSegments do
            local energy = 1 - (s / maxSegments)

            curLength = curLength * CONFIG.length_decay
            angle = angle + (math_random() - 0.5) * CONFIG.direction_noise
            
            local nX = curX + math_cos(angle) * curLength
            local nY = curY + math_sin(angle) * curLength

            local w, h = display.getSize()
            if nX < 0 or nX >= w or nY < 0 or nY >= h then
                break 
            end
            
            table_insert(draw_queue, {
                type="line",
                x1=curX, y1=curY,
                x2=nX, y2=nY,
                depth=s
            })

            damageAlongLine(curX,curY,nX,nY, energy)
            
            curX, curY = nX, nY
            table_insert(ray_points[i], {x = curX, y = curY})

            if s > 2 and math_random() < 0.25 then
                local next_i = (i % CONFIG.rays_count) + 1
                local p2 = ray_points[next_i] and ray_points[next_i][s]
                
                if p2 then
                    local midX = (curX + p2.x)/2 + (math_random()-0.5)*curLength
                    local midY = (curY + p2.y)/2 + (math_random()-0.5)*curLength
                    
                    table_insert(draw_queue, {
                        type="line",
                        x1=curX, y1=curY,
                        x2=midX, y2=midY,
                        depth=s + 0.1
                    })
                    
                    table_insert(draw_queue, {
                        type="line",
                        x1=midX, y1=midY,
                        x2=p2.x, y2=p2.y,
                        depth=s + 0.2
                    })
                end
            end

            if math_random() < CONFIG.branch_chance * (1 - s/maxSegments) then
                local bAngle = angle + (math_random() > 0.5 and 1 or -1) * (0.5 + math_random()*0.5)
                local bLen = curLength * (0.4 + math_random()*0.5)
                
                local bX = curX + math_cos(bAngle) * bLen
                local bY = curY + math_sin(bAngle) * bLen
                
                table_insert(draw_queue, {
                    type="line",
                    x1=curX, y1=curY,
                    x2=bX, y2=bY,
                    depth=s + 0.3
                })
            end
        end
    end

    for r = 2, CONFIG.segments_per_ray do
        if math_random() < (CONFIG.rings_count / CONFIG.segments_per_ray) then
            for i = 1, CONFIG.rays_count do
                local next_i = (i % CONFIG.rays_count) + 1
                local p1, p2 = ray_points[i][r], ray_points[next_i][r]
                
                if p1 and p2 and math_random() < 0.8 then
                    local midX = (p1.x + p2.x) / 2 + (math_random() - 0.5) * (CONFIG.segment_len * CONFIG.ring_jaggedness)
                    local midY = (p1.y + p2.y) / 2 + (math_random() - 0.5) * (CONFIG.segment_len * CONFIG.ring_jaggedness)
                    
                    table_insert(draw_queue, {type="line", x1=p1.x, y1=p1.y, x2=midX, y2=midY})
                    table_insert(draw_queue, {type="line", x1=midX, y1=midY, x2=p2.x, y2=p2.y})
                end
            end
        end
    end
end

function onStart()
    display.reset()
    display.setOptimizationLevel(0)
    display.setClicksAllowed(true)
    display.setMaterial(4)
    display.clear(CONFIG.bg_color)
    display.flush()
end

function onTick(dt)
    timerHost:tick()

    local click = display.getClick()
    if click and click.state == "pressed" then
        count = count + 1
        if count >= CONFIG.clicksToBreak then
            display.clear(CONFIG.bg_color)
            count = 0
        else
            createImpact(click.x, click.y)
        end
    end
    if #draw_queue > 0 then
        --[[ --Вертикальные битые столбцы
        for x, data in pairs(matrix_damage.columns) do
            for dx = 0, data.width do
                display.drawLine(x+dx, 0, x+dx, height, data.color, 1)
            end
        end

        -- Горизонтальные строки
        for y, data in pairs(matrix_damage.rows) do
            for dy = 0, data.height do
                display.drawLine(0, y+dy, width, y+dy, data.color, 1)
            end
        end

        -- Глюк-пиксели (с постепенным исчезновением)
        local next_glitch = {}
        for _, p in ipairs(matrix_damage.glitch_pixels) do
            display.drawPixel(p.x, p.y, p.color)
            p.life = p.life - 1
            if p.life > 0 then
                table_insert(next_glitch, p)
            end
        end
        matrix_damage.glitch_pixels = next_glitch ]]

        for i = 1, CONFIG.growth_speed do
            local draw = table_remove(draw_queue, 1)
            if draw then display.drawLine(draw.x1, draw.y1, draw.x2, draw.y2, CONFIG.crack_color, 1) end
        end
        display.flush()
    end
end

function onStop()
    display.clear()
    display.flush()
end

_enableCallbacks = true