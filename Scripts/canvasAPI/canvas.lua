print("> canvas.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/luajit.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/fonts/load.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/utf8.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/canvasService.lua")

local debugMode = false
local profileMode = false

local canvasAPI = {
    draw = {
        clear = 0,
        set   = 1,
        fill  = 2,
        rect  = 3,
        text  = 4,
        line  = 5,
        circle  = 6,
        circleF = 7,
        circleE = 8,
        circleVE = 9,
        poly = 10,
        polyF = 11,

        copyNX = 12,
        copyPX = 13,
        copyNY = 14,
        copyPY = 15,
        setI = 16,

        ellipse = 17,
        ellipseF = 18
    },
    material = {
        glass = sm.uuid.new("a683f897-5b8a-4c96-9c46-7b9fbc76d186"),
        classic = sm.uuid.new("8328a29d-35e0-471b-8bfe-06952e9d916d"),
        plastic = sm.uuid.new("82d2da58-6597-4ffa-9b53-1af3b707fa7a"),
        smoothed = sm.uuid.new("a23a4ea2-96da-4bb2-a723-af8c27de2511"),
        glowing = sm.uuid.new("b46ae32a-9037-4360-9f98-3bef1cd4f366"),
        glass2 = sm.uuid.new("53f43c79-f8e3-4c70-b746-f8c35634fab8")
    },
    multi_layer = {}
}

canvasAPI.multi_layer[tostring(canvasAPI.material.classic)] = true
canvasAPI.multi_layer[tostring(canvasAPI.material.plastic)] = true
canvasAPI.multi_layer[tostring(canvasAPI.material.smoothed)] = true
canvasAPI.multi_layer[tostring(canvasAPI.material.glowing)] = true
canvasAPI.version = 61

canvasAPI.materialList = {
    [0] = canvasAPI.material.glass,
    canvasAPI.material.classic,
    canvasAPI.material.plastic,
    canvasAPI.material.smoothed,
    canvasAPI.material.glowing,
    canvasAPI.material.glass2
}

canvasAPI.materialListWithoutGlass = {
    [0] = true,
    canvasAPI.material.classic,
    canvasAPI.material.plastic,
    canvasAPI.material.smoothed,
    canvasAPI.material.glowing
}

local MAX_DRAW_TIME = 2 --protecting the world from crashing using the display
local FONT_SIZE_LIMIT = 256
local DEFAULT_ALPHA_VALUE = 255
local MAX_CLICKS = 16
canvasAPI.DEFAULT_ALPHA_VALUE = DEFAULT_ALPHA_VALUE

local font = font
local defaultFont = font.default
local fonts = font.fonts
local fontsOptimized = font.fontsOptimized
local spaceCharCode = string.byte(" ")

local huge = math.huge
local string_len = string.len
local bit = bit or bit32
local bit_rshift = bit.rshift
local bit_lshift = bit.lshift
local utf8 = utf8
local string = string
local table_sort = table.sort
local type = type
local math_ceil = math.ceil
local math_max = math.max
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local math_floor = math.floor
local vec3_new = sm.vec3.new
local color_new = sm.color.new
local quat_fromEuler = sm.quat.fromEuler
local ipairs = ipairs
local pairs = pairs
local string_byte = string.byte
local defaultError = font.optimized.error
local tostring = tostring
local math_abs = math.abs
local math_min = math.min
local string_sub = string.sub
local table_concat = table.concat
local tonumber = tonumber
local utf8_len = utf8.len
local utf8_sub = utf8.sub
local sm_localPlayer_getPlayer = sm.localPlayer.getPlayer
local os_clock = os.clock
local math_sqrt = math.sqrt
local quat_new = sm.quat.new
local game_getCurrentTick = sm.game.getCurrentTick

local black = color_new(0, 0, 0)
local white = color_new(1, 1, 1)
local blackNumber = 0x000000ff
local whiteNumber = 0xffffffff
local blackSmallNumber = 0x000000
local whiteSmallNumber = 0xffffff

local getEffectName
do
    local currentEffect = 1
    local effectsNames = {}

    for i = 0, 255 do
        table_insert(effectsNames, "ShapeRenderable" .. tostring(i))
    end

    function getEffectName()
        local name = effectsNames[currentEffect]
        currentEffect = currentEffect + 1
        if currentEffect > #effectsNames then
            currentEffect = 1
        end
        return name
    end
end

local function profillerPrint(name, execTime)
    local t = execTime * 1000
    if profileMode and t > 0 then
        print("profiller", name, t)
    end
end

--[[
local function profiller(name, startTime)
    profillerPrint(name, os_clock() - startTime)
end
]]

--[[
local sm_effect_createEffect = sm.effect.withoutHook_createEffect or sm.effect.createEffect
local emptyEffect = sm_effect_createEffect(getEffectName())
local withoutHookEmptyEffect = emptyEffect
local whook = "withoutHook_"
if better and better.version >= 45 and better.isAvailable() then
    local mt = getmetatable(emptyEffect)
    local newMt = {}
    for k, v in pairs(mt) do
        newMt[k] = v
    end
    for k, v in pairs(mt) do
        if k:sub(1, #whook) == whook then
            newMt[k:sub(#whook + 1, #k)] = v
        end
    end
    withoutHookEmptyEffect = setmetatable({}, newMt)
end
local effect_setParameter = withoutHookEmptyEffect.setParameter
local effect_stop = withoutHookEmptyEffect.stop
local effect_destroy = withoutHookEmptyEffect.destroy
local effect_start = withoutHookEmptyEffect.start
local effect_isDone = withoutHookEmptyEffect.isDone
local effect_isPlaying = withoutHookEmptyEffect.isPlaying
local effect_setScale = withoutHookEmptyEffect.setScale
local effect_setOffsetPosition = withoutHookEmptyEffect.setOffsetPosition
local effect_setOffsetRotation = withoutHookEmptyEffect.setOffsetRotation
effect_destroy(emptyEffect)
]]

local sm_effect_createEffect = sm.effect.createEffect
local emptyEffect = sm_effect_createEffect(getEffectName())
local effect_setParameter = emptyEffect.setParameter
local effect_stop = emptyEffect.stop
local effect_destroy = emptyEffect.destroy
local effect_start = emptyEffect.start
local effect_isDone = emptyEffect.isDone
local effect_isPlaying = emptyEffect.isPlaying
local effect_setScale = emptyEffect.setScale
local effect_setOffsetPosition = emptyEffect.setOffsetPosition
local effect_setOffsetRotation = emptyEffect.setOffsetRotation
local effect_setPosition = emptyEffect.setPosition
local effect_setRotation = emptyEffect.setRotation
effect_destroy(emptyEffect)

local function reverse_ipairs(t)
    local i = #t + 1
    return function()
        i = i - 1
        if i > 0 then
            return i, t[i]
        end
    end
end

local function round(number)
    return math_floor(number + 0.5)
end

local function checkFont(lfont)
    if type(lfont) ~= "table" then
        error("the font should be a table", 3)
    end

    if lfont.mono or lfont.mono == nil then
        if type(lfont.chars) ~= "table" or (type(lfont.width) ~= "number") or (type(lfont.height) ~= "number") then
            error("invalid basic char data", 3)
        end
        
        if lfont.width > FONT_SIZE_LIMIT then
            error("the font width should not exceed " .. FONT_SIZE_LIMIT, 3)
        elseif lfont.height > FONT_SIZE_LIMIT then
            error("the font height should not exceed " .. FONT_SIZE_LIMIT, 3)
        end

        for char, data in pairs(lfont.chars) do
            if type(char) ~= "string" or type(data) ~= "table" or #data ~= lfont.height then
                error("font failed integrity check", 3)
            end
            for _, line in ipairs(data) do
                if type(line) ~= "string" then
                    error("the char string has the wrong type", 3)
                elseif #line ~= lfont.width then
                    print(char, #line, data)
                    error("the char string has the wrong lenght", 3)
                end
            end
        end
    else
        if type(lfont.chars) ~= "table" then
            error("font failed integrity check", 3)
        end

        local oFont = font.optimizeFont(lfont)
        lfont.spaceSize = oFont.spaceSize
        lfont.width = oFont.width
        lfont.height = oFont.height

        for char, data in pairs(lfont.chars) do
            if type(char) ~= "string" or type(data) ~= "table" or #data > FONT_SIZE_LIMIT then
                error("the font height should not exceed " .. FONT_SIZE_LIMIT, 3)
            end
            for _, line in ipairs(data) do
                if type(line) ~= "string" or #line > FONT_SIZE_LIMIT then
                    error("the font width should not exceed " .. FONT_SIZE_LIMIT, 3)
                end
            end
        end
    end
end

local function doQuat(x, y, z, w)
    local sin = math.sin(w / 2)
    return quat_new(sin * x, sin * y, sin * z, math.cos(w / 2))
end

local function custom_fromEulerYEnd(x, y, z) --custom implementation
    return doQuat(1, 0, 0, x) * doQuat(0, 0, 1, z) * doQuat(0, 1, 0, y)
end

local function tableClone(tbl)
    local newtbl = {}
    for k, v in pairs(tbl) do
        newtbl[k] = v
    end
    return newtbl
end

local function stackChecksum(stack)
    local num = -#stack
    local t, v
    for i = 1, #stack do
        v = stack[i]
        t = type(v)
        num = num - i
        if t == "number" then
            num = num + ((v * i) + v + i + (v / i))
        elseif t == "Color" then
            num = num + ((i * (v.r / i) * -4) + v.g)
            num = num - ((i * (v.g + i) * 5) + v.b)
            num = num + ((i * (v.b - i) * 8) + v.r)
        elseif t == "string" then
            for i3 = 1, #v do
                num = num + (i * (-i3 - (string_byte(v, i3) * i3)))
            end
        end
    end
    return num
end

local function checkArg(n, have, ...)
    have = type(have)
    local tbl = {...}
    for _, t in ipairs(tbl) do
        if have == t then
            return
        end
    end
    error(string_format("bad argument #%d (%s expected, got %s)", n, table_concat(tbl, " or "), have), 3)
end

local function simpleRemathRect(x, y, w, h, maxX, maxY)
    local x2, y2 = x + (w - 1), y + (h - 1)
    if x < 0 then
        x = 0
    elseif x > maxX then
        --x = maxX
        return
    end
    if y < 0 then
        y = 0
    elseif y > maxY then
        --y = maxY
        return
    end
    if x2 < 0 then
        --x2 = 0
        return
    elseif x2 > maxX then
        x2 = maxX
    end
    if y2 < 0 then
        --y2 = 0
        return
    elseif y2 > maxY then
        y2 = maxY
    end
    return x, y, x2, y2, w, h
end

local function remathRect(offset, stack, maxX, maxY)
    return simpleRemathRect(stack[offset], stack[offset+1], stack[offset+2], stack[offset+3], maxX, maxY)
end

local function posCheck(width, height, x, y)
    return x >= 0 and y >= 0 and x < width and y < height
end

local hashChar = string.byte("#")
local bit = bit or bit32
local band = bit.band
local rshift = bit.rshift
local function hexToRGB(color)
    return math_floor(color / 256 / 256) / 255, (math_floor(color / 256) % 256) / 255, (color % 256) / 255
end

local function hexToRGB256(color)
    return math_floor(color / 256 / 256), math_floor(color / 256) % 256, color % 256
end

local function optimizationLevelToValue(level)
    return (level / 255) * 0.25
end

local function formatColor(color, default)
    local t = type(color)
    if t == "Color" then
        return color
    elseif t == "string" then
        return color_new(color)
    elseif t == "number" then
        return color_new(hexToRGB(color))
    end

    return default
end

local redMul = 256 * 256 * 256
local greenMul = 256 * 256
local blueMul = 256
local function formatColorToNumber(color, default)
    local t = type(color)
    if t == "Color" then
        return (math_floor(color.r * 255) * redMul) + (math_floor(color.g * 255) * greenMul) + (math_floor(color.b * 255) * blueMul) + math_floor(color.a * 255)
    elseif t == "string" then
        local val
        if string_byte(color) == hashChar then
            val = tonumber(string_sub(color, 2, -1), 16) or 0
        else
            val = tonumber(color, 16) or 0
        end
        if #color > 7 then
            return val
        end
        return (val * 256) + 255
    elseif t == "number" then
        return (color * 256) + 255
    end

    return default or 0
end

local function formatColorToSmallNumber(color, default)
    local t = type(color)
    if t == "Color" then
        return (math_floor(color.r * 255) * greenMul) + (math_floor(color.g * 255) * blueMul) + math_floor(color.b * 255)
    elseif t == "string" then
        local val
        if string_byte(color) == hashChar then
            val = tonumber(string_sub(color, 2, -1), 16) or 0
        else
            val = tonumber(color, 16) or 0
        end
        if #color > 7 then
            return math_floor(val / 256)
        end
        return val
    elseif t == "number" then
        return color
    end

    return default or 0
end

local function color_new_fromSmallNumber(number, alpha)
    return color_new((number * 256) + (alpha or 255))
end

local function mathDist(pos1, pos2)
    return math.sqrt(((pos1.x - pos2.x) ^ 2) + ((pos1.y - pos2.y) ^ 2) + ((pos1.z - pos2.z) ^ 2))
end

local function needPushStack(canvas, dataTunnel) --returns true if the rendering stack should be applied
    return dataTunnel.display_forceFlush or not ((dataTunnel.skipAtNotSight and not canvas.isRendering()))
end

local resetViewportCodeID = -23124
local dataSizes = {
    [resetViewportCodeID] = 1,
    [-1] = 5,
    [0] = 2,
    4,
    6,
    7,
    9, --text
    7, --line
    5,
    5,
    5,
    6,

    4, --drawPoly
    4, --fillPoly

    2,
    2,
    2,
    2,
    3,

    7,
    7
}

local userCalls = {}

canvasAPI.yield = function() end

function canvasAPI.createDrawer(sizeX, sizeY, callback, callbackBefore, directArg, direct_clear, direct_fill, direct_set, updatedList)
    local obj = {}
    local oldStackSum
    local rSizeX, rSizeY = sizeX, sizeY
    local maxX, maxY = sizeX - 1, sizeY - 1
    local newBuffer, newBufferBase = {}, 0
    local realBuffer = {}
    local maxBuffer = maxX + (maxY * sizeX)
    local currentFont = font.optimized
    local fontWidth, fontHeight = defaultFont.width, defaultFont.height
    local rotation = 0
    local utf8Support = false
    local updated = false
    local clearOnly = false
    local clearBackplate = false
    local maxLineSize = sizeX + sizeY
    local bigSide = math_max(sizeX, sizeY)
    local drawerData = {}
    local _oldBufferBase
    local changes = {}
    local _changes = {}
    local changesIndex, changesCount = {}, 0

    local viewportEnable = false
    local viewport_x, viewport_y, viewport_sx, viewport_sy

    local function bufferRangeUpdate() end

    local function setDot(px, py, col)
        if viewportEnable and (px < viewport_x or py < viewport_y or px >= (viewport_x + viewport_sx) or py >= (viewport_y + viewport_sy)) then
            return
        end

        --[[
        if rotation == 0 then
            index = px + (py * rSizeX)
        elseif rotation == 1 then
            index = (rSizeX - py - 1) + (px * rSizeX)
        elseif rotation == 2 then
            index = (rSizeX - px - 1) + ((rSizeY - py - 1) * rSizeX)
        else
            index = py + ((rSizeY - px - 1) * rSizeX)
        end
        ]]

        local index
        if rotation == 0 then
            index = py + (px * rSizeY)
        elseif rotation == 1 then
            index = px + ((rSizeX - py - 1) * rSizeY)
        elseif rotation == 2 then
            index = (rSizeY - py - 1) + ((rSizeX - px - 1) * rSizeY)
        else
            index = (rSizeY - px - 1) + (py * rSizeY)
        end

        if direct_set then
            newBuffer[index] = col
            direct_set(directArg, math_floor(index / rSizeY), index % rSizeY, col)
            return true
        elseif newBuffer[index] ~= col then
            if updatedList and not changes[index] then
                changes[index] = true
                changesCount = changesCount + 1
                changesIndex[changesCount] = index
            end

            newBuffer[index] = col
            return true
        end
    end

    local function check(px, py)
        return px >= 0 and py >= 0 and px < sizeX and py < sizeY
    end

    local function checkSetDot(px, py, col)
        if check(px, py) then
            setDot(px, py, col)
            return true
        end
        return false
    end

    function obj.drawerReset()
    end

    function obj.drawer_setRotation(_rotation)
        rotation = _rotation
        if rotation == 1 or rotation == 3 then
            sizeX = rSizeY
            sizeY = rSizeX
        else
            sizeX = rSizeX
            sizeY = rSizeY
        end
        maxX, maxY = sizeX - 1, sizeY - 1
    end

    function obj.drawer_setUtf8Support(state)
        utf8Support = not not state
    end

    function obj.drawer_setFont(customFont)
        if customFont then
            currentFont = customFont
            fontWidth, fontHeight = customFont.width, customFont.height
        else
            currentFont = font.optimized
            fontWidth, fontHeight = defaultFont.width, defaultFont.height
        end
    end

    function obj.setDrawerResolution(_sizeX, _sizeY)
        rSizeX, rSizeY = _sizeX, _sizeY
        obj.drawer_setRotation(rotation)
        newBuffer, newBufferBase = {}, 0
        realBuffer = {}
        maxBuffer = maxX + (maxY * sizeX)
        maxLineSize = sizeX + sizeY
        bigSide = math_max(sizeX, sizeY)
        changes = {}
        _changes = {}
        changesIndex, changesCount = {}, 0
        oldStackSum = nil
    end

    local old_rotation
    local old_utf8support
    local old_customFont
    function obj.pushDataTunnelParams(params)
        if params.rotation ~= old_rotation then
            obj.drawer_setRotation(params.rotation)
            old_rotation = params.rotation
        end
        if params.utf8support ~= old_utf8support then
            obj.drawer_setUtf8Support(params.utf8support)
            old_utf8support = params.utf8support
        end
        if params.customFont ~= old_customFont then
            obj.drawer_setFont(params.customFont)
            old_customFont = params.customFont
        end
    end

    ------------------------------------------
    
    local function rasterize_fill(x, y, sx, sy, col)
        local x, y, x2, y2, w, h = simpleRemathRect(x, y, sx, sy, maxX, maxY)
        if not x then return end

        if direct_fill then
            direct_fill(directArg, x, y, w, h, col)
        end

        local ix, iy = x, y
        for _ = 1, ((x2 - x) + 1) * ((y2 - y) + 1) do
            setDot(ix, iy, col)
            iy = iy + 1
            if iy > y2 then
                iy = y
                ix = ix + 1
            end
        end

        --[[
        local ix, iy = x, y
        for _ = 1, ((x2 - x) + 1) * ((y2 - y) + 1) do
            setDot(ix, iy, col)
            ix = ix + 1
            if ix > x2 then
                ix = x
                iy = iy + 1
            end
        end
        ]]

        --[[
        local ix, iy = x2, y2
        for _ = 1, ((x2 - x) + 1) * ((y2 - y) + 1) do
            setDot(ix, iy, col)
            iy = iy - 1
            if iy < y then
                iy = y2
                ix = ix - 1
            end
        end
        ]]

        --[[
        local ix, iy = x2, y
        for _ = 1, ((x2 - x) + 1) * ((y2 - y) + 1) do
            setDot(ix, iy, col)
            iy = iy + 1
            if iy > y2 then
                iy = y
                ix = ix - 1
            end
        end
        ]]
    end

    local function rasterize_rect(x, y, sx, sy, col, lineWidth)
        local x, y, x2, y2, w, h = simpleRemathRect(x, y, sx, sy, maxX, maxY)
        if not x then return end
        if lineWidth == 1 then
            for ix = x, x2 do
                setDot(ix, y, col)
                setDot(ix, y2, col)
            end

            for iy = y + 1, y2 - 1 do
                setDot(x, iy, col)
                setDot(x2, iy, col)
            end
        else
            local _y, _y2, _x, _x2
            for ioff = 0, math_min(lineWidth, math_max(w, h) / 2) - 1 do
                _y = y + ioff
                _y2 = y2 - ioff
                for ix = x + ioff, x2 - ioff do
                    setDot(ix, _y, col)
                    setDot(ix, _y2, col)
                end

                _x = x + ioff
                _x2 = x2 - ioff
                for iy = y + 1 + ioff, y2 - (1 + ioff) do
                    setDot(_x, iy, col)
                    setDot(_x2, iy, col)
                end
            end
        end
    end

    local function rasterize_circleF(px, py, r, col)
        local chr = r*r
        local sx, sy, tempInt, tempBool

        if r < bigSide and px >= 0 and py >= 0 and px < sizeX and py < sizeY then --now only a quarter of the circle is rendered
            for iy = 0, r do
                sy = iy + 0.5
                tempBool = false
                for ix = r, 0, -1 do
                    sx = ix + 0.5
                    if tempBool or (sx * sx) + (sy * sy) <= chr then
                        tempBool = true
                        checkSetDot(px + ix, py + iy, col)
                        checkSetDot(px - ix - 1, py + iy, col)
                        checkSetDot(px + ix, py - iy - 1, col)
                        checkSetDot(px - ix - 1, py - iy - 1, col)
                    end
                end
            end
        else
            for ix = math_max(-r, -px), math_min(r, (sizeX - px) - 1) do --if the starting point is not within the screen or the circle is too large, then will have to check every pixel
                sx = ix + 0.5
                for iy = math_max(-r, -py), math_min(r, (sizeY - py) - 1) do
                    sy = iy + 0.5
                    if (sx * sx) + (sy * sy) <= chr then
                        setDot(px + ix, py + iy, col)
                    end
                end
            end
        end
    end

    local function rasterize_line(px, py, px2, py2, col, width, linesInfo)
        if px2 < px or py2 < py then
            local _px, _py = px, py
            px, py = px2, py2
            px2, py2 = _px, _py
        end
        local dx = math_abs(px2 - px)
        local dy = math_abs(py2 - py)
        local sx = (px < px2) and 1 or -1
        local sy = (py < py2) and 1 or -1
        local err = dx - dy
        if width == -1 or width == 0 or width == 1 then
            local drawAllowed = false
            for _ = 1, maxLineSize do
                if check(px, py) then
                    setDot(px, py, col)
                    drawAllowed = true
                elseif drawAllowed then
                    break
                end
                if px == px2 and py == py2 then
                    break
                end
                local e2 = bit_lshift(err, 1)
                if e2 > -dy then
                    err = err - dy
                    px = px + sx
                end
                if e2 < dx then
                    err = err + dx
                    py = py + sy
                end
            end
        elseif width < 0 then
            width = math_ceil((-width) / 2)
            if width < 1 then
                width = 1
            end
            for _ = 1, maxLineSize do
                rasterize_circleF(px, py, width, col)
                if px == px2 and py == py2 then
                    break
                end
                local e2 = bit_lshift(err, 1)
                if e2 > -dy then
                    err = err - dy
                    px = px + sx
                end
                if e2 < dx then
                    err = err + dx
                    py = py + sy
                end
            end
        else
            local offsetFill = math_floor(width / 2)
            for _ = 1, maxLineSize do
                rasterize_fill(px - offsetFill, py - offsetFill, width, width, col)
                if px == px2 and py == py2 then
                    break
                end
                local e2 = bit_lshift(err, 1)
                if e2 > -dy then
                    err = err - dy
                    px = px + sx
                end
                if e2 < dx then
                    err = err + dx
                    py = py + sy
                end
            end
        end
    end

    local function rasterize_hline(x, y, len, color)
        rasterize_fill(x, y, len, 1, color)
    end

    local function rasterize_vline(x, y, len, color)
        rasterize_fill(x, y, 1, len, color)
    end

    local function rasterize_filledRoundedCorners(centerX, centerY, radius, upper, delta, color)
        local f = 1 - radius
        local ddF_x = 1
        local ddF_y = -radius - radius
        local y = 0
        local lineLength

        while y < radius do
            if f >= 0 then
                lineLength = y + y + delta

                if lineLength > 0 then
                    rasterize_hline(centerX - y, upper and (centerY - radius) or (centerY + radius), lineLength, color)
                end

                radius = radius - 1
                ddF_y = ddF_y + 2
                f = f + ddF_y
            end

            y = y + 1
            ddF_x = ddF_x + 2
            f = f + ddF_x
            lineLength = radius + radius + delta

            if lineLength > 0 then
                rasterize_hline(centerX - radius, upper and (centerY - y) or (centerY + y), lineLength, color)
            end
        end
    end

    local function rasterize_roundedCorners(centerX, centerY, radius, corner, color)
        local f = 1 - radius
        local ddF_x = 1
        local ddF_y = -2 * radius
        local xe = 0
        local xs = 0
        local len = 0

        while true do
            while f < 0 do
                xe = xe + 1
                f = f + ddF_x
                ddF_x = ddF_x + 2
            end
            f = f + ddF_y
            ddF_y = ddF_y + 2

            if xe - xs == 1 then
                if bit.band(corner, 0x1) ~= 0 then -- left top
                    checkSetDot(centerX - xe, centerY - radius, color)
                    checkSetDot(centerX - radius, centerY - xe, color)
                end

                if bit.band(corner, 0x2) ~= 0 then -- right top
                    checkSetDot(centerX + radius, centerY - xe, color)
                    checkSetDot(centerX + xs + 1, centerY - radius, color)
                end

                if bit.band(corner, 0x4) ~= 0 then -- right bottom
                    checkSetDot(centerX + xs + 1, centerY + radius, color)
                    checkSetDot(centerX + radius, centerY + xs + 1, color)
                end

                if bit.band(corner, 0x8) ~= 0 then -- left bottom
                    checkSetDot(centerX - radius, centerY + xs + 1, color)
                    checkSetDot(centerX - xe, centerY + radius, color)
                end
            else
                len = xe - xs
                xs = xs + 1

                if bit.band(corner, 0x1) ~= 0 then -- left top
                    rasterize_hline(centerX - xe, centerY - radius, len, color)
                    rasterize_vline(centerX - radius, centerY - xe, len, color)
                end

                if bit.band(corner, 0x2) ~= 0 then -- right top
                    rasterize_vline(centerX + radius, centerY - xe, len, color)
                    rasterize_hline(centerX + xs, centerY - radius, len, color)
                end

                if bit.band(corner, 0x4) ~= 0 then -- right bottom
                    rasterize_hline(centerX + xs, centerY + radius, len, color)
                    rasterize_vline(centerX + radius, centerY + xs, len, color)
                end

                if bit.band(corner, 0x8) ~= 0 then -- left bottom
                    rasterize_vline(centerX - radius, centerY + xs, len, color)
                    rasterize_hline(centerX - xe, centerY + radius, len, color)
                end
            end
            xs = xe

            if xe >= radius then break end
            radius = radius - 1
        end
    end

    ------------------------------------------

    local function render_fill(stack, offset)
        rasterize_fill(stack[offset], stack[offset+1], stack[offset+2], stack[offset+3], stack[offset+4])
    end

    local function render_drawEllipse(stack, offset)
        local x, y, x2, y2, w, h = remathRect(offset, stack, maxX, maxY)
        if not x then return end
        local cornerRadius = stack[offset+4]
        local col = stack[offset+5]

        local maxCornerRadius = math.min(w / 2, h / 2)
        if cornerRadius > maxCornerRadius then cornerRadius = maxCornerRadius end

        if cornerRadius <= 0 then
            rasterize_rect(x, y, w, h, col, 1)
            return
        end

        rasterize_hline(
            x + cornerRadius, y,
            w - cornerRadius - cornerRadius,
            col
        )

        rasterize_hline(
            x + cornerRadius, y + h - 1,
            w - cornerRadius - cornerRadius,
            col
        )

        rasterize_vline(
            x , y + cornerRadius,
            h - cornerRadius - cornerRadius,
            col
        )

        rasterize_vline(
            x + w - 1, y + cornerRadius,
            h - cornerRadius - cornerRadius,
            col
        )

        rasterize_roundedCorners(
            x + cornerRadius, y + cornerRadius,
            cornerRadius,
            1,
            col
        )

        rasterize_roundedCorners(
            x + w - cornerRadius - 1, y + cornerRadius,
            cornerRadius,
            2,
            col
        )

        rasterize_roundedCorners(
            x + w - cornerRadius - 1, y + h - cornerRadius - 1,
            cornerRadius,
            4,
            col
        )

        rasterize_roundedCorners(
            x + cornerRadius, y + h - cornerRadius - 1,
            cornerRadius,
            8,
            col
        )
    end

    local function render_fillEllipse(stack, offset)
        local x, y, x2, y2, w, h = remathRect(offset, stack, maxX, maxY)
        if not x then return end
        local cornerRadius = stack[offset+4]
        local col = stack[offset+5]

        local maxCornerRadius = math.min(w / 2, h / 2)
        if cornerRadius > maxCornerRadius then cornerRadius = maxCornerRadius end

        if cornerRadius <= 0 then
            rasterize_fill(x, y, w, h, col, 1)
            return
        end

        rasterize_fill(
            x,
            y + cornerRadius,
            w,
            h - cornerRadius - cornerRadius,
            col
        )

        rasterize_filledRoundedCorners(
            x + cornerRadius,
            y + cornerRadius,
            cornerRadius,
            true,
            w - cornerRadius - cornerRadius,
            col
        )

        rasterize_filledRoundedCorners(
            x + cornerRadius,
            y + h - cornerRadius - 1,
            cornerRadius,
            false,
            w - cornerRadius - cornerRadius,
            col
        )
    end

    local function render_rect(stack, offset)
        rasterize_rect(stack[offset], stack[offset+1], stack[offset+2], stack[offset+3], stack[offset+4], stack[offset+5])
    end

    local function render_text(stack, offset)
        local tx, ty = stack[offset], stack[offset+1]
        local text = stack[offset+2]
        local col = stack[offset+3]
        local scaleX = stack[offset+4]
        local scaleY = stack[offset+5]
        local spacing = stack[offset+6]
        local fontIndex = stack[offset+7]

        local localFont = currentFont
        local localFontWidth = fontWidth
        if fontIndex > 0 and fontsOptimized[fontIndex] then
            localFont = fontsOptimized[fontIndex]
            localFontWidth = localFont.width
        end

        local len, sep
        if utf8Support then
            len, sep = utf8_len, utf8_sub
        else
            len, sep = string_len, string_byte
        end
        local scaledFontWidth = math_ceil(localFontWidth * scaleX)
        if localFont.mono then
            for i = len(text), 1, -1 do
                local char = sep(text, i, i)
                if char ~= " " and char ~= spaceCharCode then
                    local chrdata = localFont[char] or localFont.error or defaultError
                    local charOffset = (i - 1) * (scaledFontWidth + spacing)
                    for i2 = 1, #chrdata, 2 do
                        local px, py = chrdata[i2], chrdata[i2 + 1]
                        local lposX, lposY = round(px * scaleX), round(py * scaleY)
                        for ix = math_min(sizeX, round((px + 1) * scaleX) - lposX - 1), 0, -1 do
                            local setPosX = tx + ix + lposX + charOffset
                            for iy = math_min(sizeY, round((py + 1) * scaleY) - lposY - 1), 0, -1 do
                                checkSetDot(setPosX, ty + iy + lposY, col)
                            end
                        end
                    end
                end
            end
        else
            local charOffset = 0
            local startDrawTime = os_clock()
            for i = 1, len(text) do
                local char = sep(text, i, i)
                if char ~= " " and char ~= spaceCharCode then
                    local chrdata = localFont[char] or localFont.error or defaultError
                    local charPos = tx + charOffset
                    if not chrdata[0] or charPos + round(chrdata[0] * scaleX) > 0 then
                        if charPos > maxX then
                            goto endDraw
                        end
                        for i2 = 1, #chrdata, 2 do
                            local px, py = chrdata[i2], chrdata[i2 + 1]
                            local lposX, lposY = round(px * scaleX), round(py * scaleY)
                            for ix = 0, math_min(sizeX, round((px + 1) * scaleX) - lposX - 1) do
                                local setPosX = tx + ix + lposX + charOffset
                                for iy = 0, math_min(sizeY, round((py + 1) * scaleY) - lposY - 1) do
                                    checkSetDot(setPosX, ty + iy + lposY, col)
                                end
                            end
                        end
                    end
                    charOffset = charOffset + (chrdata[0] and math_ceil(chrdata[0] * scaleX) or 0) + spacing
                else
                    charOffset = charOffset + (math_ceil(localFont.spaceSize * scaleX) or localFontWidth) + spacing
                end
                if os_clock() - startDrawTime > MAX_DRAW_TIME then
                    goto endDraw
                end
            end
        end
        ::endDraw::
    end

    local function render_line(stack, offset)
        rasterize_line(stack[offset], stack[offset+1], stack[offset+2], stack[offset+3], stack[offset+4], stack[offset+5])
    end

    local function render_circle(stack, offset) --Michener’s Algorithm
        local px = stack[offset]
        local py = stack[offset+1]
        local e2 = stack[offset+2]
        local col = stack[offset+3]
        local dx = 0
        local dy = e2
        local chr = 3 - 2 * e2

        while dx <= dy do
            checkSetDot(px + dx, py + dy, col)
            checkSetDot(px + dy, py + dx, col)
            checkSetDot(px - dy, py + dx, col)
            checkSetDot(px - dx, py + dy, col)
            checkSetDot(px + dy, py - dx, col)
            checkSetDot(px + dx, py - dy, col)
            checkSetDot(px - dy, py - dx, col)
            checkSetDot(px - dx, py - dy, col)

            if chr < 0 then
                chr = chr + 4 * dx + 6
            else
                chr = chr + 4 * (dx - dy) + 10
                dy = dy - 1
            end
            dx = dx + 1
        end
    end

    local function render_circleE(stack, offset)
        local px = stack[offset]
        local py = stack[offset+1]
        local e2 = stack[offset+2]
        local col = stack[offset+3]
        local dx = 0
        local dy = e2
        local chr = 3 - 2 * e2

        while dx <= dy do
            checkSetDot(px + dx - 1, py + dy - 1, col)
            checkSetDot(px + dy - 1, py + dx, col)
            checkSetDot(px - dy, py + dx, col)
            checkSetDot(px - dx, py + dy - 1, col)
            checkSetDot(px + dy - 1, py - dx, col)
            checkSetDot(px + dx - 1, py - dy, col)
            checkSetDot(px - dy, py - dx, col)
            checkSetDot(px - dx, py - dy, col)

            if chr < 0 then
                chr = chr + 4 * dx + 6
            else
                chr = chr + 4 * (dx - dy) + 10
                dy = dy - 1
            end
            dx = dx + 1
        end
    end

    local function render_circleF(stack, offset)
        rasterize_circleF(stack[offset], stack[offset+1], stack[offset+2], stack[offset+3])
    end

    local function render_circleVE(stack, offset) --drawCircleVeryEvenly
        local px = stack[offset]
        local py = stack[offset+1]
        local e2 = stack[offset+2]
        local chr = e2*e2
        local col = stack[offset+3]
        local sx, sy, tempInt, tempBool

        e2 = math_min(e2, bigSide)
        for iy = 0, e2 do
            sy = iy + 0.5
            tempInt = stack[offset+4]
            for ix = e2, 0, -1 do
                sx = ix + 0.5
                if (sx * sx) + (sy * sy) <= chr then
                    checkSetDot(px + ix, py + iy, col)
                    checkSetDot(px - ix - 1, py + iy, col)
                    checkSetDot(px + ix, py - iy - 1, col)
                    checkSetDot(px - ix - 1, py - iy - 1, col)

                    tempInt = tempInt - 1
                    if tempInt == 0 then
                        break
                    end
                end
            end
        end
        for ix = 0, e2 do
            sx = ix + 0.5
            tempInt = stack[offset+4]
            for iy = e2, 0, -1 do
                sy = iy + 0.5
                if (sx * sx) + (sy * sy) <= chr then
                    checkSetDot(px + ix, py + iy, col)
                    checkSetDot(px - ix - 1, py + iy, col)
                    checkSetDot(px + ix, py - iy - 1, col)
                    checkSetDot(px - ix - 1, py - iy - 1, col)

                    tempInt = tempInt - 1
                    if tempInt == 0 then
                        break
                    end
                end
            end
        end
    end

    local function render_drawPoly(stack, offset, getFillInfo)
        local col = stack[offset]
        local points = stack[offset+1]
        local width = stack[offset+2]

        local startDrawTime = os_clock()
        local _px = stack[offset+3]
        local _py = stack[offset+4]
        local px, py
        local pointsPos
        if getFillInfo then
            pointsPos = {}

            local _setDot = setDot
            setDot = function(px, py, col)
                if not pointsPos[py] then
                    pointsPos[py] = {px, px}
                else
                    local data = pointsPos[py]
                    if px < data[1] then data[1] = px end
                    if px > data[2] then data[2] = px end
                end
            end
            
            for i = 3, points, 2 do
                px = stack[offset+2+i]
                py = stack[offset+3+i]
                rasterize_line(_px, _py, px, py, col, width)
                _px = px
                _py = py
                if os_clock() - startDrawTime > MAX_DRAW_TIME then
                    goto endDraw
                end
            end
            rasterize_line(_px, _py, stack[offset+3], stack[offset+4], col, width)

            setDot = _setDot
        else
            for i = 3, points, 2 do
                px = stack[offset+2+i]
                py = stack[offset+3+i]
                rasterize_line(_px, _py, px, py, col, width)
                _px = px
                _py = py
                if os_clock() - startDrawTime > MAX_DRAW_TIME then
                    goto endDraw
                end
            end
            rasterize_line(_px, _py, stack[offset+3], stack[offset+4], col, width)
        end
        
        ::endDraw::
        return points, pointsPos
    end

    local function render_fillPoly(stack, offset)
        local col = stack[offset]
        local points = stack[offset+1]
        local width = stack[offset+2]

        local gpoints = points
        for ii = 0, points / 2, 2 do
            local i = ii * 2
            local _, pointsPos = render_drawPoly({col, math_min(6, gpoints), width, stack[offset+3+i], stack[offset+4+i], stack[offset+5+i], stack[offset+6+i], stack[offset+7+i], stack[offset+8+i]}, 1, true)
            local startDrawTime = os_clock()
            for posY, v in pairs(pointsPos) do
                for i = v[1], v[2] do
                    setDot(i, posY, col)
                end

                if os_clock() - startDrawTime > MAX_DRAW_TIME then
                    goto endDraw
                end
            end
            gpoints = gpoints - 4
            if gpoints <= 0 then
                break
            end
        end

        ::endDraw::
        return points
    end

    local lastPixelX, lastPixelY, lastPixelColor
    function obj.pushStack(stack)
        local offset = 2
        local actionNum
        local addValue = 0
        local startDrawTime = os_clock()
        local idx
        while stack[offset] do
            actionNum = stack[offset-1]
            clearOnly = actionNum == 0
            addValue = 0

            if actionNum == 0 then
                newBufferBase = stack[offset]
                newBuffer = {}
                if direct_clear then
                    direct_clear(directArg, newBufferBase, changes)
                end
                updated = true
                clearBackplate = true
                if callback and newBufferBase ~= _oldBufferBase then
                    obj.fullRefresh()
                    _oldBufferBase = newBufferBase
                end
            elseif actionNum == resetViewportCodeID then
                viewportEnable = false
            elseif actionNum == -1 then
                viewportEnable = true
                viewport_x = stack[offset]
                viewport_y = stack[offset+1]
                viewport_sx = stack[offset+2]
                viewport_sy = stack[offset+3]
            elseif actionNum == 1 then
                setDot(stack[offset], stack[offset+1], stack[offset+2])
                updated = true
            elseif actionNum == 2 then
                render_fill(stack, offset)
                updated = true
            elseif actionNum == 3 then
                render_rect(stack, offset)
                updated = true
            elseif actionNum == 4 then
                render_text(stack, offset)
                updated = true
            elseif actionNum == 5 then
                render_line(stack, offset)
                updated = true
            elseif actionNum == 6 then
                render_circle(stack, offset)
                updated = true
            elseif actionNum == 8 then
                render_circleE(stack, offset)
                updated = true
            elseif actionNum == 7 then
                render_circleF(stack, offset)
                updated = true
            elseif actionNum == 9 then
                render_circleVE(stack, offset)
                updated = true
            elseif actionNum == 10 then
                addValue = render_drawPoly(stack, offset)
                updated = true
            elseif actionNum == 11 then
                addValue = render_fillPoly(stack, offset)
                updated = true
            elseif actionNum == 12 then
                for _ = 1, stack[offset] do
                    lastPixelX = lastPixelX + 1
                    setDot(lastPixelX, lastPixelY, lastPixelColor)
                end
                updated = true
            elseif actionNum == 13 then
                for _ = 1, stack[offset] do
                    lastPixelX = lastPixelX - 1
                    setDot(lastPixelX, lastPixelY, lastPixelColor)
                end
                updated = true
            elseif actionNum == 14 then
                for _ = 1, stack[offset] do
                    lastPixelY = lastPixelY + 1
                    setDot(lastPixelX, lastPixelY, lastPixelColor)
                end
                updated = true
            elseif actionNum == 15 then
                for _ = 1, stack[offset] do
                    lastPixelY = lastPixelY - 1
                    setDot(lastPixelX, lastPixelY, lastPixelColor)
                end
                updated = true
            elseif actionNum == 16 then
                idx = stack[offset]
                lastPixelX, lastPixelY, lastPixelColor = idx % rSizeX, math_floor(idx / rSizeX), stack[offset+1]
                setDot(lastPixelX, lastPixelY, lastPixelColor)
                updated = true
            elseif actionNum == 17 then
                render_drawEllipse(stack, offset)
                updated = true
            elseif actionNum == 18 then
                render_fillEllipse(stack, offset)
                updated = true
            elseif userCalls[actionNum] then
                if userCalls[actionNum](newBuffer, rotation, rSizeX, rSizeY, sizeX, sizeY, stack, offset, drawerData, bufferRangeUpdate, setDot, checkSetDot, rasterize_fill) then
                    updated = true
                end
            end

            if os_clock() - startDrawTime > MAX_DRAW_TIME then
                goto endDraw
            end

            offset = offset + dataSizes[actionNum] + addValue
        end

        ::endDraw::
    end

    function obj.flush(force)
        if not obj.wait and (updated or force) then
            if callbackBefore then
                callbackBefore(newBufferBase, clearOnly, maxBuffer, force, newBuffer, realBuffer, nil, nil, changes, changesIndex, changesCount, _changes, clearBackplate)
            end

            if callback then
                --[[
                local color, px, py
                for i = bufferChangedFrom, bufferChangedTo do
                    color = newBuffer[i] or newBufferBase
                    if color ~= realBuffer[i] or force then
                        px = math_floor(i / rSizeY)
                        py = i % rSizeY
                        callback(px, py, color, newBufferBase)
                        realBuffer[i] = color
                    end
                end
                ]]

                local oldChanges
                if clearBackplate then
                    oldChanges = {}
                    for index in pairs(changes) do
                        oldChanges[index] = true
                    end

                    for index in pairs(_changes) do
                        if not changes[index] then
                            changesCount = changesCount + 1
                            changesIndex[changesCount] = index
                            changes[index] = true
                        end
                    end
                end
        
                for i2 = 1, changesCount do
                    local index = changesIndex[i2]
                    --if changes[index] then
                        callback(math_floor(index / sizeY), index % sizeY, newBuffer[index] or newBufferBase, newBufferBase)
                        _changes[index] = true
                    --end
                end

                if clearBackplate then
                    obj.setOldChanges(oldChanges)
                end
            end

            updated = false
            clearBackplate = false
            if updatedList then
                changes = {}
                changesIndex = {}
                changesCount = 0
            end
        end
    end

    function obj.setWait(state)
        obj.wait = state
        if not state then
            obj.flush()
        end
    end

    function obj.getNewBuffer(i)
        return newBuffer[i] or newBufferBase
    end

    function obj.getRealBuffer(i)
        return realBuffer[i]
    end

    function obj.getChanges()
        return changes
    end

    function obj.fullRefresh()
        changesCount = 0
        changesIndex = {}
        for i = 0, (sizeX * sizeY) - 1 do
            changes[i] = true
            changesCount = changesCount + 1
            changesIndex[changesCount] = i
        end
    end

    --[[
    function obj.flushOldChanges()
        _changes = changes
    end
    ]]

    function obj.setOldChanges(oldChanges)
        _changes = oldChanges
    end

    function obj.clearChangesBuffer()
        _changes = {}
        changes = {}
    end

    return obj
end

if better and better.isAvailable() and better.canvas and better.version >= 40 then
    local better_canvas_clear = better.canvas.clear
    local better_canvas_fill = better.canvas.fill
    local better_canvas_set = better.canvas.set

    function canvasAPI.createBetterCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation)
        local obj = {sizeX = sizeX, sizeY = sizeY}
        local maxX, maxY = sizeX - 1, sizeY - 1
        local maxEffectArrayBuffer = maxX + (maxY * sizeX)
        local dist
        local needOptimize = false
        local showState = false
        local disable = false
        local flushedDefault = false

        local betterCanvas = better.canvas.create(sizeX, sizeY)

        local drawer = canvasAPI.createDrawer(sizeX, sizeY, nil, nil, betterCanvas, better_canvas_clear, better_canvas_fill, better_canvas_set)
        drawer.setWait(true)

        local defaultPosition = vec3_new(0, 0, 0)
        local function getSelfPos()
            local pt = type(parent)
            if pt == "Interactable" then
                return parent.shape.worldPosition
            elseif pt == "Character" then
                return parent.worldPosition
            end
            return defaultPosition
        end

        function obj.isRendering()
            return showState
        end

        function obj.disable(state)
            disable = state
        end

        function obj.setRenderDistance(_dist)
            dist = _dist
        end

        function obj.update()
            local newShowState = true
            local selfPosition
            if disable then
                newShowState = false
            elseif dist then
                if not pcall(function()
                    selfPosition = getSelfPos()
                    newShowState = mathDist(selfPosition, sm_localPlayer_getPlayer().character.worldPosition) <= dist
                end) then
                    selfPosition = selfPosition or vec3_new(0, 0, 0)
                    newShowState = false
                end
            end

            if newShowState ~= showState then
                showState = newShowState
                if newShowState then
                    drawer.setWait(false)
                    if not flushedDefault then
                        drawer.flush(true)
                        flushedDefault = true
                    end
                else
                    drawer.setWait(true)
                    better.canvas.stopUpdate(betterCanvas)
                end
            end

            if newShowState then
                better.canvas.update_3d(betterCanvas, selfPosition + (rotation * offset), -sm.quat.getRight(rotation), -sm.quat.getUp(rotation), (pixelSize.x * sizeX) / 2, (pixelSize.y * sizeY) / 2)
            end
        end

        function obj.setPixelSize(_pixelSize)
            pixelSize = _pixelSize or vec3_new(0.25 / 4, 0.25 / 4, 0.05 / 4)
            if type(pixelSize) == "number" then
                if pixelSize < 0 then
                    pixelSize = math_abs(pixelSize)
                    local vec = vec3_new(pixelSize, pixelSize, 0)
                    vec.z = 0.00025
                    obj.setPixelSize(vec)
                else
                    local vec = vec3_new(0.0072, 0.0072, 0) * pixelSize
                    vec.z = 0.00025
                    obj.setPixelSize(vec)
                end
            end
        end

        function obj.setOffset(_offset)
            offset = _offset
        end

        function obj.setCanvasRotation(_rotation)
            rotation = _rotation
        end

        function obj.destroy()
            better.canvas.destroy(betterCanvas)
        end

        ---------------------------------------

        obj.setPixelSize(pixelSize)
        obj.setCanvasRotation(rotation or quat_fromEuler(vec3_new(0, 0, 0)))
        obj.setOffset(offset or vec3_new(0, 0, 0))

        --[[
        local c = 0xff0000
        local seffect = createEffect(5, 5, 16, 16, c)
        local idx = 5 + (5 * sizeX)
        for i = 0, 16 - 1 do
            effects[idx + i] = {
                seffect,
                c,
                i,
                16,
                idx,
                5,
                5,
                1, --8. sizeY
                0 --9. indexY
            }
        end
        ]]

        ---------------------------------------

        obj.drawer = drawer
        for k, v in pairs(drawer) do
            obj[k] = v
        end

        return obj
    end
end

--low level display api
function canvasAPI.createCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation, material, scaleAddValue, altFromEuler, autoLayerDistance, constParameters)
    local hiddenOffset = vec3_new(1000000, 1000000, 1000000)
    local defaultSizeX, defaultSizeY = sizeX, sizeY
    local pixelScaleX, pixelScaleY = 1, 1
    local obj = {sizeX = sizeX, sizeY = sizeY}
    local maxX, maxY = sizeX - 1, sizeY - 1
    local maxEffectArrayBuffer = maxX + (maxY * sizeX)
    local dist
    local needOptimize = false
    local skipOptimize = false
    local showState = false
    local disable = false

    local _setPosition, _setRotation
    if parent then
        _setPosition, _setRotation = effect_setOffsetPosition, effect_setOffsetRotation
    else
        _setPosition, _setRotation = effect_setPosition, effect_setRotation
    end

    material = material or canvasAPI.material.classic
    local autoScaleAddValue = false
    if not scaleAddValue then
        autoScaleAddValue = true
    end

    local flushedDefault = false
    local oldBackplateColor
    local backplate
    if canvasAPI.multi_layer[tostring(material)] then
        oldBackplateColor = 0
        backplate = sm_effect_createEffect(getEffectName(), parent)
        effect_setParameter(backplate, "uuid", material)
        effect_setParameter(backplate, "color", black)
    end

    local additionalLayer
    local function updateAdditionalLayer()
        if material == canvasAPI.material.smoothed then
            if not additionalLayer then
                additionalLayer = sm_effect_createEffect(getEffectName(), parent)
                effect_setParameter(additionalLayer, "uuid", canvasAPI.material.glass)
                effect_setParameter(additionalLayer, "color", black)
                effect_start(additionalLayer)
                return true
            end
        elseif additionalLayer then
            effect_destroy(additionalLayer)
            additionalLayer = nil
        end
    end
    updateAdditionalLayer()

    local layerDistance
    local layerDistance_withoutBackplateCheck
    local function updateLayerDistance(distance)
        layerDistance = math.max(0.001, autoLayerDistance and distance or 0)
        if backplate then
            layerDistance_withoutBackplateCheck = layerDistance
        else
            layerDistance_withoutBackplateCheck = 0
        end
    end
    updateLayerDistance()

    local effects = {}
    local nodeEffects = {}
    local effectDatas = {}
    local effectDataLen = 5

    local bufferedEffectsUpdateTime = {}
    local bufferedEffects = {}
    local bufferedEffectsIndex = 0
    local lastDrawTickTime
    local optimizationLevel = 16
    local optimizationValue = optimizationLevelToValue(optimizationLevel)
    local alpha = DEFAULT_ALPHA_VALUE

    local oldHardwareParams = {
        offset_x = 0,
        offset_y = 0,
        offset_z = 0,
        
        rotation_x = 0,
        rotation_y = 0,
        rotation_z = 0,

        scale_x = 1,
        scale_y = 1,

        altRotation = false
    }

    local function getEIndex(index)
        return index * effectDataLen
    end

    local function fromEIndex(index)
        return index / effectDataLen
    end

    local function _setEffectDataParams_constParameters(index)
        local effect = nodeEffects[index]
        local eindex = getEIndex(index)
        local posX, posY, lSizeX, lSizeY = effectDatas[eindex+1], effectDatas[eindex+2], effectDatas[eindex+3], effectDatas[eindex+4]

        posX = posX + ((lSizeX - 1) * 0.5)
        posY = posY + ((lSizeY - 1) * 0.5)
        _setPosition(effect, vec3_new(-offset.z - layerDistance_withoutBackplateCheck, ((sizeY / 2) - (posY + 0.5)) * -pixelSize.y, ((sizeX / 2) - (posX + 0.5)) * pixelSize.x))
        effect_setScale(effect, vec3_new((pixelSize.x * lSizeX) + scaleAddValue, (pixelSize.y * lSizeY) + scaleAddValue, pixelSize.z))
        effect_setParameter(effect, "color", color_new_fromSmallNumber(effectDatas[eindex], alpha))
    end

    local function _setEffectDataParams_defaultRotation(index)
        local effect = nodeEffects[index]
        local eindex = getEIndex(index)
        local posX, posY, lSizeX, lSizeY = effectDatas[eindex+1], effectDatas[eindex+2], effectDatas[eindex+3], effectDatas[eindex+4]

        posX = posX + ((lSizeX - 1) * 0.5)
        posY = posY + ((lSizeY - 1) * 0.5)
        _setPosition(effect, rotation * (offset + vec3_new(((posX + 0.5) - (sizeX / 2)) * pixelSize.x, ((posY + 0.5) - (sizeY / 2)) * -pixelSize.y, layerDistance_withoutBackplateCheck)))
        effect_setScale(effect, vec3_new((pixelSize.x * lSizeX) + scaleAddValue, (pixelSize.y * lSizeY) + scaleAddValue, pixelSize.z))
        effect_setParameter(effect, "color", color_new_fromSmallNumber(effectDatas[eindex], alpha))
    end

    local function _setEffectDataParams_altRotation(index)
        local effect = nodeEffects[index]
        local eindex = getEIndex(index)
        local posX, posY, lSizeX, lSizeY = effectDatas[eindex+1], effectDatas[eindex+2], effectDatas[eindex+3], effectDatas[eindex+4]

        posX = posX + ((lSizeX - 1) * 0.5)
        posY = posY + ((lSizeY - 1) * 0.5)
        _setPosition(effect, offset + (rotation * vec3_new(((posX + 0.5) - (sizeX / 2)) * pixelSize.x, ((posY + 0.5) - (sizeY / 2)) * -pixelSize.y, layerDistance_withoutBackplateCheck)))
        effect_setScale(effect, vec3_new((pixelSize.x * lSizeX) + scaleAddValue, (pixelSize.y * lSizeY) + scaleAddValue, pixelSize.z))
        effect_setParameter(effect, "color", color_new_fromSmallNumber(effectDatas[eindex], alpha))
    end

    local setEffectDataParams = _setEffectDataParams_defaultRotation
    local disableRotation = false

    if constParameters then
        setEffectDataParams = _setEffectDataParams_constParameters
        disableRotation = true
    end

    local function createEffect()
        local effect
        if bufferedEffectsIndex > 0 then
            effect = bufferedEffects[bufferedEffectsIndex]
            bufferedEffectsIndex = bufferedEffectsIndex - 1
            if not effect_isPlaying(effect) then
                effect_start(effect)
            end
        else
            effect = sm_effect_createEffect(getEffectName(), parent)
            effect_setParameter(effect, "uuid", material)
            if showState then
                effect_start(effect)
            end
            _setRotation(effect, rotation)
        end
        return effect
    end

    local function createEffectUnhide(hideList)
        local effect
        if bufferedEffectsIndex > 0 then
            effect = bufferedEffects[bufferedEffectsIndex]
            hideList[effect] = nil
            bufferedEffectsIndex = bufferedEffectsIndex - 1
            if not effect_isPlaying(effect) then
                effect_start(effect)
            end
        else
            effect = sm_effect_createEffect(getEffectName(), parent)
            effect_setParameter(effect, "uuid", material)
            if showState then
                effect_start(effect)
            end
            _setRotation(effect, rotation)
        end
        return effect
    end

    local function clearBufferedEffects()
        for i = 1, bufferedEffectsIndex do
            effect_destroy(bufferedEffects[i])
        end
        bufferedEffectsUpdateTime = {}
        bufferedEffects = {}
        bufferedEffectsIndex = 0
    end

    local lastNewBuffer, lastBase

    local lastPopularColor
    local function mathPopularColor()
        local colorUsesTable = {}
        local colorUses = 0
        local oldColorUses = 0
        local colorSum = 0
        for index in pairs(nodeEffects) do
            local eindex = getEIndex(index)
            local color = effectDatas[eindex]
            local colorSize = effectDatas[eindex+3] * effectDatas[eindex+4]
            colorUsesTable[color] = (colorUsesTable[color] or 0) + colorSize
            colorSum = colorSum + colorSize
            colorUses = colorUsesTable[color]
            if colorUses > oldColorUses then
                oldColorUses = colorUses
                lastPopularColor = color
            end
        end

        if oldBackplateColor then
            local colorSize = (sizeX * sizeY) - colorSum
            colorUsesTable[oldBackplateColor] = (colorUsesTable[oldBackplateColor] or 0) + colorSize
            colorUses = colorUsesTable[oldBackplateColor]
            if colorUses > oldColorUses then
                oldColorUses = colorUses
                lastPopularColor = oldBackplateColor
            end
        end
    end

    local function effectIndexAtPos(px, py)
        return py + (px * sizeY)
    end

    local function getRootEIndexAtPos(px, py)
        if py < 0 or py >= sizeY then return end
        local index = effects[effectIndexAtPos(px, py)]
        return index and getEIndex(index), index
    end

    local function clearEffectFromBuffer(index)
        local eindex = getEIndex(index)
        local six, ix, iy = effectDatas[eindex+1], effectDatas[eindex+1], effectDatas[eindex+2]
        local sizeX, sizeY = effectDatas[eindex+3], effectDatas[eindex+4]
        nodeEffects[index] = nil
        for _ = 1, sizeX * sizeY do
            effects[effectIndexAtPos(ix, iy)] = nil
            ix = ix + 1
            if ix >= six + sizeX then
                ix = six
                iy = iy + 1
            end
        end
    end

    local function hideEffect(effect)
        bufferedEffectsIndex = bufferedEffectsIndex + 1
        bufferedEffects[bufferedEffectsIndex] = effect
        bufferedEffectsUpdateTime[bufferedEffectsIndex] = game_getCurrentTick()
        _setPosition(effect, hiddenOffset)
    end

    local function hideEffectData(index)
        hideEffect(nodeEffects[index])
        clearEffectFromBuffer(index)
    end

    local function hideEffectLater(effect, hideList)
        bufferedEffectsIndex = bufferedEffectsIndex + 1
        bufferedEffects[bufferedEffectsIndex] = effect
        bufferedEffectsUpdateTime[bufferedEffectsIndex] = game_getCurrentTick()
        hideList[effect] = true
        --_setPosition(effect, hiddenOffset)
    end

    local function hideEffectDataLater(index, hideList)
        hideEffectLater(nodeEffects[index], hideList)
        clearEffectFromBuffer(index)
    end    
    
    local function hideEffectsWithColor(color)
        for index in pairs(nodeEffects) do
            if effectDatas[getEIndex(index)] == color then
                hideEffectData(index)
            end
        end
    end

    local function delAllEffects()
        for _, effect in pairs(nodeEffects) do
            effect_destroy(effect)
        end
        effects = {}
        nodeEffects = {}
    end

    --[[
    local function forceRecreateNodeEffects()
        nodeEffects = {}
        for i, effectData in pairs(effects) do
            if effectData[7] == i then
                nodeEffects[i] = effectData
            end
        end
    end
    ]]

    --local maxVal = math_sqrt((255 ^ 2) + (255 ^ 2) + (255 ^ 2))
    local function colorEquals_smart(color1, color2)
        if color1 == color2 then return true end
        local rVal, gVal, bVal = hexToRGB256(color1)
        local rVal2, gVal2, bVal2 = hexToRGB256(color2)
        --return (math_sqrt(((rVal - rVal2) ^ 2) + ((gVal - gVal2) ^ 2) + ((bVal - bVal2) ^ 2)) / maxVal) <= optimizationValue
        return ((math_abs(rVal - rVal2) + math_abs(gVal - gVal2) + math_abs(bVal - bVal2)) / 1024) <= optimizationValue
    end

    local colorEquals = colorEquals_smart

    local function colorEquals_raw(color1, color2)
        return color1 == color2
    end

    local function getFillZone(eindex)
        local fillX1, fillY1 = effectDatas[eindex+1], effectDatas[eindex+2]
        return fillX1, fillY1, fillX1 + (effectDatas[eindex+3] - 1), fillY1 + (effectDatas[eindex+4] - 1)
    end

    local sumAttachTime = 0
    local sumAttachFillTime = 0
    local function tryLongAttach(changedList, hideList, index, px, py, color, sizeX, sizeY)
        --local startTime = os_clock()

        --[[
        local origIndex = effects[index]
        local sizeX, sizeY = 1, 1
        local origEffect
        if origIndex then
            origEffect = nodeEffects[origIndex]
            local eindex = getEIndex(origIndex)
            index, px, py = origIndex, effectDatas[eindex+1], effectDatas[eindex+2]
            sizeX, sizeY = effectDatas[eindex+3], effectDatas[eindex+4]
        end
        ]]

        local upParentE, upParent = getRootEIndexAtPos(px, py - 1)
        local downParentE, downParent = getRootEIndexAtPos(px, py + sizeY)
        local upAvailable = upParentE and nodeEffects[upParent] and effectDatas[upParentE+1] == px and effectDatas[upParentE+3] == sizeX and colorEquals(effectDatas[upParentE], color)
        local downAvailable = downParentE and nodeEffects[downParent] and effectDatas[downParentE+1] == px and effectDatas[downParentE+3] == sizeX and colorEquals(effectDatas[downParentE], color)

        local fillOptional = false
        local fillX1, fillY1, fillX2, fillY2
        local fill2X1, fill2Y1, fill2X2, fill2Y2

        --[[
        if origEffect and (upAvailable or downAvailable) then
            hideEffectLater(origEffect, hideList)
            changedList[origIndex] = nil
            changedColorList[origIndex] = nil
            nodeEffects[origIndex] = nil
        end
        ]]

        local newIndex, newEIndex
        local fillVal
        if upAvailable and downAvailable then
            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)
            fill2X1, fill2Y1, fill2X2, fill2Y2 = getFillZone(downParentE)

            local addSizeY = sizeY + effectDatas[downParentE+4]

            hideEffectLater(nodeEffects[downParent], hideList)
            changedList[downParent] = nil
            --changedColorList[downParent] = nil
            nodeEffects[downParent] = nil

            effectDatas[upParentE+4] = effectDatas[upParentE+4] + addSizeY
            newIndex, newEIndex = upParent, upParentE
            fillVal = upParent
        elseif upAvailable then
            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)

            effectDatas[upParentE+4] = effectDatas[upParentE+4] + sizeY
            newIndex, newEIndex = upParent, upParentE
            fillVal = upParent
        elseif downAvailable then
            fillOptional = true
            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)
            fill2X1, fill2Y1, fill2X2, fill2Y2 = getFillZone(downParentE)

            changedList[downParent] = nil
           --changedColorList[downParent] = nil

            nodeEffects[index] = nodeEffects[downParent]
            nodeEffects[downParent] = nil

            local eindex = getEIndex(index)
            effectDatas[eindex] = effectDatas[downParentE]
            effectDatas[eindex+1] = effectDatas[downParentE+1]
            effectDatas[eindex+2] = py
            effectDatas[eindex+3] = effectDatas[downParentE+3]
            effectDatas[eindex+4] = effectDatas[downParentE+4] + sizeY
            
            newIndex, newEIndex = index, eindex
            fillVal = index
        end

        if fillVal then
            index, px, py = newIndex, effectDatas[newEIndex+1], effectDatas[newEIndex+2]
            sizeX, sizeY = effectDatas[newEIndex+3], effectDatas[newEIndex+4]
        end

        local leftParentE, leftParent = getRootEIndexAtPos(px - 1, py)
        local rightParentE, rightParent = getRootEIndexAtPos(px + sizeX, py)
        local leftAvailable = leftParentE and nodeEffects[leftParent] and effectDatas[leftParentE+2] == py and effectDatas[leftParentE+4] == sizeY and colorEquals(effectDatas[leftParentE], color)
        local rightAvailable = rightParentE and nodeEffects[rightParent] and effectDatas[rightParentE+2] == py and effectDatas[rightParentE+4] == sizeY and colorEquals(effectDatas[rightParentE], color)

        if nodeEffects[index] and (leftAvailable or rightAvailable) then
            hideEffectLater(nodeEffects[index], hideList)
            changedList[index] = nil
            --changedColorList[index] = nil
            nodeEffects[index] = nil
        end

        if leftAvailable and rightAvailable then
            fillOptional = false
            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)
            fill2X1, fill2Y1, fill2X2, fill2Y2 = getFillZone(rightParentE)

            local addSizeX = sizeX + effectDatas[rightParentE+3]

            hideEffectLater(nodeEffects[rightParent], hideList)
            changedList[rightParent] = nil
            --changedColorList[rightParent] = nil
            nodeEffects[rightParent] = nil

            effectDatas[leftParentE+3] = effectDatas[leftParentE+3] + addSizeX
            fillVal = leftParent
        elseif leftAvailable then
            fillOptional = false
            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)
            fill2X1, fill2Y1, fill2X2, fill2Y2 = nil, nil, nil, nil

            effectDatas[leftParentE+3] = effectDatas[leftParentE+3] + sizeX
            fillVal = leftParent
        elseif rightAvailable then
            fillOptional = not upAvailable and not downAvailable
            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)
            fill2X1, fill2Y1, fill2X2, fill2Y2 = getFillZone(rightParentE)

            changedList[rightParent] = nil
            --changedColorList[rightParent] = nil

            nodeEffects[index] = nodeEffects[rightParent]
            nodeEffects[rightParent] = nil

            local eindex = getEIndex(index)
            effectDatas[eindex] = effectDatas[rightParentE]
            effectDatas[eindex+1] = px
            effectDatas[eindex+2] = effectDatas[rightParentE+2]
            effectDatas[eindex+3] = sizeX + effectDatas[rightParentE+3]
            effectDatas[eindex+4] = effectDatas[rightParentE+4]
            
            fillVal = index
        end

        --sumAttachTime = sumAttachTime + (os_clock() - startTime)

        if fillVal then
            changedList[fillVal] = true
            --changedColorList[fillVal] = true

            --[[
            local eindex = getEIndex(fillVal)
            local fillX1, fillY1 = effectDatas[eindex+1], effectDatas[eindex+2]
            local fillX2, fillY2 = fillX1 + (effectDatas[eindex+3] - 1), fillY1 + (effectDatas[eindex+4] - 1)
            local ix, iy = fillX1, fillY1
            for _ = 1, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
                effects[effectIndexAtPos(ix, iy)] = fillVal
                ix = ix + 1
                if ix > fillX2 then
                    ix = fillX1
                    iy = iy + 1
                end
            end
            ]]

            --startTime = os_clock()

            --fillOptional = false
            --if not fillOptional or not origEffect then
                local ix, iy = fillX1, fillY1
                for _ = 1, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = fillVal
                    ix = ix + 1
                    if ix > fillX2 then
                        ix = fillX1
                        iy = iy + 1
                    end
                end
            --[[else
                local ix, iy = fillX1, fillY1
                for _ = 1, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
                    if fillVal ~= effects[effectIndexAtPos(ix, iy)] then
                        print("WTTT", fillVal, effects[effectIndexAtPos(ix, iy)])
                    end
                    ix = ix + 1
                    if ix > fillX2 then
                        ix = fillX1
                        iy = iy + 1
                    end
                end
                ]]
            --end

            if fill2X1 then
                local ix, iy = fill2X1, fill2Y1
                for _ = 1, ((fill2X2 - fill2X1) + 1) * ((fill2Y2 - fill2Y1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = fillVal
                    ix = ix + 1
                    if ix > fill2X2 then
                        ix = fill2X1
                        iy = iy + 1
                    end
                end
            end

            --sumAttachFillTime = sumAttachFillTime + (os_clock() - startTime)

            --fillVal = tryAttach(changedList, changedColorList, index, px, py, color) or fillVal
        end

        return fillVal
    end

    local function tryAttach(changedList, hideList, index, px, py, color, sizeX, sizeY)
        --local startTime = os_clock()

        --[[
        local origIndex = effects[index]
        local sizeX, sizeY = 1, 1
        local origEffect
        if origIndex then
            origEffect = nodeEffects[origIndex]
            local eindex = getEIndex(origIndex)
            index, px, py = origIndex, effectDatas[eindex+1], effectDatas[eindex+2]
            sizeX, sizeY = effectDatas[eindex+3], effectDatas[eindex+4]
        end
        ]]

        local upParentE, upParent = getRootEIndexAtPos(px, py - 1)
        local upAvailable = upParentE and nodeEffects[upParent] and effectDatas[upParentE+1] == px and effectDatas[upParentE+3] == sizeX and colorEquals(effectDatas[upParentE], color)

        local fillX1, fillY1, fillX2, fillY2
        local newIndex, newEIndex, fillVal
        if upAvailable then
            --[[
            if origEffect then
                hideEffectLater(origEffect, hideList)
                changedList[origIndex] = nil
                changedColorList[origIndex] = nil
                nodeEffects[origIndex] = nil
            end
            ]]

            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)

            effectDatas[upParentE+4] = effectDatas[upParentE+4] + sizeY
            newIndex, newEIndex = upParent, upParentE
            fillVal = upParent

            index, px, py = newIndex, effectDatas[newEIndex+1], effectDatas[newEIndex+2]
            sizeX, sizeY = effectDatas[newEIndex+3], effectDatas[newEIndex+4]
        end

        local leftParentE, leftParent = getRootEIndexAtPos(px - 1, py)
        local leftAvailable = leftParentE and nodeEffects[leftParent] and effectDatas[leftParentE+2] == py and effectDatas[leftParentE+4] == sizeY and colorEquals(effectDatas[leftParentE], color)
        if leftAvailable then
            if nodeEffects[index] then
                hideEffectLater(nodeEffects[index], hideList)
                changedList[index] = nil
                --changedColorList[index] = nil
                nodeEffects[index] = nil
            end

            fillX1, fillY1, fillX2, fillY2 = px, py, px + (sizeX - 1), py + (sizeY - 1)
            effectDatas[leftParentE+3] = effectDatas[leftParentE+3] + sizeX
            fillVal = leftParent
        end

        --sumAttachTime = sumAttachTime + (os_clock() - startTime)

        if fillVal then
            changedList[fillVal] = true
            --changedColorList[fillVal] = true

            --startTime = os_clock()
            local ix, iy = fillX1, fillY1
            for _ = 1, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
                effects[effectIndexAtPos(ix, iy)] = fillVal
                ix = ix + 1
                if ix > fillX2 then
                    ix = fillX1
                    iy = iy + 1
                end
            end
            --sumAttachFillTime = sumAttachFillTime + (os_clock() - startTime)
        end

        return fillVal
    end

    local sumFillTime = 0
    local function fillBlock(x, y, sx, sy, changedList, hideList, color, iterate, effect)
        if sx <= 0 or sy <= 0 then
            return
        end

        local newRIndex = effectIndexAtPos(x, y)
        nodeEffects[newRIndex] = effect or createEffectUnhide(hideList)
        changedList[newRIndex] = true
        --changedColorList[newRIndex] = true

        local newEIndex = getEIndex(newRIndex)
        effectDatas[newEIndex] = color
        effectDatas[newEIndex+1] = x
        effectDatas[newEIndex+2] = y
        effectDatas[newEIndex+3] = sx
        effectDatas[newEIndex+4] = sy

        if not iterate then
            return true
        end
        
        --local startTime = os_clock()
        local ix, iy = x, y
        local six = ix
        local mix = six + sx
        for _ = 1, sx * sy do
            effects[effectIndexAtPos(ix, iy)] = newRIndex
            ix = ix + 1
            if ix >= mix then
                ix = six
                iy = iy + 1
            end
        end
        --sumFillTime = sumFillTime + (os_clock() - startTime)

        return true
    end

    local sumExtractTime = 0
    local function extractPixel(changedList, hideList, index, px, py, sizeX, sizeY)
        --local startTime = os_clock()

        local rindex = effects[index]
        local eindex = getEIndex(rindex)
        local rpx, rpy = effectDatas[eindex+1], effectDatas[eindex+2]
        local rsx, rsy = effectDatas[eindex+3], effectDatas[eindex+4]
        local lx = px - rpx
        local ly = py - rpy

        local effect = nodeEffects[rindex]
        changedList[rindex] = nil
        --changedColorList[rindex] = nil
        nodeEffects[rindex] = nil

        local color = effectDatas[eindex]
        --local block1, block2, block3, block4 = false, false, false, false
        if fillBlock(rpx, rpy, lx, rsy, changedList, hideList, color, false, effect) then --[[block1 = true]] effect = nil end
        if fillBlock(rpx + lx + sizeX, rpy, rsx - lx - sizeX, rsy, changedList, hideList, color, true, effect) then --[[block2 = true]] effect = nil end
        if fillBlock(rpx + lx, rpy, sizeX, ly, changedList, hideList, color, true, effect) then --[[block3 = true]] effect = nil end
        if fillBlock(rpx + lx, rpy + ly + sizeY, sizeX, rsy - ly - sizeY, changedList, hideList, color, true, effect) then --[[block4 = true]] effect = nil end

        local ix, iy, endX = px, py, px + (sizeX - 1)
        for _ = 1, sizeX * sizeY do
            effects[effectIndexAtPos(ix, iy)] = nil
            ix = ix + 1
            if ix > endX then
                ix = px
                iy = iy + 1
            end
        end

        if effect then
            hideEffectLater(effect, hideList)
        end

        --sumExtractTime = sumExtractTime + (os_clock() - startTime)

        --if block1 then tryAttach(changedList, changedColorList, effectIndexAtPos(rpx, rpy), rpx, rpy, color) end
        --if block2 then tryAttach(changedList, changedColorList, effectIndexAtPos(block2X, rpy), block2X, rpy, color) end
        --if block3 then tryAttach(changedList, changedColorList, effectIndexAtPos(block3X, rpy), block3X, rpy, color) end
        --if block4 then tryAttach(changedList, changedColorList, effectIndexAtPos(block4X, block4Y), block4X, block4Y, color) end
    end

    --[[
    local function extractXLine(changedList, changedColorList, hideList, index, px, py)
        local rindex = effects[index]
        local eindex = getEIndex(rindex)
        local rpx, rpy = effectDatas[eindex+1], effectDatas[eindex+2]
        local rsx, rsy = effectDatas[eindex+3], effectDatas[eindex+4]
        local ly = py - rpy

        local effect = nodeEffects[rindex]
        changedList[rindex] = nil
        changedColorList[rindex] = nil
        nodeEffects[rindex] = nil
        effects[index] = nil

        local color = effectDatas[eindex]
        if fillBlock(rpx, rpy, rsx, ly, changedList, changedColorList, hideList, color, false, effect) then effect = nil end
        if fillBlock(rpx, rpy + ly + 1, rsx, rsy - ly - 1, changedList, changedColorList, hideList, color, true, effect) then effect = nil end

        if effect then
            hideEffectLater(effect, hideList)
        end
    end
    ]]

    local function fillEffectsLinks(index, px, py, sizeX, sizeY)
        local ix, iy, endX = px, py, px + (sizeX - 1)
        for _ = 1, sizeX * sizeY do
            effects[effectIndexAtPos(ix, iy)] = index
            ix = ix + 1
            if ix > endX then
                ix = px
                iy = iy + 1
            end
        end
    end

    --[[
    local sumIsFullChangeTime = 0
    local function isFullChangeAvailable(fullChecked, changes, _changes, rindex, eindex, forDestroy)
        local effectID = nodeEffects[rindex].id
        if fullChecked[effectID] then
            return false
        end
        fullChecked[effectID] = true


        local startTime = os_clock()

        local fillX1, fillY1 = effectDatas[eindex+1], effectDatas[eindex+2]
        local fillX2, fillY2 = fillX1 + (effectDatas[eindex+3] - 1), fillY1 + (effectDatas[eindex+4] - 1)
        local baseColor = lastNewBuffer[effectIndexAtPos(fillX1, fillY1)] or lastBase

        local ix, iy = fillX1 + 1, fillY1
        if ix > fillX2 then
            ix = fillX1
            iy = iy + 1
        end
        for _ = 2, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
            local color = lastNewBuffer[effectIndexAtPos(ix, iy)] or lastBase
            if color ~= baseColor then
                sumIsFullChangeTime = sumIsFullChangeTime + (os_clock() - startTime)
                return false
            end
            ix = ix + 1
            if ix > fillX2 then
                ix = fillX1
                iy = iy + 1
            end
        end

        ix, iy = fillX1, fillY1
        if not forDestroy then
            for _ = 1, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
                local index = effectIndexAtPos(ix, iy)
                _changes[index] = true
                ix = ix + 1
                if ix > fillX2 then
                    ix = fillX1
                    iy = iy + 1
                end
            end
        end

        sumIsFullChangeTime = sumIsFullChangeTime + (os_clock() - startTime)
        return true
    end
    ]]

    --[[
    local function getBlockSize(rindex, index, px, py, color)
        local sizeX = 1
        --local sizeY = 1
        --[[
        for i = 1, maxY - py do
            if rindex ~= effects[index+i] or (lastNewBuffer[index+i] or lastBase) ~= color then
                break
            end
            sizeY = sizeY + 1
        end
        ] ]
        for i = 1, maxX - px do
            local lindex = effectIndexAtPos(px+i, py)
            if rindex ~= effects[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                break
            end
            sizeX = sizeX + 1
        end

        local ix, iy, endX = 0, 1, sizeX - 1
        for _ = 1, sizeX * (maxY - py) do
            local lindex = effectIndexAtPos(px+ix, py+iy)
            if rindex ~= effects[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                break
            end
            
            ix = ix + 1
            if ix > endX then
                ix = 0
                iy = iy + 1
                --sizeY = sizeY + 1
            end
        end

        --[[
        for iy = 1, maxY - py do
            local multibrake = false
            for ix = 0, sizeX - 1 do
                local lindex = effectIndexAtPos(px+ix, py+iy)
                if rindex ~= effects[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                    multibrake = true
                    break
                end
            end
            if multibrake then
                break
            end
            sizeY = sizeY + 1
        end
        ] ]

        return sizeX, iy
    end
    ]]

    local function getBlockSize(index, px, py, color)
        local sizeX = 1

        for i = 1, maxX - px do
            local lindex = effectIndexAtPos(px+i, py)
            if effects[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                break
            end
            sizeX = sizeX + 1
        end

        local ix, iy, endX = 0, 1, sizeX - 1
        for _ = 1, sizeX * (maxY - py) do
            local lindex = effectIndexAtPos(px+ix, py+iy)
            if effects[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                break
            end
            
            ix = ix + 1
            if ix > endX then
                ix = 0
                iy = iy + 1
            end
        end

        return sizeX, iy
    end

    local function getBlockSizeOptimization(index, px, py, color)
        local sizeX = 1

        for i = 1, maxX - px do
            local lindex = effectIndexAtPos(px+i, py)
            if effects[lindex] or not lastNewBuffer[lindex] or not colorEquals(lastNewBuffer[lindex], color) then
                break
            end
            sizeX = sizeX + 1
        end

        local ix, iy, endX = 0, 1, sizeX - 1
        for _ = 1, sizeX * (maxY - py) do
            local lindex = effectIndexAtPos(px+ix, py+iy)
            if effects[lindex] or not lastNewBuffer[lindex] or not colorEquals(lastNewBuffer[lindex], color) then
                break
            end
            
            ix = ix + 1
            if ix > endX then
                ix = 0
                iy = iy + 1
            end
        end

        return sizeX, iy
    end

    local function getChangesBlockSize(rindex, index, changes, px, py, color)
        local sizeX = 1

        for i = 1, maxX - px do
            local lindex = effectIndexAtPos(px+i, py)
            if rindex ~= effects[lindex] or not changes[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                break
            end
            sizeX = sizeX + 1
        end

        local ix, iy, endX = 0, 1, sizeX - 1
        for _ = 1, sizeX * (maxY - py) do
            local lindex = effectIndexAtPos(px+ix, py+iy)
            if rindex ~= effects[lindex] or not changes[lindex] or (lastNewBuffer[lindex] or lastBase) ~= color then
                break
            end
            
            ix = ix + 1
            if ix > endX then
                ix = 0
                iy = iy + 1
            end
        end

        return sizeX, iy
    end

    local _oldVirtualBackplateColor
    local drawer
    local lastDrawWithClear = true
    drawer = canvasAPI.createDrawer(sizeX, sizeY, nil, function (base, clearOnly, maxBuffer, force, newBuffer, realBuffer, _, _, changes, changesIndex, changesCount, _changes, clearBackplate)
        lastNewBuffer, lastBase = newBuffer, base
        lastDrawWithClear = clearBackplate

        if clearOnly and backplate then
            clearBufferedEffects()
            drawer.clearChangesBuffer()
            delAllEffects()
            return
        end

        local changedList = {}
        --local changedColorList = {}
        local hideList = {}
        --local fullChecked = {}

        --print("changesCount 1", changesCount)

        local oldChanges
        if clearBackplate then
            --local startTime = os_clock()

            oldChanges = {}
            for index in pairs(changes) do
                oldChanges[index] = true
            end

            for index in pairs(_changes) do
                if not changes[index] then
                    changesCount = changesCount + 1
                    changesIndex[changesCount] = index
                    changes[index] = true
                end
            end

            --profiller("clear-loop", startTime)
        end

        --[[
        local _changesSize = 0
        for k, v in pairs(_changes) do
            _changesSize = _changesSize + 1
        end
        print(tostring(_changes), _changesSize)
        ]]

        --print("changesCount 2", changesCount)

        --[[
        local startTime = os_clock()
        table_sort(changesIndex, function (a, b)
            return a < b
        end)
        profiller("stack-sort", startTime)
        ]]

        --[[
        local startTime = os_clock()
        for i2 = 1, changesCount do
            local index = changesIndex[i2]
            local color = newBuffer[index] or base
            local rindex = effects[index]
            if rindex then
                local eindex = getEIndex(rindex)
                if not colorEquals(effectDatas[eindex], color) then
                    local px = math_floor(index / sizeY)
                    local py = index % sizeY
                    local aSizeX, aSizeY = effectDatas[eindex+3] > 1, effectDatas[eindex+4] > 1
                    local backplateColor = color == oldBackplateColor
                    if isFullChangeAvailable(fullChecked, changes, _changes, rindex, eindex, backplateColor) then
                        if backplateColor then
                            changedList[rindex] = nil
                            changedColorList[rindex] = nil
                            hideEffectDataLater(rindex, hideList)
                        elseif not tryAttach(changedList, changedColorList, hideList, index, px, py, color) then
                            effectDatas[eindex] = color
                            changedColorList[rindex] = true
                        end
                    elseif backplateColor then
                        if aSizeX or aSizeY then
                            extractPixel(changedList, changedColorList, hideList, index, px, py)
                        else
                            changedList[rindex] = nil
                            changedColorList[rindex] = nil
                            hideEffectDataLater(rindex, hideList)
                        end
                    else
                        _changes[index] = true

                        if aSizeX or aSizeY then
                            extractPixel(changedList, changedColorList, hideList, index, px, py)
                        end

                        if not tryAttach(changedList, changedColorList, hideList, index, px, py, color) then
                            local eindex = getEIndex(index)

                            if not nodeEffects[index] then
                                local effect = createEffectUnhide(hideList)

                                local bSizeX, bSizeY = 1, 1
                                effectDatas[eindex+1] = px
                                effectDatas[eindex+2] = py
                                effectDatas[eindex+3] = bSizeX
                                effectDatas[eindex+4] = bSizeY
                                fillEffectsLinks(index, px, py, bSizeX, bSizeY)
                                
                                nodeEffects[index] = effect
                                changedList[index] = true
                            end

                            effectDatas[eindex] = color
                            changedColorList[index] = true
                        end
                    end
                end
            elseif color ~= oldBackplateColor then
                _changes[index] = true
                local px = math_floor(index / sizeY)
                local py = index % sizeY
                if not tryAttach(changedList, changedColorList, hideList, index, px, py, color) then
                    local effect = createEffectUnhide(hideList)

                    nodeEffects[index] = effect

                    local eindex = getEIndex(index)
                    local bSizeX, bSizeY = getBlockSize(index, px, py)
                    effectDatas[eindex] = color
                    effectDatas[eindex+1] = px
                    effectDatas[eindex+2] = py
                    effectDatas[eindex+3] = bSizeX
                    effectDatas[eindex+4] = bSizeY
                    fillEffectsLinks(index, px, py, bSizeX, bSizeY)
                    
                    changedList[index] = true
                    changedColorList[index] = true
                end
            end
        end
        profiller("change-loop", startTime)
        ]]

        --local localEffectsBlacklist = {}

        --local startTime = os_clock()
        for i2 = 1, changesCount do
            local index = changesIndex[i2]
            local color = newBuffer[index] or base
            local rindex = effects[index]
            if rindex --[[and not localEffectsBlacklist[rindex] ]] then
                local eindex = getEIndex(rindex)
                --local isBackgroundColor = color == oldBackplateColor
                --if color == oldBackplateColor or not colorEquals(effectDatas[eindex], color) then
                if realBuffer[index] ~= color then
                    --local px = math_floor(index / sizeY)
                    --local py = index % sizeY
                    --local aSizeX, aSizeY = effectDatas[eindex+3] > 1, effectDatas[eindex+4] > 1
                    --[[if isFullChangeAvailable(fullChecked, changes, _changes, rindex, eindex, backplateColor) then
                        if backplateColor then
                            changedList[rindex] = nil
                            changedColorList[rindex] = nil
                            hideEffectDataLater(rindex, hideList)
                        else
                            effectDatas[eindex] = color
                            changedColorList[rindex] = true
                        end
                    else]]
                    
                    --local aSizeX, aSizeY = effectDatas[eindex+3], effectDatas[eindex+4]
                    if effectDatas[eindex+3] > 1 or effectDatas[eindex+4] > 1 then
                        local px = math_floor(index / sizeY)
                        local py = index % sizeY
                        --local bSizeX, bSizeY = getBlockSize(rindex, index, px, py, color)
                        --extractPixel(changedList, changedColorList, hideList, index, px, py, bSizeX, bSizeY)
                        extractPixel(changedList, hideList, index, px, py, getChangesBlockSize(rindex, index, changes, px, py, color))

                        --[[
                        local bSizeX, bSizeY = getBlockSize(rindex, index, px, py, color)
                        if aSizeX == bSizeX and aSizeY == bSizeY then
                            effectDatas[eindex] = color
                            changedColorList[rindex] = true
                        else
                            extractPixel(changedList, changedColorList, hideList, index, px, py, bSizeX, bSizeY)
                        end
                        ]]

                        --[[
                        if not isBackgroundColor then
                            if not tryAttach(changedList, changedColorList, hideList, index, px, py, color, bSizeX, bSizeY) then
                                local effect = createEffectUnhide(hideList)

                                nodeEffects[index] = effect

                                local eindex = getEIndex(index)
                                effectDatas[eindex] = color
                                effectDatas[eindex+1] = px
                                effectDatas[eindex+2] = py
                                effectDatas[eindex+3] = bSizeX
                                effectDatas[eindex+4] = bSizeY
                                fillEffectsLinks(index, px, py, bSizeX, bSizeY)
                                
                                changedList[index] = true
                                changedColorList[index] = true
                                localEffectsBlacklist[index] = true
                            end
                        end
                        ]]
                    else
                        changedList[rindex] = nil
                        --changedColorList[rindex] = nil
                        hideEffectDataLater(rindex, hideList)
                    end
                end
            end
            realBuffer[index] = color
        end
        --profiller("extract-loop", startTime)

        --local blockSizeCache = {}
        --local startTime = os_clock()
        for i2 = 1, changesCount do
            local index = changesIndex[i2]
            local color = newBuffer[index] or base
            if color ~= oldBackplateColor then
                _changes[index] = true

                if not effects[index] then
                    local px = math_floor(index / sizeY)
                    local py = index % sizeY

                    if not tryLongAttach(changedList, hideList, index, px, py, color, 1, 1) then
                        --[[
                        local blockSize
                        if blockSizeCache[index] then
                            blockSize = blockSizeCache[index]
                            print("LOAD", index, blockSize)
                        else
                            blockSize = {getBlockSize(index, px, py, color)}
                            blockSizeCache[index] = blockSize
                        end
                        ]]

                        local bSizeX, bSizeY = getBlockSize(index, px, py, color)
                        if not tryLongAttach(changedList, hideList, index, px, py, color, bSizeX, bSizeY) then
                            local effect = createEffectUnhide(hideList)

                            nodeEffects[index] = effect

                            local eindex = getEIndex(index)
                            effectDatas[eindex] = color
                            effectDatas[eindex+1] = px
                            effectDatas[eindex+2] = py
                            effectDatas[eindex+3] = bSizeX
                            effectDatas[eindex+4] = bSizeY
                            fillEffectsLinks(index, px, py, bSizeX, bSizeY)
                            
                            changedList[index] = true
                            --changedColorList[index] = true
                        end

                        --[[
                        local effect = createEffectUnhide(hideList)

                        nodeEffects[index] = effect
                        effects[index] = index

                        local eindex = getEIndex(index)
                        effectDatas[eindex] = color
                        effectDatas[eindex+1] = px
                        effectDatas[eindex+2] = py
                        effectDatas[eindex+3] = 1
                        effectDatas[eindex+4] = 1
                        
                        changedList[index] = true
                        ]]
                    end
                end
            end
        end
        --profiller("add-loop", startTime)

        --[[
        local localEffectsBlacklist = {}
        local startTime = os_clock()
        for i2 = 1, changesCount do
            local index = changesIndex[i2]
            local color = newBuffer[index] or base
            local rindex = effects[index]
            if rindex then
                if not localEffectsBlacklist[rindex] then
                    local eindex = getEIndex(rindex)
                    local isBackgroundColor = color == oldBackplateColor
                    if isBackgroundColor or not colorEquals(effectDatas[eindex], color) then
                        if effectDatas[eindex+3] > 1 or effectDatas[eindex+4] > 1 then
                            local px = math_floor(index / sizeY)
                            local py = index % sizeY
                            local bSizeX, bSizeY = getBlockSize(rindex, index, px, py, color)
                            extractPixel(changedList, changedColorList, hideList, index, px, py, bSizeX, bSizeY)

                            if not isBackgroundColor then
                                _changes[index] = true

                                if not tryAttach(changedList, changedColorList, hideList, index, px, py, color) then
                                    local effect = createEffectUnhide(hideList)

                                    nodeEffects[index] = effect

                                    local eindex = getEIndex(index)
                                    effectDatas[eindex] = color
                                    effectDatas[eindex+1] = px
                                    effectDatas[eindex+2] = py
                                    effectDatas[eindex+3] = bSizeX
                                    effectDatas[eindex+4] = bSizeY
                                    fillEffectsLinks(index, px, py, bSizeX, bSizeY)
                                    
                                    changedList[index] = true
                                    changedColorList[index] = true
                                    localEffectsBlacklist[index] = true
                                end
                            end
                        elseif not isBackgroundColor then
                            _changes[index] = true

                            local px = math_floor(index / sizeY)
                            local py = index % sizeY
                            if not tryAttach(changedList, changedColorList, hideList, index, px, py, color) then
                                effectDatas[eindex] = color
                                changedColorList[rindex] = true
                            end
                        else
                            changedList[rindex] = nil
                            changedColorList[rindex] = nil
                            hideEffectDataLater(rindex, hideList)
                        end
                    end
                end
            elseif color ~= oldBackplateColor then
                _changes[index] = true

                local px = math_floor(index / sizeY)
                local py = index % sizeY
                if not tryAttach(changedList, changedColorList, hideList, index, px, py, color) then
                    local effect = createEffectUnhide(hideList)

                    nodeEffects[index] = effect

                    local eindex = getEIndex(index)
                    local bSizeX, bSizeY = getBlockSize(nil, index, px, py, color)
                    effectDatas[eindex] = color
                    effectDatas[eindex+1] = px
                    effectDatas[eindex+2] = py
                    effectDatas[eindex+3] = bSizeX
                    effectDatas[eindex+4] = bSizeY
                    fillEffectsLinks(index, px, py, bSizeX, bSizeY)
                    
                    changedList[index] = true
                    changedColorList[index] = true
                    localEffectsBlacklist[index] = true
                end
            end
        end
        profiller("change-loop", startTime)
        ]]

        local contentUpdated = false

        --startTime = os_clock()
        for index in pairs(changedList) do
            setEffectDataParams(index)
            contentUpdated = true
        end
        --profiller("apply-params", startTime)

        --[[
        startTime = os_clock()
        for index in pairs(changedColorList) do
            local color = effectDatas[getEIndex(index)]
            if not colorCache[color] then
                colorCache[color] = color_new_fromSmallNumber(color, alpha)
            end
            effect_setParameter(nodeEffects[index], "color", colorCache[color])
        end
        profiller("apply-colors", startTime)
        ]]
        --[[
        startTime = os_clock()
        local colorobj = color_new(0)
        for index in pairs(changedColorList) do
            local color = effectDatas[getEIndex(index)]
            colorobj.r, colorobj.g, colorobj.b = hexToRGB(color)
            colorobj.a = alpha / 255
            effect_setParameter(nodeEffects[index], "color", colorobj)
            contentUpdated = true
        end
        profiller("apply-colors", startTime)
        ]]

        --startTime = os_clock()
        for effect in pairs(hideList) do
            _setPosition(effect, hiddenOffset)
        end
        --profiller("later-hide", startTime)

        --profillerPrint("fill-sum", sumFillTime)
        --profillerPrint("extract-sum", sumExtractTime)
        --profillerPrint("attach-sum", sumAttachTime)
        --profillerPrint("attach-fill-sum", sumAttachFillTime)
        --profillerPrint("isFullChange-sum", sumIsFullChangeTime)
        --sumIsFullChangeTime = 0
        sumFillTime = 0
        sumExtractTime = 0
        sumAttachTime = 0
        sumAttachFillTime = 0
        
        if clearBackplate then
            drawer.setOldChanges(oldChanges)
            --clearBackplate = false
        end

        if clearOnly then
            clearBufferedEffects()
            return
        end

        if contentUpdated then
            lastDrawTickTime = game_getCurrentTick()
            needOptimize = true
        end
    end, nil, function (_, color, changes)
        if backplate then
            oldBackplateColor = color
            effect_setParameter(backplate, "color", color_new_fromSmallNumber(color, alpha))
        elseif color ~= _oldVirtualBackplateColor then
            drawer.fullRefresh()
            _oldVirtualBackplateColor = color
        end
    end, nil, nil, true)

    if not backplate then
        drawer.fullRefresh()
    end

    local canvasWait
    local wait_dataTunnel
    local function _setWait(wait)
        canvasWait = wait
        drawer.setWait(wait)
        if not wait and wait_dataTunnel then
            obj.realPushDataTunnelParams(wait_dataTunnel)
            wait_dataTunnel = nil
        end
    end

    _setWait(true)

    local function recreateCanvas()
        if not lastNewBuffer then
            return
        end

        if backplate and not lastDrawWithClear then --WHAT? (fixed)
            mathPopularColor()
            if lastPopularColor ~= oldBackplateColor then
                effect_setParameter(backplate, "color", color_new_fromSmallNumber(lastPopularColor, alpha))
                oldBackplateColor = lastPopularColor
                drawer.fullRefresh()
            end
        end
        
        local hideList = {}
        for i, effect in pairs(nodeEffects) do
            hideEffectLater(effect, hideList)
        end
        effects = {}
        nodeEffects = {}
        effectDatas = {}

        local changedList = {}
        --local changedColorList = {}

        --local startTime = os.clock()
        local index = 0
        while index <= maxEffectArrayBuffer do
            local px = math_floor(index / sizeY)
            local py = index % sizeY
            local color = lastNewBuffer[index] or lastBase
            if effects[index] then
                index = index + effectDatas[getEIndex(effects[index])+4]
            elseif color ~= oldBackplateColor then
                local eindex = getEIndex(index)

                local newRootIndex = tryAttach(changedList, hideList, index, px, py, color, 1, 1)
                if newRootIndex then
                    local newRootEIndex = getEIndex(newRootIndex)
                    index = effectIndexAtPos(px, effectDatas[newRootEIndex+2] + effectDatas[newRootEIndex+4])
                else
                    local effect = createEffectUnhide(hideList)

                    nodeEffects[index] = effect
                    effects[index] = index

                    effectDatas[eindex] = color
                    effectDatas[eindex+1] = px
                    effectDatas[eindex+2] = py
                    effectDatas[eindex+3] = 1
                    effectDatas[eindex+4] = 1
                    
                    changedList[index] = true
                    --changedColorList[index] = true
                    index = index + 1
                end

                --[[
                local bSizeX, bSizeY = getBlockSizeOptimization(index, px, py, color)
                local effect = createEffectUnhide(hideList)

                nodeEffects[index] = effect
                effectDatas[eindex] = color
                effectDatas[eindex+1] = px
                effectDatas[eindex+2] = py
                effectDatas[eindex+3] = bSizeX
                effectDatas[eindex+4] = bSizeY
                fillEffectsLinks(index, px, py, bSizeX, bSizeY)

                changedList[index] = true
                index = index + bSizeY
                ]]
            else
                index = index + 1
            end
        end
        --print("recreate-loop time:", os.clock() - startTime)

        for index in pairs(changedList) do
            setEffectDataParams(index)
        end

        --[[
        local colorobj = color_new(0)
        for index in pairs(changedColorList) do
            local color = effectDatas[getEIndex(index)]
            colorobj.r, colorobj.g, colorobj.b = hexToRGB(color)
            colorobj.a = alpha / 255
            effect_setParameter(nodeEffects[index], "color", colorobj)
        end
        ]]

        for effect in pairs(hideList) do
            _setPosition(effect, hiddenOffset)
        end
    end

    local _s_pixelSize, _s_offset, _s_rotation
    function obj.setCanvasMaterial(_material)
        material = _material
        local newBackplateExists = not not canvasAPI.multi_layer[tostring(material)]
        local oldBackplateExists = not not backplate

        if newBackplateExists ~= oldBackplateExists then
            _oldVirtualBackplateColor = nil
        end

        local updateParameters = false
        if newBackplateExists then
            if not oldBackplateExists then
                updateParameters = true
                oldBackplateColor = 0
                backplate = sm_effect_createEffect(getEffectName(), parent)
                effect_setParameter(backplate, "color", black)
                effect_setParameter(backplate, "uuid", material)
                if showState then
                    effect_start(backplate)
                end
            else
                effect_stop(backplate)
                effect_setParameter(backplate, "uuid", material)
                effect_start(backplate)
            end
        elseif oldBackplateExists then
            effect_destroy(backplate)
            oldBackplateColor = nil
            backplate = nil
            recreateCanvas()
        end

        for _, effect in pairs(nodeEffects) do
            effect_stop(effect)
            effect_setParameter(effect, "uuid", material)
            effect_start(effect)
        end

        for i = 1, bufferedEffectsIndex do
            local effect = bufferedEffects[i]
            effect_stop(effect)
            effect_setParameter(effect, "uuid", material)
            effect_start(effect)
        end

        local layerCreated = updateAdditionalLayer()

        if updateParameters or layerCreated then
            obj.setPixelSize(_s_pixelSize)
            obj.setOffset(_s_offset, true)
            obj.setCanvasRotation(_s_rotation)
        end
    end

    local function switchHardware()
        obj.setPixelSize(_s_pixelSize)
        obj.setOffset(_s_offset, true)
        obj.setCanvasRotation(_s_rotation)
    end

    local defaultPosition = vec3_new(0, 0, 0)
    local function getSelfPos()
        local pt = type(parent)
        if pt == "Interactable" then
            return parent.shape.worldPosition
        elseif pt == "Character" then
            return parent.worldPosition
        end
        return defaultPosition
    end

    local function updateLayersPos()
        if backplate then
            _setPosition(backplate, rotation * offset)
        end
        if additionalLayer then
            _setPosition(additionalLayer, rotation * (offset + vec3_new(0, 0, 0.0015)))
        end
    end

    local longOptimizeCounter = 0
    local lastOptimizeTime = game_getCurrentTick()
    local function optimize()
        --[[
        if bufferedEffectsIndex > 4096 then
            for i = 1, bufferedEffectsIndex - 4096 do
                effect_stop(bufferedEffects[i])
                stoppedCount = stoppedCount + 1
            end

            --[[
            if bufferedEffectsIndex > 3000 then
                if debugMode then
                    print("destroy buffered effects")
                end

                for i = 3001, bufferedEffectsIndex do
                    effect_destroy(bufferedEffects[i])
                    bufferedEffects[i] = nil
                end
                bufferedEffectsIndex = 3000
            end
            ] ]
        end
        ]]

        if longOptimizeCounter >= 3 then
            skipOptimize = true
            if debugMode then
                print("skip optimize")
            end
            return
        end

        local startTime = os_clock()
        recreateCanvas()

        local optimizeTime = os_clock() - startTime
        if optimizeTime > ((1 / 1000) * 50) then
            if debugMode then
                print("long optimize time", optimizeTime)
            end
            longOptimizeCounter = longOptimizeCounter + 1
        end

        lastOptimizeTime = game_getCurrentTick()
    end

    function obj.setAlpha(_alpha)
        alpha = _alpha
        for rindex, effect in pairs(nodeEffects) do
            effect_setParameter(effect, "color", color_new_fromSmallNumber(effectDatas[getEIndex(rindex)], alpha))
        end
    end

    function obj.setCanvasOptimizationLevel(value)
        optimizationLevel = value
        if value == 0 then
            colorEquals = colorEquals_raw
        else
            colorEquals = colorEquals_smart
        end
        optimizationValue = optimizationLevelToValue(optimizationLevel)
    end

    function obj.isRendering()
        return showState
    end

    function obj.disable(state)
        disable = state
    end

    function obj.setRenderDistance(_dist)
        dist = _dist
    end

    local reoptimizeTime = 20
    local reoptimizeDynamicTime = 40
    local canvasSize = sizeX * sizeY
    if canvasSize >= (512 * 512) then
        reoptimizeTime = 40
        reoptimizeDynamicTime = 80
    elseif canvasSize >= (256 * 256) then
        reoptimizeTime = 40
        reoptimizeDynamicTime = 60
    end

    local oldOptimizeTime
    local newShowState = true
    function obj.update()
        if disable then
            newShowState = false
        elseif dist then
            if not pcall(function()
                local currentDist = mathDist(getSelfPos(), sm_localPlayer_getPlayer().character.worldPosition)
                if currentDist <= dist then
                    newShowState = true
                elseif currentDist >= dist + 2 then
                    newShowState = false
                end
            end) then
                newShowState = false
            end
        end

        --recreateCanvas()

        if newShowState ~= showState then
            showState = newShowState
            if newShowState then
                obj.setWait(false)
                if not backplate and not flushedDefault then
                    drawer.flush(true)
                    flushedDefault = true
                end
                for _, effect in pairs(nodeEffects) do
                    if not effect_isPlaying(effect) then
                        effect_start(effect)
                    end
                end
                if backplate then
                    effect_start(backplate)
                end
                if additionalLayer then
                    effect_start(additionalLayer)
                end
            else
                for _, effect in pairs(nodeEffects) do
                    effect_stop(effect)
                end
                for i = 1, bufferedEffectsIndex do
                    effect_stop(bufferedEffects[i])
                end
                if backplate then
                    effect_stop(backplate)
                end
                if additionalLayer then
                    effect_stop(additionalLayer)
                end
                obj.setWait(true)
            end
        end

        local ctick = game_getCurrentTick()
        local optimizePeer = reoptimizeTime
        if lastDrawTickTime then
            if ctick - lastDrawTickTime < 20 then
                optimizePeer = reoptimizeDynamicTime
            end

            if longOptimizeCounter > 0 and (ctick - lastDrawTickTime > 40 * 5 or ctick - lastOptimizeTime > 40 * 10) then
                if debugMode then
                    print("reset longOptimizeCounter", longOptimizeCounter)
                end
                longOptimizeCounter = 0
                if skipOptimize then
                    optimize()
                    longOptimizeCounter = 0
                    skipOptimize = false
                end
            end
        end

        if ctick % 20 == 0 then
            local stoppedCount = 0
            local destroyedCount = 0

            if bufferedEffectsIndex > 6000 then
                for i = 6001, bufferedEffectsIndex do
                    effect_destroy(bufferedEffects[i])
                    bufferedEffects[i] = nil
                    destroyedCount = destroyedCount + 1
                end
                bufferedEffectsIndex = 6000
            end

            for i = 1, bufferedEffectsIndex - 1024 do
                local otick = bufferedEffectsUpdateTime[i]
                if otick ~= true and ctick - otick > 160 then
                    bufferedEffectsUpdateTime[i] = true
                    effect_stop(bufferedEffects[i])
                    stoppedCount = stoppedCount + 1
                end
            end

            if debugMode then
                if destroyedCount > 0 then
                    print("destroying buffered effects", destroyedCount)
                end
                print("stoping buffered effects", stoppedCount .. " / " .. bufferedEffectsIndex)
            end
        end

        if newShowState and needOptimize and optimizePeer and (not oldOptimizeTime or ctick - oldOptimizeTime >= optimizePeer) then
            needOptimize = false
            oldOptimizeTime = ctick
            optimize()
        end

        updateLayersPos()
    end

    function obj.setPixelSize(_pixelSize)
        pixelSize = _pixelSize or vec3_new(0.25 / 4, 0.25 / 4, 0.05 / 4)
        if type(pixelSize) == "Vec3" then
            _s_pixelSize = vec3_new(pixelSize.x, pixelSize.y, pixelSize.z)
        else
            _s_pixelSize = pixelSize
        end
        if type(pixelSize) == "number" then
            if pixelSize < 0 then
                pixelSize = math_abs(pixelSize)
                local vec = vec3_new(pixelSize, pixelSize, 0)
                vec.z = 0.00025
                obj.setPixelSize(vec)
                return
            else
                local vec = vec3_new(0.0072, 0.0072, 0) * pixelSize
                vec.z = 0.00025
                obj.setPixelSize(vec)
                return
            end
        end
        pixelSize.x = pixelSize.x * oldHardwareParams.scale_x * pixelScaleX
        pixelSize.y = pixelSize.y * oldHardwareParams.scale_y * pixelScaleY
        --pixelSize.x = pixelSize.x + 0.00025
        --pixelSize.y = pixelSize.y + 0.00025
        if backplate then
            effect_setScale(backplate, vec3_new(pixelSize.x * sizeX, pixelSize.y * sizeY, pixelSize.z))
        end
        updateLayerDistance(math.max(pixelSize.x * sizeX, pixelSize.y * sizeY) / 1000)
        if additionalLayer then
            effect_setScale(additionalLayer, vec3_new(pixelSize.x * sizeX * 1.005, pixelSize.y * sizeY * 1.005, math.min(2, layerDistance + ((pixelSize.x * sizeX) / 3 / 128))))
        end
        if autoScaleAddValue then
            scaleAddValue = math_min((pixelSize.x + pixelSize.y) / 50, 0.0002)
        end
    end

    function obj.setOffset(_offset, noUpdateParameters)
        offset = vec3_new(_offset.x, _offset.y, _offset.z)
        _s_offset = vec3_new(_offset.x, _offset.y, _offset.z)
        offset.x = offset.x + oldHardwareParams.offset_x
        offset.y = offset.y + oldHardwareParams.offset_y
        offset.z = offset.z + oldHardwareParams.offset_z
        updateLayersPos()
        if not noUpdateParameters then
            for index in pairs(nodeEffects) do
                setEffectDataParams(index)
            end
        end
    end

    function obj.setCanvasRotation(_rotation)
        _s_rotation = _rotation
        if type(_rotation) == "Quat" then
        elseif altFromEuler then
            _rotation = custom_fromEulerYEnd(math.rad(_rotation.x) + oldHardwareParams.rotation_x, math.rad(_rotation.y) + oldHardwareParams.rotation_y, math.rad(_rotation.z) + oldHardwareParams.rotation_z)
        else
            _rotation = quat_fromEuler(vec3_new(_rotation.x + math.deg(oldHardwareParams.rotation_x), _rotation.y + math.deg(oldHardwareParams.rotation_y), _rotation.z + math.deg(oldHardwareParams.rotation_z)))
        end
        rotation = _rotation
        if backplate then
            _setRotation(backplate, rotation)
        end
        if additionalLayer then
            _setRotation(additionalLayer, rotation)
        end
        for index, effect in pairs(nodeEffects) do
            _setRotation(effect, rotation)
            setEffectDataParams(index)
        end
        for _, effect in pairs(bufferedEffects) do
            _setRotation(effect, rotation)
        end
    end

    function obj.destroy()
        for _, effect in pairs(nodeEffects) do
            effect_destroy(effect)
        end
        if backplate then
            effect_destroy(backplate)
        end
        if additionalLayer then
            effect_destroy(additionalLayer)
        end
    end

    local function raw_setResolution(_sizeX, _sizeY)
        drawer.setDrawerResolution(_sizeX, _sizeY)

        for _, effect in pairs(nodeEffects) do
            hideEffect(effect)
        end
        effects = {}
        nodeEffects = {}
        effectDatas = {}
        
        sizeX = _sizeX
        sizeY = _sizeY
        obj.sizeX = sizeX
        obj.sizeY = sizeY
        maxX, maxY = sizeX - 1, sizeY - 1
        maxEffectArrayBuffer = maxX + (maxY * sizeX)
        pixelScaleX, pixelScaleY = defaultSizeX / sizeX, defaultSizeY / sizeY
    end

    function obj.setCanvasResolution(_sizeX, _sizeY)
        raw_setResolution(_sizeX, _sizeY)
        switchHardware()
    end

    ---------------------------------------

    obj.setPixelSize(pixelSize)
    obj.setCanvasRotation(rotation or vec3_new(0, 0, 0))
    obj.setOffset(offset or vec3_new(0, 0, 0))

    ---------------------------------------

    obj.drawer = drawer
    for k, v in pairs(drawer) do
        obj[k] = v
    end
    obj.setWait = _setWait

    function obj.pushDataTunnelParams(dataTunnel)
        if canvasWait then
            wait_dataTunnel = dataTunnel
        else
            wait_dataTunnel = nil
            obj.realPushDataTunnelParams(dataTunnel)
        end
    end

    function obj.realPushDataTunnelParams(dataTunnel)
        obj.setCanvasOptimizationLevel(dataTunnel.optimizationLevel)
        drawer.pushDataTunnelParams(dataTunnel)

        if not disableRotation then
            if dataTunnel.altRotation then
                setEffectDataParams = _setEffectDataParams_altRotation
            else
                setEffectDataParams = _setEffectDataParams_defaultRotation
            end
        end

        local hardwareParamsChanged = false
        if dataTunnel.res_x ~= sizeX or dataTunnel.res_y ~= sizeY then
            raw_setResolution(dataTunnel.res_x, dataTunnel.res_y)

            hardwareParamsChanged = true
        end

        obj.setAlpha(dataTunnel.light)
        if dataTunnel.material and dataTunnel.material ~= material then
            obj.setCanvasMaterial(dataTunnel.material)
        end
        for key, value in pairs(oldHardwareParams) do
            if dataTunnel[key] ~= value then
                hardwareParamsChanged = true
                oldHardwareParams[key] = dataTunnel[key]
            end
        end
        if hardwareParamsChanged then
            switchHardware()
        end
    end

    return obj
end

--simulates the API of display from SComputers on the client side of your parts
--this is the easiest way to implement the display in your mod
function canvasAPI.createClientScriptableCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation, material)
    local dataTunnel = {}
    local canvas = canvasAPI.createCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation, material)
    local api = canvasAPI.createScriptableApi(sizeX, sizeY, dataTunnel, nil, canvas.drawer, canvasAPI.materialList, 1, {
        maxOffset = math.huge,
        maxScale = math.huge
    }, {
        maxPixels = math.huge
    })
    api.registerClick = canvasAPI.addTouch(api, dataTunnel)
    api.dataTunnel = dataTunnel
    api.canvas = canvas

    local renderDistance = 15

    for k, v in pairs(canvas) do
        if k ~= "flush" then
            api[k] = v
        end
    end

    function api.getAudience()
        return canvas.isRendering() and 1 or 0
    end

    function api.update()
        canvas.disable(not api.isAllow())
        if dataTunnel.renderAtDistance then
            canvas.setRenderDistance()
        else
            canvas.setRenderDistance(renderDistance)
        end
        canvas.pushDataTunnelParams(dataTunnel)
        canvas.update()
        dataTunnel.scriptableApi_update()

        if dataTunnel.display_reset then
            canvas.drawerReset()
            dataTunnel.display_reset = nil
        end

        if dataTunnel.display_flush then
            if needPushStack(canvas, dataTunnel) then
                canvas.pushStack(dataTunnel.display_stack)
                canvas.flush()
            end
            
            dataTunnel.display_flush()
            dataTunnel.display_stack = nil
            dataTunnel.display_flush = nil
            dataTunnel.display_forceFlush = nil
        end
    end

    function api.setRenderDistance(dist)
        renderDistance = dist
    end

    return api
end

local customFontIndexesCache = {}
local checkedFonts = {}

--implement the SComputers API, does not implement data transfer
function canvasAPI.createScriptableApi(width, height, dataTunnel, flushCallback, drawer, materialList, defaultMaterial, allowHoloAPI, allowSetResolution)
    local defaultResolutionX, defaultResolutionY = width, height
    
    dataTunnel = dataTunnel or {}
    dataTunnel.rotation = 0
    dataTunnel.light = DEFAULT_ALPHA_VALUE
    dataTunnel.skipAtNotSight = false
    dataTunnel.utf8support = false
    dataTunnel.renderAtDistance = false
    dataTunnel.display_forceFlush = true
    dataTunnel.dataUpdated = true
    dataTunnel.optimizationLevel = 16

    local stack = {}
    local stackIndex = 1
    local pixelsCache = {} --optimizations for cameras
    local pixelsCacheExists = false
    local oldStackSum, oldDataSum, oldStack, oldStackIndex
    local forceFlag = false

    local function clearStackForce()
        stack = {}
        stackIndex = 1
    end

    local function clearStack()
        if dataTunnel.display_stack == stack then
            clearStackForce()
        end
    end

    local function setForceFrame()
        if pixelsCacheExists then
            pixelsCache = {}
            pixelsCacheExists = false
        end
        forceFlag = true
        dataTunnel.display_forceFlush = true
    end

    local oldPlayersCount = #sm.player.getAllPlayers()
    function dataTunnel.scriptableApi_update()
        local playersCount = #sm.player.getAllPlayers()
        --local force = sm.game.getCurrentTick() % 80 == 0
        local force = false
        if oldPlayersCount ~= playersCount or force then
            --dataTunnel.display_forceForceFlush = force
            setForceFrame()
            oldPlayersCount = playersCount
        end
    end

    local rwidth, rheight = width, height
    local rmwidth, rmheight = width - 1, height - 1
    local utf8support = false
    local monoFont = true
    local newDataFlag = false
    local spacing = 1
    local fontIndex = 0
    local lastPixelX, lastPixelY, lastPixelColor, lastAction
    local currentSettedFont
    local currentTouchs = {}

    local viewport_x, viewport_y, viewport_sx, viewport_sy

    local dFontX, dFontY = defaultFont.width, defaultFont.height
    local drFontX, drFontY = defaultFont.width, defaultFont.height
    local fontX, fontY
    local mFontX, mFontY
    local xFontX, xFontY
    local sFontX, sFontY
    local rFontX, rFontY
    local fontScaleX, fontScaleY = 1, 1
    local function updateFontSize()
        fontX, fontY = math_ceil(dFontX * fontScaleX), math_ceil(dFontY * fontScaleY)
        rFontX, rFontY = math_ceil(drFontX * fontScaleX), math_ceil(drFontY * fontScaleY)
        mFontX, mFontY = fontX - 1, fontY - 1
        xFontX, xFontY = fontX + 1, fontY + 1
        sFontX, sFontY = fontX + spacing, fontY + 1
    end
    updateFontSize()

    ---------------- color equals check
    local optimizationValue = optimizationLevelToValue(16)

    --local maxVal = math_sqrt((255 ^ 2) + (255 ^ 2) + (255 ^ 2))
    local function colorEquals_smart(color1, color2)
        if color1 == color2 then return true end
        local rVal, gVal, bVal = hexToRGB256(color1)
        local rVal2, gVal2, bVal2 = hexToRGB256(color2)
        --return (math_sqrt(((rVal - rVal2) ^ 2) + ((gVal - gVal2) ^ 2) + ((bVal - bVal2) ^ 2)) / maxVal) <= optimizationValue
        return ((math_abs(rVal - rVal2) + math_abs(gVal - gVal2) + math_abs(bVal - bVal2)) / 1024) <= optimizationValue
    end

    local colorEquals = colorEquals_smart

    local function colorEquals_raw(color1, color2)
        return color1 == color2
    end

    ----------------

    local api
    local api_flush
    api = {
        --[[
        getBuffer = function (x, y)
            if not drawer or x < 0 or x >= width or y < 0 or y >= height then return 0 end
            return drawer.getNewBuffer(x + (y * rwidth))
        end,
        getCurrent = function (x, y)
            if not drawer or x < 0 or x >= width or y < 0 or y >= height then return 0 end
            return drawer.getRealBuffer(x + (y * rwidth))
        end,
        ]]
        get = function (x, y)
            if not drawer or x < 0 or x >= width or y < 0 or y >= height then return 0 end
            return drawer.getNewBuffer(y + (x * rheight))
        end,

        -- not implemented (implement it yourself if necessary)
        isAllow = function()
            return true
        end,
        getAudience = function()
            return 1
        end,

        setOptimizationLevel = function(value)
            checkArg(1, value, "number")
            value = round(value)
            if value < 0 then value = 0 end
            if value > 255 then value = 255 end
            if dataTunnel.optimizationLevel ~= value then
                optimizationValue = optimizationLevelToValue(value)
                if value == 0 then
                    colorEquals = colorEquals_raw
                else
                    colorEquals = colorEquals_smart
                end

                dataTunnel.optimizationLevel = value
                dataTunnel.dataUpdated = true
            end
        end,
        getOptimizationLevel = function()
            return dataTunnel.optimizationLevel
        end,


        -- stubs (outdated methods)
        optimize = function() end,
        setFrameCheck = function () end,
        getFrameCheck = function () return false end,
        setSkipAtLags = function() end,
        getSkipAtLags = function() return false end,


        -- main
        setFontScale = function(scaleX, scaleY)
            checkArg(1, scaleX, "number")
            checkArg(2, scaleY, "number")
            if scaleX < 0 then scaleX = 0 end
            if scaleY < 0 then scaleY = 0 end
            fontScaleX, fontScaleY = scaleX, scaleY
            updateFontSize()
        end,
        getFontScale = function()
            return fontScaleX, fontScaleY
        end,
        setTextSpacing = function(_spacing)
            if _spacing < 0 then _spacing = 0 end
            spacing = _spacing
            updateFontSize()
        end,
        setFontSize = function(_width, _height)
            api.setFontScale(_width / dFontX, _height / dFontY)
        end,
        getTextSpacing = function()
            return spacing
        end,
        calcTextBox = function(text) --it will return two numbers, this will be the size of the box that your text will occupy with this font and this scale
            local px, py
            local len, sep
            if utf8support then
                len, sep = utf8_len, utf8_sub
            else
                len, sep = string_len, string_byte
            end

            local textLen = len(text)
            if textLen == 0 then
                return 0, 0
            end

            local totalSize = 0
            if monoFont then
                totalSize = textLen * (fontX + spacing)
            else
                local localFontWidth = dFontX
                local localFont = dataTunnel.customFont or font.optimized
                if fontIndex > 0 and fontsOptimized[fontIndex] then
                    localFont = fontsOptimized[fontIndex]
                    localFontWidth = localFont.width
                end

                local char, chrdata
                for i = 1, textLen do
                    char = sep(text, i, i)
                    if char ~= " " and char ~= spaceCharCode then
                        chrdata = localFont[char] or localFont.error or defaultError
                        totalSize = totalSize + (chrdata[0] and math_ceil(chrdata[0] * fontScaleX) or 0) + spacing
                    else
                        totalSize = totalSize + (localFont.spaceSize or localFontWidth) + spacing
                    end
                    canvasAPI.yield()
                end
            end

            return totalSize - spacing, fontY
        end,
        calcCharsSize = function(text) --calculates the length of each character in a string, taking into account its spacing from the next character, and returns a table with these values
            local px, py
            local len, sep
            if utf8support then
                len, sep = utf8_len, utf8_sub
            else
                len, sep = string_len, string_byte
            end

            local textLen = len(text)
            if textLen == 0 then
                return 0, 0
            end

            local lens = {}

            local localFontWidth = dFontX
            local localFont = dataTunnel.customFont or font.optimized
            if fontIndex > 0 and fontsOptimized[fontIndex] then
                localFont = fontsOptimized[fontIndex]
                localFontWidth = localFont.width
            end

            local char, chrdata
            for i = 1, textLen do
                char = sep(text, i, i)
                if char ~= " " and char ~= spaceCharCode then
                    chrdata = localFont[char] or localFont.error or defaultError
                    table_insert(lens, (chrdata[0] and math_ceil(chrdata[0] * fontScaleX) or 0) + spacing)
                else
                    table_insert(lens, (localFont.spaceSize or localFontWidth) + spacing)
                end
                canvasAPI.yield()
            end

            lens[#lens] = lens[#lens] - spacing
            return lens
        end,
        calcDecreasingTextSizes = function(text) --it works almost like calcCharsSize. however, each value contains all the previous ones. this is used in the graphic.textBox function, but probably not applicable to any other
            local px, py
            local len, sep
            if utf8support then
                len, sep = utf8_len, utf8_sub
            else
                len, sep = string_len, string_byte
            end

            local textLen = len(text)
            if textLen == 0 then
                return 0, 0
            end

            local lens = {}
            local otherVals = 0

            local localFontWidth = dFontX
            local localFont = dataTunnel.customFont or font.optimized
            if fontIndex > 0 and fontsOptimized[fontIndex] then
                localFont = fontsOptimized[fontIndex]
                localFontWidth = localFont.width
            end

            local char, chrdata
            for i = 1, textLen do
                char = sep(text, i, i)
                local val
                if char ~= " " and char ~= spaceCharCode then
                    chrdata = localFont[char] or localFont.error or defaultError
                    val = (chrdata[0] and math_ceil(chrdata[0] * fontScaleX) or 0) + spacing
                else
                    val = (localFont.spaceSize or localFontWidth) + spacing
                end
                otherVals = otherVals + val
                table_insert(lens, otherVals)
                canvasAPI.yield()
            end

            lens[#lens] = lens[#lens] - spacing
            return lens
        end,
        isMonospacedFont = function()
            return not not monoFont
        end,

        getWidth = function()
            return rwidth
        end,
        getHeight = function()
            return rheight
        end,
        getSize = function()
            return rwidth, rheight
        end,
        getResolution = function()
            return rwidth, rheight
        end,

        clear = function(color)
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end

            lastAction = nil

            clearStackForce()
            stackIndex = 4
            stack[1] = resetViewportCodeID
            stack[2] = 0
            stack[3] = formatColorToSmallNumber(color, blackSmallNumber)
            
            --[[
            for i = 3, stackIndex - 1 do
                stack[i] = nil
            end
            stackIndex = 3
            ]]
        end,
        drawPixel = function(x, y, color)
            x, y = round(x), round(y)
            if x < 0 or x >= width or y < 0 or y >= height then return end
            local index = x + (y * rwidth)
            color = formatColorToSmallNumber(color, whiteSmallNumber)
            if pixelsCache[index] ~= color then
                if lastAction and x == lastPixelX + 1 and y == lastPixelY and colorEquals(lastPixelColor, color) then
                    if lastAction == 1 then
                        local i = stackIndex - 1
                        stack[i] = stack[i] + 1
                    else
                        stack[stackIndex] = 12
                        stackIndex = stackIndex + 1
                        stack[stackIndex] = 1
                        stackIndex = stackIndex + 1
                    end

                    lastAction = 1
                elseif lastAction and x == lastPixelX - 1 and y == lastPixelY and colorEquals(lastPixelColor, color) then
                    if lastAction == 2 then
                        local i = stackIndex - 1
                        stack[i] = stack[i] + 1
                    else
                        stack[stackIndex] = 13
                        stackIndex = stackIndex + 1
                        stack[stackIndex] = 1
                        stackIndex = stackIndex + 1
                    end

                    lastAction = 2
                elseif lastAction and x == lastPixelX and y == lastPixelY + 1 and colorEquals(lastPixelColor, color) then
                    if lastAction == 3 then
                        local i = stackIndex - 1
                        stack[i] = stack[i] + 1
                    else
                        stack[stackIndex] = 14
                        stackIndex = stackIndex + 1
                        stack[stackIndex] = 1
                        stackIndex = stackIndex + 1
                    end

                    lastAction = 3
                elseif lastAction and x == lastPixelX and y == lastPixelY - 1 and colorEquals(lastPixelColor, color) then
                    if lastAction == 4 then
                        local i = stackIndex - 1
                        stack[i] = stack[i] + 1
                    else
                        stack[stackIndex] = 15
                        stackIndex = stackIndex + 1
                        stack[stackIndex] = 1
                        stackIndex = stackIndex + 1
                    end

                    lastAction = 4
                else
                    lastPixelColor = color

                    stack[stackIndex] = 16
                    stackIndex = stackIndex + 1
                    stack[stackIndex] = index
                    stackIndex = stackIndex + 1
                    stack[stackIndex] = color
                    stackIndex = stackIndex + 1

                    lastAction = 0
                end

                lastPixelX, lastPixelY = x, y
                pixelsCache[index] = color
                pixelsCacheExists = true
            end
        end,
        fillRect = function(x, y, sizeX, sizeY, color)
            if x <= 0 and y <= 0 and x + sizeX >= width and y + sizeY >= height then
                return api.clear(color or 0xffffff)
            end

            stack[stackIndex] = 2
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeX)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeY)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawEllipse = function(x, y, sizeX, sizeY, cornerRadius, color)
            stack[stackIndex] = 17
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeX)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeY)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(cornerRadius)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        fillEllipse = function(x, y, sizeX, sizeY, cornerRadius, color)
            stack[stackIndex] = 18
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeX)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeY)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(cornerRadius)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawRect = function(x, y, sizeX, sizeY, color, lineWidth)
            lineWidth = round(lineWidth or 1)
            if lineWidth < 1 then
                lineWidth = 1
            end

            stack[stackIndex] = 3
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeX)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(sizeY)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            stack[stackIndex] = lineWidth
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawText = function(x, y, text, color)
            if y > rmheight or y + mFontY < 0 or fontScaleX <= 0 or fontScaleY <= 0 then return end
            text = tostring(text)

            if monoFont then
                local maxTextLen = math_ceil((width - x) / sFontX)
                if maxTextLen <= 0 then return end
                local startTextFrom = math_max(1, math_floor(-x / sFontX) + 1)

                if utf8support then
                    if utf8.len(text) > maxTextLen or startTextFrom > 1 then
                        text = utf8.sub(text, startTextFrom, maxTextLen)
                    end
                else
                    if #text > maxTextLen or startTextFrom > 1 then
                        text = text:sub(startTextFrom, maxTextLen)
                    end
                end

                if #text == 0 then return end
                stack[stackIndex] = 4
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(x) + ((startTextFrom - 1) * sFontX)
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(y)
                stackIndex = stackIndex + 1
                stack[stackIndex] = text
                stackIndex = stackIndex + 1
                stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
                stackIndex = stackIndex + 1
                stack[stackIndex] = fontScaleX
                stackIndex = stackIndex + 1
                stack[stackIndex] = fontScaleY
                stackIndex = stackIndex + 1
                stack[stackIndex] = spacing
                stackIndex = stackIndex + 1
                stack[stackIndex] = fontIndex
                stackIndex = stackIndex + 1
            else
                if #text == 0 then return end
                stack[stackIndex] = 4
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(x)
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(y)
                stackIndex = stackIndex + 1
                stack[stackIndex] = text
                stackIndex = stackIndex + 1
                stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
                stackIndex = stackIndex + 1
                stack[stackIndex] = fontScaleX
                stackIndex = stackIndex + 1
                stack[stackIndex] = fontScaleY
                stackIndex = stackIndex + 1
                stack[stackIndex] = spacing
                stackIndex = stackIndex + 1
                stack[stackIndex] = fontIndex
                stackIndex = stackIndex + 1
            end
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawCenteredText = function(x, y, text, color, centerX, centerY)
            if centerX == nil then centerX = true end
            if centerY == nil then centerY = true end
            
            local sizeX, sizeY
            if centerX or centerY then
                sizeX, sizeY = api.calcTextBox(text)
            end

            if centerX then
                x = x - (sizeX / 2)
            end

            if centerY then
                y = y - (sizeY / 2)
            end

            api.drawText(x, y, text, color)
        end,
        drawLine = function(x, y, x2, y2, color, width, roundFlag)
            width = round(width or 1)
            if width < 1 then
                width = 1
            end
            if roundFlag then
                width = -width
            end

            stack[stackIndex] = 5
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x2)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y2)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            stack[stackIndex] = width
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawCircle = function (x, y, r, color)
            stack[stackIndex] = 6
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(r)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        fillCircle = function (x, y, r, color)
            stack[stackIndex] = 7
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(r)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawCircleEvenly = function (x, y, r, color)
            stack[stackIndex] = 8
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(r)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawCircleVeryEvenly = function (x, y, r, color, stroke)
            if not stroke or stroke < 1 then stroke = 1 end

            stack[stackIndex] = 9
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(x)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(y)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(r)
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1
            stack[stackIndex] = round(stroke)
            stackIndex = stackIndex + 1
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawPoly = function(color, ...)
            api.drawWidePoly(color, 1, false, ...)
        end,
        drawWidePoly = function(color, width, roundFlag, ...)
            stack[stackIndex] = 10
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1

            width = round(width or 1)
            if width < 1 then
                width = 1
            end
            if roundFlag then
                width = -width
            end

            local points = {...}
            if #points == 0 or #points % 2 ~= 0 then
                error("an odd number of points are specified", 2)
            end
            stack[stackIndex] = #points
            stackIndex = stackIndex + 1

            stack[stackIndex] = width
            stackIndex = stackIndex + 1

            for _, v in ipairs(points) do
                stack[stackIndex] = round(v)
                stackIndex = stackIndex + 1
            end
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        fillPoly = function(color, ...)
            api.fillWidePoly(color, 1, false, ...)
        end,
        fillWidePoly = function(color, width, roundFlag, ...)
            stack[stackIndex] = 11
            stackIndex = stackIndex + 1
            stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
            stackIndex = stackIndex + 1

            width = round(width or 1)
            if width < 1 then
                width = 1
            end
            if roundFlag then
                width = -width
            end

            local points = {...}
            if #points == 0 or #points % 2 ~= 0 then
                error("an odd number of points are specified", 2)
            end
            stack[stackIndex] = #points
            stackIndex = stackIndex + 1

            stack[stackIndex] = width
            stackIndex = stackIndex + 1

            for _, v in ipairs(points) do
                stack[stackIndex] = round(v)
                stackIndex = stackIndex + 1
            end
            
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end
        end,
        drawTriangle = function(x1, y1, x2, y2, x3, y3, color)
            api.drawPoly(color, x1, y1, x2, y2, x3, y3)
        end,
        fillTriangle = function(x1, y1, x2, y2, x3, y3, color)
            api.fillPoly(color, x1, y1, x2, y2, x3, y3)
        end,
        flush = function()
            lastAction = nil
            api.setViewport()

            if dataTunnel.display_flush and dataTunnel.display_stack == stack then
                return
            end

            local needFlush = forceFlag
            --print("--------------------------- FLUSH 1", needFlush, stack, stackChecksum(stack), stackChecksum(canvasAPI.minimizeDataTunnel(dataTunnel)))

            if not needFlush and stackIndex ~= oldStackIndex then
                --print("FLUSH 2", stackIndex, oldStackIndex)
                needFlush = true
            end

            if not needFlush and newDataFlag then
                local dataSum = stackChecksum(canvasAPI.minimizeDataTunnel(dataTunnel))
                if dataSum ~= oldDataSum then
                    --print("FLUSH 3")
                    needFlush = true
                    oldDataSum = dataSum
                end
            end

            if not needFlush and stack ~= oldStack then
                for i = 1, stackIndex - 1 do
                    if stack[i] ~= oldStack[i] then
                        needFlush = true
                        --print("FLUSH 4", oldStack)
                        break
                    end
                end
            end

            --[[
            if needFlush then
                oldStackSum = nil
            else
                local stachSum = stackChecksum(stack)
                if stachSum ~= oldStackSum then
                    --print("FLUSH 5")
                    needFlush = true
                    oldStackSum = stachSum
                end
            end
            ]]
            
            if needFlush then
                --print("FLUSH ACTION")
                oldStack = stack
                oldStackIndex = stackIndex

                dataTunnel.display_stack = stack
                dataTunnel.display_flush = clearStack
                
                if flushCallback then
                    flushCallback()
                end
            else
                clearStackForce()
            end

            forceFlag = false
            newDataFlag = false
        end,
        forceFlush = function()
            api_flush()
            dataTunnel.display_forceFlush = true
        end,

        -- settings
        setUtf8Support = function (state)
            if type(state) == "boolean" then
                if dataTunnel.utf8support ~= state then
                    dataTunnel.utf8support = state
                    dataTunnel.dataUpdated = true
                    newDataFlag = true
                    utf8support = state
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getUtf8Support = function () return dataTunnel.utf8support end,

        setRenderAtDistance = function (c)
            if type(c) == "boolean" then
                if dataTunnel.renderAtDistance ~= c then
                    dataTunnel.renderAtDistance = c
                    dataTunnel.dataUpdated = true
                end
            else
                error("Type must be boolean", 2)
            end
        end,
        getRenderAtDistance = function () return dataTunnel.renderAtDistance end,

        setRotation = function (rotation)
            if type(rotation) == "number" and rotation % 1 == 0 and rotation >= 0 and rotation <= 3 then
                if rotation ~= dataTunnel.rotation then
                    dataTunnel.rotation = rotation
                    dataTunnel.dataUpdated = true
                    newDataFlag = true

                    if pixelsCacheExists then
                        pixelsCache = {}
                        pixelsCacheExists = false
                    end

                    if rotation == 1 or rotation == 3 then
                        rwidth = height
                        rheight = width
                    else
                        rwidth = width
                        rheight = height
                    end
                    rmheight = rheight - 1
                    rmwidth = rwidth - 1
                end
            else
                error("integer must be in [0; 3]", 2)
            end
        end,
        getRotation = function () return dataTunnel.rotation end,

        setFont = function (customFont)
            checkArg(1, customFont, "table", "nil")
            currentSettedFont = customFont
            fontIndex = 0
            if dataTunnel.customFont then
                dataTunnel.dataUpdated = true
                dataTunnel.customFont = nil
            end
            if customFont then
                if not checkedFonts[customFont] then
                    checkFont(customFont)
                    checkedFonts[customFont] = true
                end
                dFontX, dFontY = customFont.width, customFont.height
                drFontX, drFontY = customFont.returnWidth or customFont.width, customFont.returnHeight or customFont.height
                fontIndex = customFontIndexesCache[customFont]
                if not fontIndex then
                    fontIndex = 0
                    for _, v in pairs(fonts) do
                        if v == customFont then
                            fontIndex = v.index
                        end
                    end
                    customFontIndexesCache[customFont] = fontIndex
                end
                if fontIndex == 0 then
                    dataTunnel.customFont = font.optimizeFont(customFont)
                    dataTunnel.dataUpdated = true
                end
                monoFont = customFont.mono or customFont.mono == nil
            else
                dFontX, dFontY = defaultFont.width, defaultFont.height
                drFontX, drFontY = defaultFont.width, defaultFont.height
                monoFont = true
            end
            updateFontSize()
            newDataFlag = true
        end,
        getFont = function()
            return currentSettedFont
        end,

        getFontWidth = function ()
            return rFontX
        end,
        getFontHeight = function ()
            return rFontY
        end,
        getFontSize = function()
            return rFontX, rFontY
        end,

        getRealFontWidth = function ()
            return drFontX
        end,
        getRealFontHeight = function ()
            return drFontY
        end,
        getRealFontSize = function()
            return drFontX, drFontY
        end,

        setSkipAtNotSight = function (state)
            checkArg(1, state, "boolean")
            if dataTunnel.skipAtNotSight ~= state then
                dataTunnel.skipAtNotSight = state
                dataTunnel.dataUpdated = true
            end
        end,
        getSkipAtNotSight = function () return dataTunnel.skipAtNotSight end,

        getViewport = function()
            return viewport_x, viewport_y, viewport_sx, viewport_sy
        end,
        setViewport = function(x, y, sizeX, sizeY)
            if x or y or sizeX or sizeY then
                viewport_x, viewport_y, viewport_sx, viewport_sy = x or 0, y or 0, sizeX or api.getWidth(), sizeY or api.getHeight()
                stack[stackIndex] = -1
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(viewport_x)
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(viewport_y)
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(viewport_sx)
                stackIndex = stackIndex + 1
                stack[stackIndex] = round(viewport_sy)
                stackIndex = stackIndex + 1
            else
                viewport_x, viewport_y, viewport_sx, viewport_sy = nil, nil, nil, nil
                stack[stackIndex] = resetViewportCodeID
                stackIndex = stackIndex + 1
            end
        end,
        setInlineViewport = function(x, y, sizeX, sizeY)
            if viewport_x then
                local x2 = x + (sizeX - 1)
                local y2 = y + (sizeY - 1)
                local px2 = viewport_x + (viewport_sx - 1)
                local py2 = viewport_y + (viewport_sy - 1)
                if x < viewport_x then x = viewport_x elseif x > px2 then x = px2 end
                if y < viewport_y then y = viewport_y elseif y > py2 then y = py2 end
                if x2 < viewport_x then x2 = viewport_x elseif x2 > px2 then x2 = px2 end
                if y2 < viewport_y then y2 = viewport_y elseif y2 > py2 then y2 = py2 end
                api.setViewport(x, y, (x2 - x) + 1, (y2 - y) + 1)
            else
                api.setViewport(x, y, sizeX, sizeY)
            end
        end,

        setBrightness = function(value) --legacy
            checkArg(1, value, "number")
            --[[
            if value < 0 then value = 0 end
            if value > 255 then value = 255 end
            if dataTunnel.brightness ~= value then
                dataTunnel.brightness = value
                dataTunnel.dataUpdated = true
            end
            ]]
        end,
        getBrightness = function() --legacy
            --return dataTunnel.brightness
            return 1
        end,

        setLight = function(value)
            checkArg(1, value, "number")
            value = math_floor(value + 0.5)
            if value < 0 then value = 0 end
            if value > 255 then value = 255 end
            if dataTunnel.light ~= value then
                dataTunnel.light = value
                dataTunnel.dataUpdated = true
            end
        end,
        getLight = function(value)
            return dataTunnel.light
        end,

        getDefaultResolution = function()
            return defaultResolutionX, defaultResolutionY
        end,

        getTouchs = function()
            for i = 1, MAX_CLICKS do
                local click = api.getClick()
                if not click then
                    break
                end
                local index = #currentTouchs + 1
                for lindex, lclick in reverse_ipairs(currentTouchs) do
                    if lclick.nickname == click.nickname and lclick.button == click.button then
                        index = lindex
                        break
                    end
                end
                if click.state == "released" then
                    table.remove(currentTouchs, index)
                else
                    currentTouchs[index] = click
                end
            end

            return currentTouchs
        end,

        getTouch = function()
            return api.getTouchs()[1]
        end,

        reset = function()
            currentTouchs = {}
            if api.setMaterial then api.setMaterial(api.getDefaultMaterial()) end
            if api.setFontScale then api.setFontScale(1, 1) end
            if api.setTextSpacing then api.setTextSpacing(1) end
            if api.setFont then api.setFont() end
            if api.setRotation then api.setRotation(0) end
            if api.setUtf8Support then api.setUtf8Support(false) end
            if api.setClicksAllowed then api.setClicksAllowed(false) end
            if api.setMaxClicks then api.setMaxClicks(MAX_CLICKS) end
            if api.clearClicks then api.clearClicks() end
            if api.setSkipAtNotSight then api.setSkipAtNotSight(false) end
            if api.setRenderAtDistance then api.setRenderAtDistance(false) end
            if api.setViewport then api.setViewport() end
            if api.setLight then api.setLight(DEFAULT_ALPHA_VALUE) end
            if api.setOptimizationLevel then api.setOptimizationLevel(16) end
            if api.setHoloOffset then api.setHoloOffset(0, 0, 0) end
            if api.setHoloRotation then api.setHoloRotation(0, 0, 0) end
            if api.setHoloScale then api.setHoloScale(1, 1) end
            if api.setResolution then api.setResolution(defaultResolutionX, defaultResolutionY) end
            dataTunnel.display_reset = true
        end
    }

    if materialList then
        defaultMaterial = defaultMaterial or (materialList[0] and 0 or 1)
        local currentMaterialID

        function api.setMaterial(materialId)
            checkArg(1, materialId, "number")
            currentMaterialID = materialId
            if not materialList[currentMaterialID] then
                currentMaterialID = defaultMaterial
            end
            local material = materialList[currentMaterialID]
            if material == true then
                error("this material is not supported on this display", 2)
            end
            if dataTunnel.material ~= material then
                dataTunnel.material = material
                dataTunnel.dataUpdated = true
            end
        end

        function api.getMaterial()
            return currentMaterialID
        end

        function api.getDefaultMaterial()
            return defaultMaterial
        end

        api.setMaterial(api.getDefaultMaterial())
    end

    dataTunnel.offset_x, dataTunnel.offset_y, dataTunnel.offset_z = 0, 0, 0
    dataTunnel.rotation_x, dataTunnel.rotation_y, dataTunnel.rotation_z = 0, 0, 0
    dataTunnel.scale_x, dataTunnel.scale_y = 1, 1
    dataTunnel.altRotation = false
    if allowHoloAPI then
        local maxOffset = 5
        local maxScale = 5
        if type(allowHoloAPI) == "table" then
            maxOffset = allowHoloAPI.maxOffset or maxOffset
            maxScale = allowHoloAPI.maxScale or maxScale
        end

        function api.setHoloOffset(x, y, z)
            checkArg(1, x, "number")
            checkArg(2, y, "number")
            checkArg(3, z, "number")
            
            if x < -maxOffset then x = -maxOffset end
            if y < -maxOffset then y = -maxOffset end
            if z < -maxOffset then z = -maxOffset end
            if x > maxOffset then x = maxOffset end
            if y > maxOffset then y = maxOffset end
            if z > maxOffset then z = maxOffset end

            if x ~= dataTunnel.offset_x or y ~= dataTunnel.offset_y or z ~= dataTunnel.offset_z then
                dataTunnel.offset_x, dataTunnel.offset_y, dataTunnel.offset_z = x, y, z
                dataTunnel.dataUpdated = true
            end
        end

        function api.getHoloOffset()
            return dataTunnel.offset_x, dataTunnel.offset_y, dataTunnel.offset_z
        end

        function api.setHoloRotation(x, y, z, altRotation)
            checkArg(1, x, "number")
            checkArg(2, y, "number")
            checkArg(3, z, "number")
            checkArg(4, altRotation, "boolean", "nil")
            if x ~= dataTunnel.rotation_x or y ~= dataTunnel.rotation_y or z ~= dataTunnel.rotation_z then
                dataTunnel.rotation_x, dataTunnel.rotation_y, dataTunnel.rotation_z = x, y, z
                dataTunnel.altRotation = not not altRotation
                dataTunnel.dataUpdated = true
            end
        end

        function api.getHoloRotation()
            return dataTunnel.rotation_x, dataTunnel.rotation_y, dataTunnel.rotation_z, dataTunnel.altRotation
        end

        function api.setHoloScale(x, y)
            checkArg(1, x, "number")
            checkArg(2, y, "number")

            if x < 0 then x = 0 end
            if y < 0 then y = 0 end
            if x > maxScale then x = maxScale end
            if y > maxScale then y = maxScale end

            if x ~= dataTunnel.scale_x or y ~= dataTunnel.scale_y then
                dataTunnel.scale_x, dataTunnel.scale_y = x, y
                dataTunnel.dataUpdated = true
            end
        end

        function api.getHoloScale()
            return dataTunnel.scale_x, dataTunnel.scale_y
        end
    end

    dataTunnel.res_x, dataTunnel.res_y = defaultResolutionX, defaultResolutionY
    if allowSetResolution then
        if type(allowSetResolution) ~= "table" then
            allowSetResolution = {
                maxPixels = 4096 * 4096,
                maxWidth = 4096,
                maxHeight = 4096
            }
        end

        function api.setResolution(resX, resY)
            checkArg(1, resX, "number")
            checkArg(2, resY, "number")

            resX = math.floor(resX)
            resY = math.floor(resY)
            if resX < 1 then resX = 1 end
            if resY < 1 then resY = 1 end

            if allowSetResolution.maxWidth and resX > allowSetResolution.maxWidth then
                error("the width resolution has been exceeded. maximum: " .. allowSetResolution.maxWidth, 2)
            end

            if allowSetResolution.maxHeight and resX > allowSetResolution.maxHeight then
                error("the height resolution has been exceeded. maximum: " .. allowSetResolution.maxHeight, 2)
            end

            if allowSetResolution.maxPixels and (resX * resY) > allowSetResolution.maxPixels then
                error("the total maximum number of pixels has been exceeded. maximum: " .. allowSetResolution.maxPixels, 2)
            end
            
            if resX ~= dataTunnel.res_x or resY ~= dataTunnel.res_y then
                dataTunnel.res_x, dataTunnel.res_y = resX, resY
                dataTunnel.dataUpdated = true
                dataTunnel.resolutionChanged = true

                if pixelsCacheExists then
                    pixelsCache = {}
                    pixelsCacheExists = false
                end

                width, height = resX, resY
                if dataTunnel.rotation == 1 or dataTunnel.rotation == 3 then
                    rwidth = height
                    rheight = width
                else
                    rwidth = width
                    rheight = height
                end
                rmheight = rheight - 1
                rmwidth = rwidth - 1
            end
        end
    end

    api.update = api.flush
    api.getBuffer = api.get
    api.getCurrent = api.get
    api_flush = api.flush

    local internal = {
        rawPush = function(tbl)
            for i = 1, #tbl do
                stack[stackIndex] = tbl[i]
                stackIndex = stackIndex + 1
            end
        end,
        setForceFrame = setForceFrame
    }

    return api, internal
end

--adds a touch screen API (does not implement click processing)
function canvasAPI.addTouch(api, dataTunnel)
    dataTunnel = dataTunnel or {}
    dataTunnel.clicksAllowed = false
    dataTunnel.maxClicks = MAX_CLICKS
    dataTunnel.clickData = {}

    api.getClick = function ()
        return (table_remove(dataTunnel.clickData, 1))
    end

    api.setMaxClicks = function (c)
        if type(c) == "number" and c % 1 == 0 and c > 0 and c <= 16 then
            dataTunnel.maxClicks = c
        else
            error("integer must be in [1; 16]", 2)
        end
    end

    api.getMaxClicks = function ()
        return dataTunnel.maxClicks
    end

    api.clearClicks = function ()
        dataTunnel.clickData = {}
    end

    api.setClicksAllowed = function (c)
        if type(c) == "boolean" then
            if dataTunnel.clicksAllowed ~= c then
                dataTunnel.clicksAllowed = c
                dataTunnel.dataUpdated = true
            end
        else
            error("Type must be boolean", 2)
        end
    end

    api.getClicksAllowed = function ()
        return dataTunnel.clicksAllowed
    end

    return function (tbl)
        tbl.x = tbl[1] or tbl.x
        tbl.y = tbl[2] or tbl.y
        tbl.state = tbl[3] or tbl.state
        tbl.button = tbl[4] or tbl.button
        tbl.nickname = tbl[5] or tbl.nickname
        tbl[1] = tbl.x or tbl[1]
        tbl[2] = tbl.y or tbl[2]
        tbl[3] = tbl.state or tbl[3]
        tbl[4] = tbl.button or tbl[4]
        tbl[5] = tbl.nickname or tbl[5]
        if #dataTunnel.clickData < dataTunnel.maxClicks then
            table_insert(dataTunnel.clickData, tbl)
        end
    end
end

--leaves only those tunnel fields that are needed for transmission over the network
function canvasAPI.minimizeDataTunnel(dataTunnel)
    return {
        clicksAllowed = dataTunnel.clicksAllowed,
        rotation = dataTunnel.rotation,
        renderAtDistance = dataTunnel.renderAtDistance,
        skipAtNotSight = dataTunnel.skipAtNotSight,
        utf8support = dataTunnel.utf8support,
        customFont = dataTunnel.customFont,
        display_reset = dataTunnel.display_reset,
        optimizationLevel = dataTunnel.optimizationLevel,
        light = dataTunnel.light,
        material = dataTunnel.material,

        offset_x = dataTunnel.offset_x,
        offset_y = dataTunnel.offset_y,
        offset_z = dataTunnel.offset_z,

        rotation_x = dataTunnel.rotation_x,
        rotation_y = dataTunnel.rotation_y,
        rotation_z = dataTunnel.rotation_z,
        altRotation = dataTunnel.altRotation,

        scale_x = dataTunnel.scale_x,
        scale_y = dataTunnel.scale_y,

        res_x = dataTunnel.res_x,
        res_y = dataTunnel.res_y
    }
end

-------- additional
canvasAPI.stackChecksum = stackChecksum
canvasAPI.formatColor = formatColor
canvasAPI.formatColorToNumber = formatColorToNumber
canvasAPI.formatColorToSmallNumber = formatColorToSmallNumber
canvasAPI.checkFont = checkFont
canvasAPI.simpleRemathRect = simpleRemathRect
canvasAPI.remathRect = remathRect
canvasAPI.hexToRGB = hexToRGB
canvasAPI.hexToRGB256 = hexToRGB256
canvasAPI.posCheck = posCheck
canvasAPI.mathDist = mathDist
canvasAPI.needPushStack = needPushStack
canvasAPI.font = font
canvasAPI.tableClone = tableClone
canvasAPI.canvasService = canvasService
canvasAPI.userCalls = userCalls
canvasAPI.dataSizes = dataSizes
canvasAPI.color_new_fromSmallNumber = color_new_fromSmallNumber
canvasAPI.getEffectName = getEffectName
canvasAPI.fonts = fonts
canvasAPI.utf8 = utf8

function canvasAPI.pushData(stack, ...)
    for i, v in ipairs({...}) do
        table.insert(stack, v)
    end
end

_G.canvasAPI = canvasAPI