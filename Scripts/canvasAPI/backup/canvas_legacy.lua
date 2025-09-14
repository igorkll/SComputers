--[[
this file belongs to logic/bananaPen and was completely written by me alone(logic/bananaPen)
it was the most technically difficult project in my life O_o
writing a canvas for scrap mechanic that should work quickly turned out to be VERY DIFFICULT
]]

print("> canvas.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/luajit.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/font.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/fonts/fontsLoad.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/utf8.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/canvasService.lua")

local debugMode = true
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
        polyF = 11
    },
    material = {
        classic = sm.uuid.new("64d41b06-9b71-4e19-9f87-1e7e63845e59"),
        glass = sm.uuid.new("a683f897-5b8a-4c96-9c46-7b9fbc76d186")
    },
    multi_layer = {}
}
canvasAPI.multi_layer[tostring(canvasAPI.material.classic)] = true
canvasAPI.version = 30

canvasAPI.directList = {
    get = true,
    getCurrent = true,
    getBuffer = true,
    
    clear = true,
    drawPixel = true,
    drawRect = true,
    fillRect = true,
    drawText = true,
    drawLine = true,
    drawCircle = true,
    fillCircle = true,
    drawCircleEvenly = true,
    drawCircleVeryEvenly = true,
    drawPoly = true,
    drawWidePoly = true,
    fillPoly = true,
    fillWidePoly = true,
    getWidth = true,
    getHeight = true,
    getSize = true,

    isAllow = true,
    setFontScale = true,
    setFontSize = true,
    getFontScale = true,
    setTextSpacing = true,
    getTextSpacing = true,
    calcTextBox = true,
    calcCharsSize = true,
    calcDecreasingTextSizes = true,
    setUtf8Support = true,
    getUtf8Support = true,
    setRenderAtDistance = true,
    getRenderAtDistance = true,
    setRotation = true,
    getRotation = true,
    setFont = true,
    getFont = true,
    getFontWidth = true,
    getFontHeight = true,
    getRealFontWidth = true,
    getRealFontHeight = true,
    setSkipAtNotSight = true,
    getSkipAtNotSight = true,
    isMonospacedFont = true,
    setBrightness = true,
    getBrightness = true,
    reset = true,
    setClicksAllowed = true,
    getClicksAllowed = true,
    clearClicks = true,
    setMaxClicks = true,
    getMaxClicks = true,
    getClick = true,
    setOptimizationLevel = true,
    getOptimizationLevel = true,

    setViewport = true,
    setInlineViewport = true,
    getViewport = true
}

local MAX_DRAW_TIME = 2 --protecting the world from crashing using the display
local FONT_SIZE_LIMIT = 256
local DEFAULT_ALPHA_VALUE = 180

local fonts = fonts
local fontsOptimized = fontsOptimized
local spaceCharCode = string.byte(" ")

local huge = math.huge
local string_len = string.len
local bit = bit or bit32
local bit_rshift = bit.rshift
local bit_lshift = bit.lshift
local utf8 = utf8
local string = string
local table_sort = table.sort
local font = font
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

--[[
local sm_effect_createEffect = sm.effect.withoutHook_createEffect or sm.effect.createEffect
local emptyEffect = sm_effect_createEffect(getEffectName())
local withoutHookEmptyEffect = emptyEffect
local whook = "withoutHook_"
if better and better.version >= 24 and better.isAvailable() then
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
effect_destroy(emptyEffect)

local function round(number)
    return math_floor(number + 0.5)
end

local function checkFont(lfont)
	if type(lfont) ~= "table" then
		error("the font should be a table", 3)
    end

    if lfont.mono or lfont.mono == nil then
        if type(lfont.chars) ~= "table" or (type(lfont.width) ~= "number") or (type(lfont.height) ~= "number") then
            error("font failed integrity check", 3)
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
                if type(line) ~= "string" or #line ~= lfont.width then
                    error("font failed integrity check", 3)
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
    return band(rshift(color, 16), 0xFF) / 255, band(rshift(color, 8), 0xFF) / 255, band(color, 0xFF) / 255
end

local function hexToRGB256(color)
    return band(rshift(color, 16), 0xFF), band(rshift(color, 8), 0xFF), band(color, 0xFF)
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

local function needPushStack(canvas, dataTunnel, dt) --returns true if the rendering stack should be applied
    return dataTunnel.display_forceFlush or not ((dataTunnel.skipAtNotSight and not canvas.isRendering()))
end

local resetViewportCodeID = -23124
local dataSizes = {
    [resetViewportCodeID] = 1,
    [-1] = 5,
    [0] = 2,
    3,
    6,
    7,
    9, --text
    7, --line
    5,
    5,
    5,
    6,

    4, --drawPoly
    4 --fillPoly
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
    local fontWidth, fontHeight = font.width, font.height
    local rotation = 0
    local utf8Support = false
    local updated = false
    local clearOnly = false
    local maxLineSize = sizeX + sizeY
    local bigSide = math_max(sizeX, sizeY)
    local drawerData = {}
    local changes = {}
    local _changes = {}
    local changesIndex, changesCount = {}, 0

    local bufferChangedFrom = huge
    local bufferChangedTo = -huge

    local function bufferRangeUpdate(index)
        if index < bufferChangedFrom then bufferChangedFrom = index end
        if index > bufferChangedTo then bufferChangedTo = index end
    end

    local viewportEnable = false
    local brightnessEnable = false
    local brightness = 1
    local viewport_x, viewport_y, viewport_sx, viewport_sy

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

        if brightnessEnable then
            local r = math_floor(col / 256 / 256) % 256
            local g = math_floor(col / 256) % 256
            local b = col % 256
            col = (math_min(255, math_floor(r * brightness)) * 256 * 256) + (math_min(255, math_floor(g * brightness)) * 256) + math_min(255, math_floor(b * brightness))
        end

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

        if updatedList and not changes[index] then
            changes[index] = true
            changesCount = changesCount + 1
            changesIndex[changesCount] = index
        end

        if direct_set then
            newBuffer[index] = col
            direct_set(directArg, math_floor(index / rSizeY), index % rSizeY, col)
            return true
        elseif newBuffer[index] ~= col then
            bufferRangeUpdate(index)
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

    function obj.setSoftwareRotation(_rotation)
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

    function obj.setUtf8Support(state)
        utf8Support = not not state
    end

    function obj.setFont(customFont)
        if customFont then
            currentFont = customFont
            fontWidth, fontHeight = customFont.width, customFont.height
        else
            currentFont = font.optimized
            fontWidth, fontHeight = font.width, font.height
        end
    end

    local old_rotation
    local old_utf8support
    local old_customFont
    function obj.pushDataTunnelParams(params)
        brightness = params.brightness
        brightnessEnable = brightness ~= 1

        if params.rotation ~= old_rotation then
            obj.setSoftwareRotation(params.rotation)
            old_rotation = params.rotation
        end
        if params.utf8support ~= old_utf8support then
            obj.setUtf8Support(params.utf8support)
            old_utf8support = params.utf8support
        end
        if params.customFont ~= old_customFont then
            obj.setFont(params.customFont)
            old_customFont = params.customFont
        end
    end

    ------------------------------------------
    
    local function rasterize_fill(x, y, sx, sy, col)
        local x, y, x2, y2 = simpleRemathRect(x, y, sx, sy, maxX, maxY)
        if not x then return end
        for ix = x, x2 do
            for iy = y, y2 do
                setDot(ix, iy, col)
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
        local dx = math_abs(px2 - px)
        local dy = math_abs(py2 - py)
        local sx = (px < px2) and 1 or -1
        local sy = (py < py2) and 1 or -1
        local err = dx - dy
        local e2
        if width == -1 or width == 0 or width == 1 then
            for _ = 1, maxLineSize do
                checkSetDot(px, py, col)
                if px == px2 and py == py2 then
                    break
                end
                e2 = bit_lshift(err, 1)
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
                e2 = bit_lshift(err, 1)
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
                e2 = bit_lshift(err, 1)
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

    ------------------------------------------

    local function render_fill(stack, offset)
        local col = stack[offset+4]
        if direct_fill then
            direct_fill(directArg, stack[offset], stack[offset+1], stack[offset+2], stack[offset+3], col)
        else
            local x, y, x2, y2 = remathRect(offset, stack, maxX, maxY)
            if not x then return end
            --[[
            for ix = x, x2 do
                for iy = y, y2 do
                    setDot(ix, iy, col)
                end
            end
            ]]
            local ix, iy = x, y
            for _ = 1, ((y2 - y) + 1) * ((x2 - x) + 1) do
                setDot(ix, iy, col)
                iy = iy + 1
                if iy > y2 then
                    iy = y
                    ix = ix + 1
                end
            end
        end
    end

    local function render_rect(stack, offset)
        local x, y, x2, y2, w, h = remathRect(offset, stack, maxX, maxY)
        if not x then return end
        local col = stack[offset+4]
        local lineWidth = stack[offset+5]
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

    local function render_text(stack, offset)
        local tx, ty = stack[offset], stack[offset+1]
        local text = stack[offset+2]
        local col = stack[offset+3]
        local scaleX = stack[offset+4]
        local scaleY = stack[offset+5]
        local spacing = stack[offset+6]
        local fontIndex = stack[offset+7]
        local chrdata

        local localFont = currentFont
        local localFontWidth = fontWidth
        if fontIndex > 0 and fontsOptimized[fontIndex] then
            localFont = fontsOptimized[fontIndex]
            localFontWidth = localFont.width
        end

        local px, py
        local len, sep
        if utf8Support then
            len, sep = utf8_len, utf8_sub
        else
            len, sep = string_len, string_byte
        end
        local lposX, lposY
        local char, charOffset
        local setPosX
        local scaledFontWidth = math_ceil(localFontWidth * scaleX)
        if localFont.mono then
            for i = 1, len(text) do
                char = sep(text, i, i)
                if char ~= " " and char ~= spaceCharCode then
                    chrdata = localFont[char] or localFont.error or defaultError
                    charOffset = (i - 1) * (scaledFontWidth + spacing)
                    for i2 = 1, #chrdata, 2 do
                        px, py = chrdata[i2], chrdata[i2 + 1]
                        lposX, lposY = round(px * scaleX), round(py * scaleY)
                        for ix = 0, math_min(sizeX, round((px + 1) * scaleX) - lposX - 1) do
                            setPosX = tx + ix + lposX + charOffset
                            for iy = 0, math_min(sizeY, round((py + 1) * scaleY) - lposY - 1) do
                                checkSetDot(setPosX, ty + iy + lposY, col)
                            end
                        end
                    end
                end
            end
        else
            charOffset = 0
            local charPos
            local startDrawTime = os_clock()
            for i = 1, len(text) do
                char = sep(text, i, i)
                if char ~= " " and char ~= spaceCharCode then
                    chrdata = localFont[char] or localFont.error or defaultError
                    charPos = tx + charOffset
                    if not chrdata[0] or charPos + round(chrdata[0] * scaleX) > 0 then
                        if charPos > maxX then
                            goto endDraw
                        end
                        for i2 = 1, #chrdata, 2 do
                            px, py = chrdata[i2], chrdata[i2 + 1]
                            lposX, lposY = round(px * scaleX), round(py * scaleY)
                            for ix = 0, math_min(sizeX, round((px + 1) * scaleX) - lposX - 1) do
                                setPosX = tx + ix + lposX + charOffset
                                for iy = 0, math_min(sizeY, round((py + 1) * scaleY) - lposY - 1) do
                                    checkSetDot(setPosX, ty + iy + lposY, col)
                                end
                            end
                        end
                    end
                    charOffset = charOffset + (chrdata[0] and math_ceil(chrdata[0] * scaleX) or 0) + spacing
                else
                    charOffset = charOffset + (localFont.spaceSize or localFontWidth) + spacing
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

    local function render_drawPoly(stack, offset, linesInfo)
        local col = stack[offset]
        local points = stack[offset+1]
        local width = stack[offset+2]

        local startDrawTime = os_clock()
        local _px = stack[offset+3]
        local _py = stack[offset+4]
        local px, py
        for i = 3, points, 2 do
            px = stack[offset+2+i]
            py = stack[offset+3+i]
            rasterize_line(_px, _py, px, py, col, width, linesInfo)
            _px = px
            _py = py
            if os_clock() - startDrawTime > MAX_DRAW_TIME then
                goto endDraw
            end
        end
        rasterize_line(_px, _py, stack[offset+3], stack[offset+4], col, width, linesInfo)

        ::endDraw::
        return points
    end

    local function render_fillPoly(stack, offset)
        local linesInfo = {}
        local points = render_drawPoly(stack, offset, linesInfo)

        return points
    end

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
                else
                    bufferChangedFrom = 0
                    bufferChangedTo = maxBuffer
                end
                updated = true
            elseif actionNum == resetViewportCodeID then
                viewportEnable = false
            elseif actionNum == -1 then
                viewportEnable = true
                viewport_x = stack[offset]
                viewport_y = stack[offset+1]
                viewport_sx = stack[offset+2]
                viewport_sy = stack[offset+3]
            elseif actionNum == 1 then
                --[[
                local px, py, col = stack[offset], stack[offset+1], stack[offset+2]
                if px >= 0 and py >= 0 and px < sizeX and py < sizeY then
                    local index
                    if rotation == 0 then
                        index = (py + (px * rSizeY)) + 1
                    elseif rotation == 1 then
                        index = ((rSizeY - px - 1) + (py * rSizeY)) + 1
                    elseif rotation == 2 then
                        index = ((rSizeY - py - 1) + ((rSizeX - px - 1) * rSizeY)) + 1
                    else
                        index = (px + ((rSizeX - py - 1) * rSizeY)) + 1
                    end

                    if newBuffer[index] ~= col then
                        if index < bufferChangedFrom then bufferChangedFrom = index end
                        if index > bufferChangedTo then bufferChangedTo = index end
                        newBuffer[index] = col
                        updated = true
                    end
                end
                ]]
                idx = stack[offset]
                setDot(idx % rSizeX, math_floor(idx / rSizeX), stack[offset+1])
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
            elseif userCalls[actionNum] then
                --if sm.sc_g.freezeDetector("userCalls", userCalls[actionNum], newBuffer, rotation, rSizeX, rSizeY, sizeX, sizeY, stack, offset, drawerData, bufferRangeUpdate) then
                if userCalls[actionNum](newBuffer, rotation, rSizeX, rSizeY, sizeX, sizeY, stack, offset, drawerData, bufferRangeUpdate, setDot, checkSetDot) then
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
            if force then
                bufferChangedFrom = 0
                bufferChangedTo = maxBuffer
            end
            if callbackBefore then
                if callbackBefore(newBufferBase, clearOnly, maxBuffer, force, newBuffer, realBuffer, bufferChangedFrom, bufferChangedTo, changes, changesIndex, changesCount, _changes) then
                    realBuffer = {}
                end
            end
            if callback then
                --[[
                local color
                local nextCount = 0
                local px, py = 0, 0
                local i = 1
                local li = 0
                local m
                while i <= maxBuffer do
                    color = newBuffer[i] or newBufferBase
                    if color ~= realBuffer[i] or force then
                        px = (i - 1) % rSizeX
                        py = math_floor((i - 1) / rSizeX)
                        nextCount = rSizeX
                        for i2 = 1, rSizeX - 1 do
                            m = i + i2
                            if (m - 1) % rSizeX == 0 or (newBuffer[m] or newBufferBase) ~= color then
                                nextCount = i2
                                break
                            end
                        end
                        li = 0
                        while nextCount > 0 do
                            if callback(px + li, py, color, newBufferBase, nextCount) then
                                while nextCount > 0 do
                                    realBuffer[i] = color
                                    i = i + 1
                                    nextCount = nextCount - 1
                                end
                                break
                            end
                            nextCount = nextCount - 1
                            realBuffer[i] = color
                            li = li + 1
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
                ]]
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
            end
            bufferChangedFrom = huge
            bufferChangedTo = -huge
            updated = false
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

    function obj.flushOldChanges()
        _changes = changes
    end

    return obj
end

if better and better.isAvailable() and better.canvas and better.version >= 40 then
    local better_canvas_clear = better.canvas.clear
    local better_canvas_fill = better.canvas.fill
    local better_canvas_set = better.canvas.set

    function canvasAPI.createBetterCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation)
        local hiddenOffset = vec3_new(1000000, 1000000, 1000000)
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

        local function getSelfPos()
            local pt = type(parent)
            if pt == "Interactable" then
                return parent.shape.worldPosition
            elseif pt == "Character" then
                return parent.worldPosition
            end
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
function canvasAPI.createCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation, material, scaleAddValue)
    local hiddenOffset = vec3_new(1000000, 1000000, 1000000)
    local obj = {sizeX = sizeX, sizeY = sizeY}
    local maxX, maxY = sizeX - 1, sizeY - 1
    local maxEffectArrayBuffer = maxX + (maxY * sizeX)
    local dist
    local needOptimize = false
    local showState = false
    local disable = false
    local colorCache = {}

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

    local effects = {}
    local nodeEffects = {}
    local bufferedEffects = {}
    local bufferedEffectsIndex = 0
    local lastDrawTickTime
    local optimizationLevel = 16
    local alpha = DEFAULT_ALPHA_VALUE

    local function setEffectDataParams(effectData)
        local effect, posX, posY, lSizeX, lSizeY = effectData[1], effectData[3], effectData[4], effectData[5], effectData[6]

        posX = posX + ((lSizeX - 1) * 0.5)
        posY = posY + ((lSizeY - 1) * 0.5)
        effect_setOffsetPosition(effect, rotation * (offset + vec3_new(((posX + 0.5) - (sizeX / 2)) * pixelSize.x, ((posY + 0.5) - (sizeY / 2)) * -pixelSize.y, backplate and (debugMode and 0.05 or 0.001) or 0)))

        local localScaleAddValue = debugMode and -(pixelSize.x / 2) or scaleAddValue
        local vec = pixelSize * 1
        vec.x = (pixelSize.x * lSizeX) + localScaleAddValue
        vec.y = (pixelSize.y * lSizeY) + localScaleAddValue
        effect_setScale(effect, vec)
    end

    local function createEffect()
        --[[
        local endX = x + (sizeX - 1)
        if endX > maxX then
            print(x, y, sizeX, sizeY, tostring(color_new_fromSmallNumber(color)))
            error("outside effect create")
        end
        ]]

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
            effect_setOffsetRotation(effect, rotation)
        end
        return effect
    end

    local function clearBufferedEffects()
        for i = 1, bufferedEffectsIndex do
            effect_destroy(bufferedEffects[i])
        end
        bufferedEffects = {}
        bufferedEffectsIndex = 0
    end

    local lastNewBuffer, lastBase

    local lastPopularColorTick, lastPopularColor
    local lastPopularColorUpdatePerTick = (sizeX * sizeY) / 256
    local function mathPopularColor()
        local oldLastPopularColor = lastPopularColor

        local colorUsesTable = {}
        local colorUses = 0
        local oldColorUses = 0
        local colorSum = 0
        for _, effectData in pairs(nodeEffects) do
            local color = effectData[2]
            local colorSize = effectData[5] * effectData[6]
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
            colorSum = colorSum + colorSize
            colorUses = colorUsesTable[oldBackplateColor]
            if colorUses > oldColorUses then
                oldColorUses = colorUses
                lastPopularColor = oldBackplateColor
            end
        end

        if oldLastPopularColor and colorUses < 32 then
            lastPopularColor = oldLastPopularColor
        else
            lastPopularColorTick = sm.game.getCurrentTick()
        end
    end

    local function effectIndexAtPos(px, py)
        return py + (px * sizeY)
    end

    local function getEffectDataAtPos(px, py)
        if py < 0 or py >= sizeY then return end
        return effects[effectIndexAtPos(px, py)]
    end

    local function clearEffectFromBuffer(effectData)
        local six, ix, iy = effectData[3], effectData[3], effectData[4]
        local sizeX, sizeY = effectData[5], effectData[6]
        nodeEffects[effectData[7]] = nil
        for _ = 1, sizeX * sizeY do
            effects[effectIndexAtPos(ix, iy)] = nil
            ix = ix + 1
            if ix >= six + sizeX then
                ix = six
                iy = iy + 1
            end
        end
    end

    local function hideEffect(effect, hideList)
        bufferedEffectsIndex = bufferedEffectsIndex + 1
        bufferedEffects[bufferedEffectsIndex] = effect
        if hideList then
            hideList[effect.id] = effect
        else
            effect_setOffsetPosition(effect, hiddenOffset)
        end
    end

    local function hideEffectData(effectData, hideList)
        hideEffect(effectData[1], hideList)
        clearEffectFromBuffer(effectData)
    end

    local function hideEffectsWithColor(color)
        for i, effectData in pairs(nodeEffects) do
            if effectData[2] == color then
                hideEffectData(effectData)
            end
        end
    end

    local function delAllEffects()
        for _, effectData in pairs(nodeEffects) do
            effect_destroy(effectData[1])
        end
        effects = {}
        nodeEffects = {}
    end

    local function extractVerticleLine(changedList, changedColorList, index, px, py, saveExtractionPixel)
        local effectData = effects[index]
        local lx = px - effectData[3]
        local rpx, rpy = effectData[3], effectData[4]
        if lx == 0 then --extract first line
            if saveExtractionPixel then
                local newEffectData = {
                    createEffect(),
                    effectData[2],
                    rpx,
                    rpy,
                    1,
                    effectData[6],
                    effectData[7]
                }
                for i = 0, newEffectData[6] - 1 do
                    effects[newEffectData[7] + i] = newEffectData
                end
                nodeEffects[newEffectData[7]] = newEffectData
                changedList[newEffectData] = true
                changedColorList[newEffectData[1]] = newEffectData
            else
                for i = 0, effectData[6] - 1 do
                    effects[effectData[7] + i] = nil
                end
                nodeEffects[effectData[7]] = nil
            end

            effectData[7] = effectData[7] + sizeY
            nodeEffects[effectData[7]] = effectData
            effectData[3] = effectData[3] + 1
            effectData[5] = effectData[5] - 1
            changedList[effectData] = true
        elseif lx == effectData[5] - 1 then --extract last line
            local rootIndex = effectIndexAtPos(px, rpy)
            if saveExtractionPixel then
                local newEffectData = {
                    createEffect(),
                    effectData[2],
                    px,
                    rpy,
                    1,
                    effectData[6],
                    rootIndex
                }
                nodeEffects[rootIndex] = newEffectData
                for i = 0, newEffectData[6] - 1 do
                    effects[rootIndex + i] = newEffectData
                end
                changedList[newEffectData] = true
                changedColorList[newEffectData[1]] = newEffectData
            else
                for i = 0, effectData[6] - 1 do
                    effects[rootIndex + i] = nil
                end
            end

            effectData[5] = effectData[5] - 1
            changedList[effectData] = true
        else --extract center line
            local endPartIndex = px + 1
            local newEffectData = { --end part
                createEffect(),
                effectData[2],
                endPartIndex,
                rpy,
                effectData[5] - lx - 1,
                effectData[6],
                effectIndexAtPos(endPartIndex, rpy)
            }
            nodeEffects[newEffectData[7]] = newEffectData
            local ix, iy = 0, 0
            local sizeX, sizeY = newEffectData[5], newEffectData[6]
            for _ = 1, sizeX * sizeY do
                effects[effectIndexAtPos(endPartIndex + ix, rpy + iy)] = newEffectData
                ix = ix + 1
                if ix >= sizeX then
                    ix = 0
                    iy = iy + 1
                end
            end
            --[[
            for iy = 0, newEffectData[6] - 1 do
                for i = 0, newEffectData[5] - 1 do
                    effects[effectIndexAtPos(endPartIndex + i, rpy + iy)] = newEffectData
                end
            end
            ]]
            changedList[newEffectData] = true
            changedColorList[newEffectData[1]] = newEffectData

            effectData[5] = lx --first part
            changedList[effectData] = true

            local rootIndex = effectIndexAtPos(px, rpy)
            if saveExtractionPixel then
                newEffectData = { --center part
                    createEffect(),
                    effectData[2],
                    px,
                    rpy,
                    1,
                    effectData[6],
                    rootIndex
                }
                nodeEffects[rootIndex] = newEffectData
                for i = 0, newEffectData[6] - 1 do
                    effects[rootIndex + i] = newEffectData
                end
                changedList[newEffectData] = true
                changedColorList[newEffectData[1]] = newEffectData
            else
                for i = 0, effectData[6] - 1 do
                    effects[rootIndex + i] = nil
                end
            end
        end
    end

    local function extractVerticlePixel(changedList, changedColorList, index, px, py, saveExtractionPixel)
        local effectData = effects[index]
        local ly = py - effectData[4]
        if ly == 0 then --extract first pixel
            if saveExtractionPixel then
                local newEffectData = {
                    createEffect(),
                    nil,
                    px,
                    py,
                    1,
                    1,
                    effectData[7]
                }
                effects[newEffectData[7]] = newEffectData
                nodeEffects[newEffectData[7]] = newEffectData
                changedList[newEffectData] = true
            else
                effects[effectData[7]] = nil
                nodeEffects[effectData[7]] = nil
            end

            effectData[7] = effectData[7] + 1
            effectData[4] = effectData[4] + 1
            effectData[6] = effectData[6] - 1
            nodeEffects[effectData[7]] = effectData
            changedList[effectData] = true
        elseif ly == effectData[6] - 1 then --extract last pixel
            local rootIndex = effectData[7] + ly
            if saveExtractionPixel then
                local newEffectData = {
                    createEffect(),
                    nil,
                    px,
                    py,
                    1,
                    1,
                    rootIndex
                }
                effects[rootIndex] = newEffectData
                nodeEffects[rootIndex] = newEffectData
                changedList[newEffectData] = true
            else
                effects[rootIndex] = nil
                nodeEffects[rootIndex] = nil
            end

            effectData[6] = effectData[6] - 1
            changedList[effectData] = true
        else --extract center pixel
            local newEffectData = { --end part
                createEffect(),
                effectData[2],
                px,
                py + 1,
                1,
                effectData[6] - ly - 1,
                effectIndexAtPos(px, py + 1)
            }
            nodeEffects[newEffectData[7]] = newEffectData
            for i = 1, newEffectData[6] do
                effects[effectData[7] + ly + i] = newEffectData
            end
            changedList[newEffectData] = true
            changedColorList[newEffectData[1]] = newEffectData

            effectData[6] = ly --first part
            changedList[effectData] = true

            local rootIndex = effectData[7] + ly
            if saveExtractionPixel then
                newEffectData = { --center part
                    createEffect(),
                    nil,
                    px,
                    py,
                    1,
                    1,
                    rootIndex
                }
                effects[rootIndex] = newEffectData
                nodeEffects[rootIndex] = newEffectData
                changedList[newEffectData] = true
            else
                effects[rootIndex] = nil
                nodeEffects[rootIndex] = nil
            end
        end
    end

    local function colorEquals_smart(color1, color2)
        local rVal, gVal, bVal = hexToRGB256(color1)
        local rVal2, gVal2, bVal2 = hexToRGB256(color2)
        local rDelta = math_abs(rVal - rVal2)
        local gDelta = math_abs(gVal - gVal2)
        local bDelta = math_abs(bVal - bVal2)
        return rDelta + gDelta + bDelta <= optimizationLevel
    end

    local colorEquals = colorEquals_smart

    local function colorEquals_raw(color1, color2)
        return color1 == color2
    end

    local function tryAttach(changedList, index, px, py, color, hideList)
        --[[
        local origEffectData = effects[index]
        local rpx, rpy = px, py
        local currentSizeX = 1
        local currentSizeY = 1
        if origEffectData then
            index = origEffectData[7]
            rpx, rpy = origEffectData[3], origEffectData[4]
            currentSizeX = origEffectData[5]
            currentSizeY = origEffectData[6]
        end
        
        local upParent = getEffectDataAtPos(rpx, rpy - 1)
        local downParent = getEffectDataAtPos(rpx, rpy + currentSizeY)
        local upAvailable = upParent and upParent[3] == rpx and upParent[5] == currentSizeX and colorEquals(upParent[2], color)
        local downAvailable = downParent and downParent[3] == rpx and downParent[5] == currentSizeX and colorEquals(downParent[2], color)
        local fillObj
        if upAvailable and downAvailable then
            --[[
            for ix = 0, currentSizeX - 1 do
                for i = 0, downParent[6] - 1 do
                    effects[downParent[7] + i + (ix * sizeY)] = upParent
                end
            end
            ] ]
            local ix1, iy1 = 0, 0
            local ix2, iy2 = currentSizeX - 1, downParent[6] - 1
            local ix, iy = ix1, iy1
            for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                effects[downParent[7] + iy + (ix * sizeY)] = upParent
                ix = ix + 1
                if ix > ix2 then
                    ix = ix1
                    iy = iy + 1
                end
            end

            upParent[6] = upParent[6] + currentSizeY + downParent[6]
            fillObj = upParent
            changedList[upParent] = true

            changedList[downParent] = nil
            hideEffect(downParent[1])
        elseif upAvailable then
            upParent[6] = upParent[6] + currentSizeY
            fillObj = upParent

            changedList[upParent] = true
        elseif downAvailable then
            downParent[6] = downParent[6] + currentSizeY
            downParent[7] = downParent[7] - currentSizeY
            downParent[4] = downParent[4] - currentSizeY
            fillObj = downParent

            changedList[downParent] = true
        end

        if fillObj then
            if origEffectData then
                changedList[origEffectData] = nil
                hideEffect(origEffectData[1])
            end

            --[[
            for ix = 0, currentSizeX - 1 do
                for i = index, index + (currentSizeY - 1) do
                    effects[i + (ix * sizeY)] = fillObj
                end
            end
            ] ]
            local ix1, iy1 = 0, index
            local ix2, iy2 = currentSizeX - 1, index + (currentSizeY - 1)
            local ix, iy = ix1, iy1
            for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                effects[iy + (ix * sizeY)] = fillObj
                ix = ix + 1
                if ix > ix2 then
                    ix = ix1
                    iy = iy + 1
                end
            end

            index = fillObj[7]
            rpx, rpy = fillObj[3], fillObj[4]
            currentSizeX = fillObj[5]
            currentSizeY = fillObj[6]
        end

        local leftParent = getEffectDataAtPos(rpx - 1, rpy)
        local rightParent = getEffectDataAtPos(rpx + currentSizeX, rpy)
        local leftAvailable = leftParent and leftParent[4] == rpy and leftParent[6] == currentSizeY and colorEquals(leftParent[2], color)
        local rightAvailable = rightParent and rightParent[4] == rpy and rightParent[6] == currentSizeY and colorEquals(rightParent[2], color)
        local fillObj2

        if leftAvailable and rightAvailable then
            local ix1, iy1 = 0, 0
            local ix2, iy2 = rightParent[5] - 1, rightParent[6] - 1
            local ix, iy = ix1, iy1
            for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                effects[rightParent[7] + iy + (ix * sizeY)] = leftParent
                ix = ix + 1
                if ix > ix2 then
                    ix = ix1
                    iy = iy + 1
                end
            end

            leftParent[5] = leftParent[5] + currentSizeX + rightParent[5]
            fillObj2 = leftParent
            changedList[leftParent] = true

            changedList[rightParent] = nil
            hideEffect(rightParent[1])
        elseif leftAvailable then
            leftParent[5] = leftParent[5] + currentSizeX
            fillObj2 = leftParent

            changedList[leftParent] = true
        elseif rightAvailable then
            rightParent[5] = rightParent[5] + currentSizeX
            rightParent[3] = rightParent[3] - currentSizeX
            rightParent[7] = effectIndexAtPos(rightParent[3], rightParent[4])
            fillObj2 = rightParent

            changedList[rightParent] = true
        end

        if fillObj2 then
            origEffectData = effects[index]
            if origEffectData then
                changedList[origEffectData] = nil
                hideEffect(origEffectData[1])
            end

            --[[
            for ix = 0, currentSizeX - 1 do
                for i = index, index + (currentSizeY - 1) do
                    effects[i + (ix * sizeY)] = fillObj2
                end
            end
            ] ]

            local ix1, iy1 = 0, index
            local ix2, iy2 = currentSizeX - 1, index + (currentSizeY - 1)
            local ix, iy = ix1, iy1
            for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                effects[iy + (ix * sizeY)] = fillObj2
                ix = ix + 1
                if ix > ix2 then
                    ix = ix1
                    iy = iy + 1
                end
            end
        end

        return fillObj or fillObj2
        ]]

        --[[
        local origEffectData = effects[index]
        if origEffectData then
            px, py, index = origEffectData[3], origEffectData[4], attached[7]
            local upParent = getEffectDataAtPos(px, py - 1)
            local downParent = getEffectDataAtPos(px, py + origEffectData[6])
            local upAvailable = upParent and upParent[3] == px and upParent[5] == origEffectData[5] and colorEquals(upParent[2], origEffectData[2])
            local downAvailable = downParent and downParent[3] == px and downParent[5] == origEffectData[5] and colorEquals(downParent[2], origEffectData[2])

            if upAvailable and downAvailable and false then
                
            elseif upAvailable then
                hideEffect(upParent[1])
                changedList[upParent] = nil
                
                upParent[6] = upParent[6] + 1
            elseif downAvailable and false then
                
            end
        else
        ]]

        --[[
        local attached
        local origEffectData = effects[index]
        if origEffectData then --bug
            px, py, index = origEffectData[3], origEffectData[4], origEffectData[7] 
            local vSize = origEffectData[6]
            
            local upParent = getEffectDataAtPos(px, py - 1)
            local downParent = getEffectDataAtPos(px, py + vSize)
            local upAvailable = upParent and upParent[3] == px and upParent[5] == origEffectData[5] and colorEquals(upParent[2], color)
            local downAvailable = downParent and downParent[3] == px and downParent[5] == origEffectData[5] and colorEquals(downParent[2], color)
            
            local currentEffect = origEffectData
            if upAvailable and downAvailable then
                hideEffect(origEffectData[1], hideList)
                changedList[origEffectData] = nil
                nodeEffects[downParent[7] ] = nil

                upParent[6] = upParent[6] + vSize + downParent[6]
                changedList[upParent] = true

                local ix1, iy1 = px, py
                local ix2, iy2 = px + (origEffectData[5] - 1), py + ((vSize + downParent[6]) - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = upParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                hideEffect(downParent[1], hideList)
                changedList[downParent] = nil
                attached = true
                currentEffect = upParent
            elseif upAvailable then
                hideEffect(origEffectData[1], hideList)
                changedList[origEffectData] = nil

                upParent[6] = upParent[6] + vSize
                local ix1, iy1 = px, py
                local ix2, iy2 = px + (origEffectData[5] - 1), py + (vSize - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = upParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                changedList[upParent] = true
                attached = true
                currentEffect = upParent
            elseif downAvailable then
                hideEffect(origEffectData[1], hideList)
                changedList[origEffectData] = nil

                nodeEffects[downParent[7] ] = nil
                downParent[7] = index
                downParent[4] = downParent[4] - vSize
                downParent[6] = downParent[6] + vSize
                local ix1, iy1 = px, py
                local ix2, iy2 = px + (origEffectData[5] - 1), py + (vSize - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = downParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                nodeEffects[index] = downParent
                changedList[downParent] = true
                attached = true
                currentEffect = downParent
            end

            px, py, index = currentEffect[3], currentEffect[4], currentEffect[7]
            vSize = currentEffect[6]
            local hSize = currentEffect[5]

            local leftParent = getEffectDataAtPos(px - 1, py)
            local rightParent = getEffectDataAtPos(px + hSize, py)
            local leftAvailable = leftParent and leftParent[4] == py and leftParent[6] == vSize and colorEquals(leftParent[2], color)
            local rightAvailable = rightParent and rightParent[4] == py and rightParent[6] == vSize and colorEquals(rightParent[2], color)

            if leftAvailable and rightAvailable then
                hideEffect(currentEffect[1], hideList)
                changedList[currentEffect] = nil
                nodeEffects[rightParent[7] ] = nil

                leftParent[5] = leftParent[5] + hSize + rightParent[5]
                changedList[leftParent] = true

                local ix1, iy1 = px, py
                local ix2, iy2 = px + ((hSize + rightParent[5]) - 1), py + (vSize - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = leftParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                hideEffect(rightParent[1], hideList)
                changedList[rightParent] = nil
            elseif leftAvailable then
                hideEffect(currentEffect[1], hideList)
                changedList[currentEffect] = nil

                leftParent[5] = leftParent[5] + hSize
                local ix1, iy1 = px, py
                local ix2, iy2 = px + (hSize - 1), py + (vSize - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = leftParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                changedList[leftParent] = true
            elseif rightAvailable then
                hideEffect(currentEffect[1], hideList)
                changedList[currentEffect] = nil

                nodeEffects[rightParent[7] ] = nil
                rightParent[7] = index
                rightParent[3] = px
                rightParent[5] = rightParent[5] + hSize
                local ix1, iy1 = px, py
                local ix2, iy2 = px + (hSize - 1), py + (vSize - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = rightParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                nodeEffects[index] = rightParent
                changedList[rightParent] = true
            end

            return attached
        end

        local upParent = getEffectDataAtPos(px, py - 1)
        local downParent = getEffectDataAtPos(px, py + 1)
        local upAvailable = upParent and upParent[3] == px and upParent[5] == 1 and colorEquals(upParent[2], color)
        local downAvailable = downParent and downParent[3] == px and downParent[5] == 1 and colorEquals(downParent[2], color)

        if upAvailable and downAvailable then
            nodeEffects[downParent[7] ] = nil

            upParent[6] = upParent[6] + 1 + downParent[6]
            effects[index] = upParent
            changedList[upParent] = true

            for i = downParent[7], downParent[7] + (downParent[6] - 1) do
                effects[i] = upParent
            end
            hideEffect(downParent[1])
            changedList[downParent] = nil
            attached = upParent
        elseif upAvailable then
            upParent[6] = upParent[6] + 1
            effects[index] = upParent
            changedList[upParent] = true
            attached = upParent
        elseif downAvailable then
            nodeEffects[downParent[7] ] = nil
            downParent[7] = index
            downParent[4] = downParent[4] - 1
            downParent[6] = downParent[6] + 1
            effects[index] = downParent
            nodeEffects[index] = downParent
            changedList[downParent] = true
            attached = downParent
        end

        if attached then
            px, py, index = attached[3], attached[4], attached[7]
            local verticleSize = attached[6]

            local leftParent = getEffectDataAtPos(px - 1, py)
            local rightParent = getEffectDataAtPos(px + 1, py)
            local leftAvailable = leftParent and leftParent[4] == py and leftParent[6] == verticleSize and colorEquals(leftParent[2], color)
            local rightAvailable = rightParent and rightParent[4] == py and rightParent[6] == verticleSize and colorEquals(rightParent[2], color)

            if leftAvailable and rightAvailable then --bug
                nodeEffects[rightParent[7] ] = nil

                hideEffect(attached[1])
                changedList[attached] = nil

                leftParent[5] = leftParent[5] + 1 + rightParent[5]
                changedList[leftParent] = true

                local ix1, iy1 = rightParent[3] - 1, py
                local ix2, iy2 = rightParent[3] + (rightParent[5] - 1), py + (verticleSize - 1)
                local ix, iy = ix1, iy1
                for _ = 1, ((ix2 - ix1) + 1) * ((iy2 - iy1) + 1) do
                    effects[effectIndexAtPos(ix, iy)] = leftParent
                    ix = ix + 1
                    if ix > ix2 then
                        ix = ix1
                        iy = iy + 1
                    end
                end
                hideEffect(rightParent[1])
                changedList[rightParent] = nil
            elseif leftAvailable then
                hideEffect(attached[1])
                changedList[attached] = nil

                nodeEffects[index] = nil
                leftParent[5] = leftParent[5] + 1
                changedList[leftParent] = true
                for i = py, py + (verticleSize - 1) do
                    effects[effectIndexAtPos(px, i)] = leftParent
                end
            elseif rightAvailable then
                hideEffect(attached[1])
                changedList[attached] = nil

                nodeEffects[rightParent[7] ] = nil
                rightParent[7] = index
                rightParent[3] = rightParent[3] - 1
                rightParent[5] = rightParent[5] + 1
                nodeEffects[index] = rightParent
                for i = py, py + (verticleSize - 1) do
                    effects[effectIndexAtPos(px, i)] = rightParent
                end
                changedList[rightParent] = true
            end
        else
            local leftParent = getEffectDataAtPos(px - 1, py)
            local rightParent = getEffectDataAtPos(px + 1, py)
            local leftAvailable = leftParent and leftParent[4] == py and leftParent[6] == 1 and colorEquals(leftParent[2], color)
            local rightAvailable = rightParent and rightParent[4] == py and rightParent[6] == 1 and colorEquals(rightParent[2], color)

            if leftAvailable and rightAvailable then
                nodeEffects[rightParent[7] ] = nil

                leftParent[5] = leftParent[5] + 1 + rightParent[5]
                effects[index] = leftParent
                changedList[leftParent] = true

                for i = rightParent[3], rightParent[3] + (rightParent[5] - 1) do
                    effects[effectIndexAtPos(i, py)] = leftParent
                end
                hideEffect(rightParent[1])
                changedList[rightParent] = nil
                attached = true
            elseif leftAvailable then
                nodeEffects[index] = nil
                leftParent[5] = leftParent[5] + 1
                effects[index] = leftParent
                changedList[leftParent] = true
                attached = true
            elseif rightAvailable then
                nodeEffects[rightParent[7] ] = nil
                rightParent[7] = index
                rightParent[3] = rightParent[3] - 1
                rightParent[5] = rightParent[5] + 1
                effects[index] = rightParent
                nodeEffects[index] = rightParent
                changedList[rightParent] = true
                attached = true
            end
        end

        return attached
        ]]

        local attached

        local origEffectData = effects[index]
        local sizeX, sizeY = 1, 1
        if origEffectData then
            index, px, py = origEffectData[7], origEffectData[3], origEffectData[4]
            sizeX, sizeY = origEffectData[5], origEffectData[6]
        end

        local fillX1, fillX2, fillY1, fillY2 = px, px, py, py
        local function updateFillbox(x, y)
            if x < fillX1 then
                fillX1 = x
            elseif x > fillX2 then
                fillX2 = x
            end

            if y < fillY1 then
                fillY1 = y
            elseif y > fillY2 then
                fillY2 = y
            end
        end

        local upParent = getEffectDataAtPos(px, py - 1)
        local downParent = getEffectDataAtPos(px, py + sizeY)
        local upAvailable = upParent and upParent[3] == px and upParent[5] == sizeX and colorEquals(upParent[2], color)
        local downAvailable = downParent and downParent[3] == px and downParent[5] == sizeX and colorEquals(downParent[2], color)

        if upAvailable and downAvailable and false then
            nodeEffects[downParent[7]] = nil
            hideEffect(downParent[1], hideList)
            changedList[downParent] = nil

            upParent[6] = upParent[6] + sizeY + downParent[6]
            updateFillbox(px + (sizeX - 1), py + ((sizeY + downParent[6]) - 1))
            attached = upParent
        elseif upAvailable and false then
            upParent[6] = upParent[6] + sizeY
            updateFillbox(px + (sizeX - 1), py + (sizeY - 1))
            attached = upParent
        elseif downAvailable and false then
            nodeEffects[downParent[7]] = nil
            downParent[7] = index
            downParent[4] = py
            downParent[6] = downParent[6] + sizeY
            updateFillbox(px + (sizeX - 1), py + (sizeY - 1))
            nodeEffects[index] = downParent
            attached = downParent
        end

        if attached then
            index, px, py = attached[7], attached[3], attached[4]
            sizeX, sizeY = attached[5], attached[6]
        end

        local leftParent = getEffectDataAtPos(px - 1, py)
        local rightParent = getEffectDataAtPos(px + sizeX, py)
        local leftAvailable = leftParent and leftParent[4] == py and leftParent[6] == sizeY and colorEquals(leftParent[2], color)
        local rightAvailable = rightParent and rightParent[4] == py and rightParent[6] == sizeY and colorEquals(rightParent[2], color)
        
        if leftAvailable and false then
            if attached then
                hideEffect(attached[1], hideList)
                changedList[attached] = nil
            end
            leftParent[5] = leftParent[5] + sizeX
            updateFillbox(px, py)
            updateFillbox(px + (sizeX - 1), py + (sizeY - 1))
            attached = leftParent
        elseif rightAvailable and false then
            if attached then
                hideEffect(attached[1], hideList)
                changedList[attached] = nil
            end
            rightParent[3] = rightParent[3] - sizeX
            rightParent[5] = rightParent[5] + sizeX
            updateFillbox(px, py)
            updateFillbox(px + (sizeX - 1), py + (sizeY - 1))
            attached = rightParent
        end

        if attached then
            changedList[attached] = true
            local ix, iy = fillX1, fillY1
            for _ = 1, ((fillX2 - fillX1) + 1) * ((fillY2 - fillY1) + 1) do
                effects[effectIndexAtPos(ix, iy)] = attached
                ix = ix + 1
                if ix > fillX2 then
                    ix = fillX1
                    iy = iy + 1
                end
            end
            if origEffectData then
                hideEffect(origEffectData[1], hideList)
                changedList[origEffectData] = nil
            end
        end

        return attached
    end

    local function fillEmptySpace(color)
        local px, py, effect, effectData
        local changedList = {}
        local changedColorList = {}
        
        for i = 0, maxEffectArrayBuffer do
            px = math_floor(i / sizeY)
            py = i % sizeY
            if not effects[i] and not tryAttach(changedList, i, px, py, color) then
                effect = createEffect()
                effectData = {
                    effect,
                    color,
                    px, --3. root pos x
                    py, --4. root pos Y
                    1,  --5. sizeX
                    1,  --6. sizeY
                    i   --7. root index
                }
                effects[i] = effectData
                changedList[effectData] = true
                changedColorList[effect] = effectData
            end
        end

        for effectData in pairs(changedList) do
            setEffectDataParams(effectData)
        end

        local color
        for _, effectData in pairs(changedColorList) do
            color = effectData[2]
            if not colorCache[color] then
                colorCache[color] = color_new_fromSmallNumber(color, alpha)
            end
            effect_setParameter(effectData[1], "color", colorCache[color])
        end
    end

    --[[
    local function checkNodeEffects()
        --[[
        for i, effectData in pairs(nodeEffects) do
            if effectData[7] ~= effectIndexAtPos(effectData[3], effectData[4]) then
                print(effectData)
                error("WTF 6")
            end
        end

        for i, effectData in pairs(effects) do
            if effectData[7] == i then
                if not nodeEffects[i] then
                    error("WTF 0")
                end

                if nodeEffects[i][7] ~= i then
                    error("WTF 1")
                end
            end
        end

        for i, effectData in pairs(nodeEffects) do
            if not effects[i] then
                print(effectData)
                error("WTF 3")
            end
        end

        for i, effectData in pairs(nodeEffects) do
            if effectData[7] ~= i then
                print(effectData)
                error("WTF 4")
            end
        end

        local exists = {}
        for i, effectData in pairs(nodeEffects) do
            if exists[effectData[1].id] then
                print(i, effectData, exists[effectData[1].id])
                error("WTF 5")
            end
            exists[effectData[1].id] = {i, effectData}
        end
        ] ]

        nodeEffects = {}
        for i, effectData in pairs(effects) do
            if effectData[7] == i then
                nodeEffects[i] = effectData
            end
        end
    end
    ]]

    --[[
    local showedNodeEffects = {}
    local function showNodeEffects()
        for _, effect in pairs(showedNodeEffects) do
            hideEffect(effect)
        end
        showedNodeEffects = {}
        for i, effectData in pairs(nodeEffects) do
            showedNodeEffects[i] = createEffect()
            local effectData = {
                showedNodeEffects[i],
                nil,
                effectData[3], --3. root pos x
                effectData[4], --4. root pos Y
                1,  --5. sizeX
                1,  --6. sizeY
                i   --7. root index
            }
            local effect, posX, posY, lSizeX, lSizeY = effectData[1], effectData[3], effectData[4], effectData[5], effectData[6]
            posX = posX + ((lSizeX - 1) * 0.5)
            posY = posY + ((lSizeY - 1) * 0.5)
            effect_setOffsetPosition(effect, rotation * (offset + vec3_new(((posX + 0.5) - (sizeX / 2)) * pixelSize.x, ((posY + 0.5) - (sizeY / 2)) * -pixelSize.y, backplate and (debugMode and 0.051 or 0.011) or 0)))
            local localScaleAddValue = debugMode and -(pixelSize.x / 2) or scaleAddValue
            local vec = pixelSize * 1
            vec.x = (pixelSize.x * lSizeX) + localScaleAddValue
            vec.y = (pixelSize.y * lSizeY) + localScaleAddValue
            effect_setScale(effect, vec)
            effect_setParameter(showedNodeEffects[i], "color", sm.color.new(1, 0, 0))
        end
    end
    ]]

    --if true then
    local clearBackplate = false
    
    local drawer
    drawer = canvasAPI.createDrawer(sizeX, sizeY, nil, function (base, clearOnly, maxBuffer, force, newBuffer, realBuffer, bufferChangedFrom, bufferChangedTo, changes, changesIndex, changesCount, _changes)
        lastNewBuffer, lastBase = newBuffer, base
        lastDrawTickTime = sm.game.getCurrentTick()

        local changedList = {}
        local changedColorList = {}
        local hideList = {}

        if clearBackplate then
            --checkNodeEffects()
            --showNodeEffects()
            --[[
            for i, effectData in pairs(nodeEffects) do
                hideList[effectData[1].id] = effectData[1]
                hideEffectDataLater(effectData)
                --effectData[8] = true
            end
            ]]
            for index in pairs(_changes) do
                if not changes[index] then
                    changesCount = changesCount + 1
                    changesIndex[changesCount] = index
                end
            end
        end

        --for i in pairs(changes) do
        for i2 = 1, changesCount do
            local i = changesIndex[i2]
            local color = newBuffer[i] or base
            if effects[i] then
                if not colorEquals(effects[i][2], color) then
                    local px = math_floor(i / sizeY)
                    local py = i % sizeY
                    if color == oldBackplateColor then
                        local aSizeX, aSizeY = effects[i][5] > 1, effects[i][6] > 1
                        if aSizeX and aSizeY then
                            extractVerticleLine(changedList, changedColorList, i, px, py, true)
                            extractVerticlePixel(changedList, changedColorList, i, px, py)
                        elseif aSizeX then
                            extractVerticleLine(changedList, changedColorList, i, px, py)
                        elseif aSizeY then
                            extractVerticlePixel(changedList, changedColorList, i, px, py)
                        else
                            changedList[effects[i]] = nil
                            hideEffectData(effects[i])
                        end
                    else
                        _changes[i] = true
                        if effects[i][5] > 1 then
                            extractVerticleLine(changedList, changedColorList, i, px, py, true)
                        end
                        if effects[i][6] > 1 then
                            extractVerticlePixel(changedList, changedColorList, i, px, py, true)
                        end
                        if not tryAttach(changedList, i, px, py, color, hideList) then
                            effects[i][2] = color
                            changedColorList[effects[i][1]] = effects[i]
                        end
                    end
                end
            elseif color ~= oldBackplateColor then
                _changes[i] = true
                local px = math_floor(i / sizeY)
                local py = i % sizeY
                if not tryAttach(changedList, i, px, py, color, hideList) then
                    local effect = createEffect()
                    local effectData = {
                        effect,
                        color,
                        px, --3. root pos x
                        py, --4. root pos Y
                        1,  --5. sizeX
                        1,  --6. sizeY
                        i   --7. root index
                    }
                    effects[i] = effectData
                    nodeEffects[i] = effectData
                    changedList[effectData] = true
                    changedColorList[effect] = effectData
                    hideList[effect.id] = nil
                end
            end
        end

        for _, effect in pairs(hideList) do
            effect_setOffsetPosition(effect, hiddenOffset)
        end

        for effectData in pairs(changedList) do
            setEffectDataParams(effectData)
        end

        local color
        for _, effectData in pairs(changedColorList) do
            color = effectData[2]
            if not colorCache[color] then
                colorCache[color] = color_new_fromSmallNumber(color, alpha)
            end
            effect_setParameter(effectData[1], "color", colorCache[color])
        end

        if clearOnly then
            clearBufferedEffects()
        end

        if clearBackplate then
            drawer.flushOldChanges()
            clearBackplate = false
        end

        needOptimize = true
    end, nil, function (_, color, changes)
        if backplate then
            oldBackplateColor = color
            effect_setParameter(backplate, "color", color_new_fromSmallNumber(color, alpha))
            clearBackplate = true
        else
            drawer.fullRefresh()
        end
    end, nil, nil, true)

    if not backplate then
        drawer.fullRefresh()
    end

    --[[
    else
        drawer = canvasAPI.createDrawer(sizeX, sizeY, nil, function (base, clearOnly, maxBuffer, force, newBuffer, realBuffer, bufferChangedFrom, bufferChangedTo)
            local oldBase = lastBase
            lastNewBuffer, lastBase = newBuffer, base
    
            local newBackplateColor
            local oldOldBackplateColor
            local ctick = sm.game.getCurrentTick()
            
            if backplate then
                if clearOnly then
                    newBackplateColor = base
                else
                    if not lastPopularColor or ctick - lastPopularColorTick >= lastPopularColorUpdatePerTick or base ~= oldBase then
                        mathPopularColor()
                    end
                    newBackplateColor = lastPopularColor
                end
    
                if newBackplateColor ~= oldBackplateColor then
                    effect_setParameter(backplate, "color", color_new_fromSmallNumber(newBackplateColor, alpha))
                    if not clearOnly then
                        hideEffectsWithColor(newBackplateColor)
                    end
                    oldOldBackplateColor = oldBackplateColor
                    oldBackplateColor = newBackplateColor
                end
    
                if clearOnly then
                    needOptimize = false
                    delAllEffects()
                    clearBufferedEffects()
                    return true
                end
            end
    
            if force or oldOldBackplateColor then
                bufferChangedFrom, bufferChangedTo = 0, maxBuffer
            end
    
            --print("FFFF", (bufferChangedTo - bufferChangedFrom) / 1000)
    
            local changedList = {}
            local changedColorList = {}

            local color, px, py, oldEffect, effect, effectData
            local i = bufferChangedFrom
            while i <= bufferChangedTo do
                color = newBuffer[i] or base
                if not realBuffer[i] or not colorEquals(color, realBuffer[i]) or color == oldOldBackplateColor or force then
                    lastDrawTickTime = ctick
                    needOptimize = true
    
                    px = math_floor(i / sizeY)
                    py = i % sizeY
                    if effects[i] then
                        if effects[i][5] > 1 then
                            extractVerticleLine(changedList, changedColorList, px, py)
                        end
                        if effects[i][6] > 1 then
                            extractVerticlePixel(changedList, changedColorList, px, py)
                        end
                        if color == newBackplateColor then
                            changedList[effects[i] ] = nil
                            hideEffectData(effects[i] )
                        elseif not tryAttach(changedList, i, px, py, color) then
                            effects[i][2] = color
                            changedColorList[effects[i][1] ] = effects[i]
                        end
                    elseif color ~= newBackplateColor and not tryAttach(changedList, i, px, py, color) then
                        effect = createEffect()
                        effectData = {
                            effect,
                            color,
                            px, --3. root pos x
                            py, --4. root pos Y
                            1,  --5. sizeX
                            1,  --6. sizeY
                            i   --7. root index
                        }
                        effects[i] = effectData
                        changedList[effectData] = true
                        changedColorList[effect] = effectData
                    end
                    realBuffer[i] = color
                end
                i = i + 1
            end
    
            --[[
            local cx, cy = 7, 4
            print("1", effectIndexAtPos(cx, cy), effects[effectIndexAtPos(cx, cy)])
            extractVerticleLine(changedList, changedColorList, cx, cy)
            print("2", effectIndexAtPos(cx, cy), effects[effectIndexAtPos(cx, cy)])
            print("2-", effectIndexAtPos(cx-1, cy), effects[effectIndexAtPos(cx-1, cy)])
            print("2+", effectIndexAtPos(cx+1, cy), effects[effectIndexAtPos(cx+1, cy)])
            ] ]
    
            --[[
            extractVerticleLine(changedList, changedColorList, 5, 5)
            extractVerticlePixel(changedList, changedColorList, 5, 5)
            changedColorList[effects[effectIndexAtPos(5, 5)][1] ] = effects[effectIndexAtPos(5, 5)]
            effects[effectIndexAtPos(5, 5)][2] = 0x00ff00
            tryAttach(changedList, effectIndexAtPos(5, 5), 5, 5, 0x00ff00)
            extractVerticleLine(changedList, changedColorList, 5, 5)
            extractVerticlePixel(changedList, changedColorList, 5, 5)
            ] ]
    
            for effectData in pairs(changedList) do
                setEffectDataParams(effectData)
            end
    
            for _, effectData in pairs(changedColorList) do
                effect_setParameter(effectData[1], "color", color_new_fromSmallNumber(effectData[2], alpha))
            end
    
            if clearOnly then
                clearBufferedEffects()
            end
        end)
    end
    ]]
    drawer.setWait(true)

    --[[
    local _flush = drawer.flush
    function drawer.flush(force)
        _flush(true)
    end
    ]]

    local function getSelfPos()
        local pt = type(parent)
        if pt == "Interactable" then
            return parent.shape.worldPosition
        elseif pt == "Character" then
            return parent.worldPosition
        end
    end

    local reoptimizeCanvas = sizeX * sizeY <= (256 * 256)
    if debugMode then
        print("reoptimizeCanvas", sizeX, sizeY, reoptimizeCanvas)
    end
    local function optimize()
        --[[
        if backplate then
            mathPopularColor()
            if lastPopularColor ~= oldBackplateColor then
                effect_setParameter(backplate, "color", color_new_fromSmallNumber(lastPopularColor, alpha))
                if not reoptimizeCanvas then
                    fillEmptySpace(oldBackplateColor)
                    hideEffectsWithColor(lastPopularColor)
                end
                oldBackplateColor = lastPopularColor
            end
        end
        ]]

        if debugMode then
            local usedEffects = 0
            local addedList = {}
            for k, v in pairs(effects) do
                if not addedList[v[1]] then
                    usedEffects = usedEffects + 1
                    addedList[v[1]] = true
                end
            end
            print("effect info:")
            print("used effects: ", usedEffects)
            print("buffered effects: ", bufferedEffectsIndex)
        end

        ------------------------------------------

        if reoptimizeCanvas then
            --checkNodeEffects()

            if debugMode then
                print("reoptimize canvas")
            end

            if backplate then
                mathPopularColor()
                if lastPopularColor ~= oldBackplateColor then
                    effect_setParameter(backplate, "color", color_new_fromSmallNumber(lastPopularColor, alpha))
                    oldBackplateColor = lastPopularColor
                end
            end
            
            for i, effectData in pairs(nodeEffects) do
                hideEffect(effectData[1])
            end
            effects = {}
            nodeEffects = {}

            local changedList = {}
            local changedColorList = {}
            local i = 0
            while i <= maxEffectArrayBuffer do
                local color = lastNewBuffer[i] or lastBase
                local px = math_floor(i / sizeY)
                local py = i % sizeY
                if color ~= oldBackplateColor and not tryAttach(changedList, i, px, py, color) then
                    local effect = createEffect()
                    local effectData = {
                        effect,
                        color,
                        px, --3. root pos x
                        py, --4. root pos Y
                        1,  --5. sizeX
                        1,  --6. sizeY
                        i   --7. root index
                    }
                    effects[i] = effectData
                    nodeEffects[i] = effectData
                    changedList[effectData] = true
                    changedColorList[effect] = effectData
                end
                i = i + 1
            end

            for effectData in pairs(changedList) do
                setEffectDataParams(effectData)
            end

            local color
            for _, effectData in pairs(changedColorList) do
                color = effectData[2]
                if not colorCache[color] then
                    colorCache[color] = color_new_fromSmallNumber(color, alpha)
                end
                effect_setParameter(effectData[1], "color", colorCache[color])
            end
        end

        ------------------------------------------

        if bufferedEffectsIndex > 1024 then
            if debugMode then
                print("stoping buffered effects")
            end

            for i = 1, bufferedEffectsIndex - 1024 do
                effect_stop(bufferedEffects[i])
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
            ]]
        end
    end

    function obj.setAlpha(_alpha)
        alpha = _alpha
        for _, effectData in pairs(nodeEffects) do
            effect_setParameter(effectData[1], "color", color_new_fromSmallNumber(effectData[2], alpha))
        end
    end

    function obj.setOptimizationLevel(value)
        optimizationLevel = value
        if value == 0 then
            colorEquals = colorEquals_raw
        else
            colorEquals = colorEquals_smart
        end
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

    local oldOptimizeTime
    function obj.update()
        local newShowState = true
        if disable then
            newShowState = false
        elseif dist then
            if not pcall(function()
                newShowState = mathDist(getSelfPos(), sm_localPlayer_getPlayer().character.worldPosition) <= dist
            end) then
                newShowState = false
            end
        end

        if newShowState ~= showState then
            showState = newShowState
            if newShowState then
                drawer.setWait(false)
                if not backplate and not flushedDefault then
                    drawer.flush(true)
                    flushedDefault = true
                end
                for _, effect in pairs(nodeEffects) do
                    if not effect_isPlaying(effect[1]) then
                        effect_start(effect[1])
                    end
                end
                if backplate then
                    effect_start(backplate)
                end
            else
                for _, effect in pairs(nodeEffects) do
                    effect_stop(effect[1])
                end
                for i = 1, bufferedEffectsIndex do
                    effect_stop(bufferedEffects[i])
                end
                if backplate then
                    effect_stop(backplate)
                end
                drawer.setWait(true)
            end
        end

        local ctick = sm.game.getCurrentTick()
        local optimizePeer = 40
        if lastDrawTickTime and ctick - lastDrawTickTime < 20 then
            optimizePeer = 80
        end

        if newShowState and needOptimize and (not oldOptimizeTime or ctick - oldOptimizeTime >= optimizePeer) then
            needOptimize = false
            oldOptimizeTime = ctick
            optimize()
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
                return
            else
                local vec = vec3_new(0.0072, 0.0072, 0) * pixelSize
                vec.z = 0.00025
                obj.setPixelSize(vec)
                return
            end
        end
        if backplate then
            effect_setScale(backplate, vec3_new((pixelSize.x * sizeX) - 0.00005, (pixelSize.y * sizeY) - 0.00005, pixelSize.z))
        end
        if autoScaleAddValue then
            scaleAddValue = (pixelSize.x + pixelSize.y + pixelSize.z) / 50
        end
        --scaleAddValue = -0.003
    end

    function obj.setOffset(_offset)
        offset = _offset
        if backplate then
            effect_setOffsetPosition(backplate, rotation * offset)
        end
        for _, effectData in pairs(nodeEffects) do
            setEffectDataParams(effectData)
        end
    end

    function obj.setCanvasRotation(_rotation)
        rotation = _rotation
        if backplate then
            effect_setOffsetRotation(backplate, rotation)
        end
        for _, effectData in pairs(nodeEffects) do
            effect_setOffsetRotation(effectData[1], rotation)
            setEffectDataParams(effectData)
        end
    end

    function obj.destroy()
        for _, effectData in pairs(nodeEffects) do
            effect_destroy(effectData[1])
        end
        if backplate then
            effect_destroy(backplate)
        end
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

    function obj.pushDataTunnelParams(dataTunnel)
        obj.setOptimizationLevel(dataTunnel.optimizationLevel)
        obj.setAlpha(dataTunnel.light)
        drawer.pushDataTunnelParams(dataTunnel)
    end

    return obj
end

--simulates the API of screens from SComputers on the client side of your parts
function canvasAPI.createClientScriptableCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation, material)
    local dataTunnel = {}
    local canvas = canvasAPI.createCanvas(parent, sizeX, sizeY, pixelSize, offset, rotation, material)
    local api = canvasAPI.createScriptableApi(sizeX, sizeY, dataTunnel, nil, canvas.drawer)
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

    function api.update(dt)
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
            if needPushStack(canvas, dataTunnel, dt) then
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

--simulates the SComputers API, does not implement data transfer
function canvasAPI.createScriptableApi(width, height, dataTunnel, flushCallback, drawer)
    dataTunnel = dataTunnel or {}
    dataTunnel.rotation = 0
    dataTunnel.brightness = 1
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
    local lastPixelX, lastPixelY, lastPixelColor
    local currentSettedFont

    local viewport_x, viewport_y, viewport_sx, viewport_sy

    local dFontX, dFontY = font.width, font.height
    local fontX, fontY
    local mFontX, mFontY
    local xFontX, xFontY
    local sFontX, sFontY
    local fontScaleX, fontScaleY = 1, 1
    local function updateFontSize()
        fontX, fontY = math_ceil(dFontX * fontScaleX), math_ceil(dFontY * fontScaleY)
        mFontX, mFontY = fontX - 1, fontY - 1
        xFontX, xFontY = fontX + 1, fontY + 1
        sFontX, sFontY = fontX + spacing, fontY + 1
    end
    updateFontSize()

    local api
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
            return drawer.getNewBuffer(x + (y * rwidth))
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
                totalSize = ((textLen - 1) * (fontX + spacing)) + fontX
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

        clear = function(color)
            if pixelsCacheExists then
                pixelsCache = {}
                pixelsCacheExists = false
            end

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
            color = color or false
            if pixelsCache[index] ~= color then
                if false and pixelsCacheExists and x == lastPixelX + 1 then
                    
                else
                    --[[
                    stack[stackIndex] = -index - 20
                    stackIndex = stackIndex + 1
                    stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
                    stackIndex = stackIndex + 1
                    ]]
                    stack[stackIndex] = 1
                    stackIndex = stackIndex + 1
                    stack[stackIndex] = index
                    stackIndex = stackIndex + 1
                    stack[stackIndex] = formatColorToSmallNumber(color, whiteSmallNumber)
                    stackIndex = stackIndex + 1
                end

                lastPixelX, lastPixelY, lastPixelColor = x, y, color

                pixelsCache[index] = color
                pixelsCacheExists = true
            end
        end,
        fillRect = function(x, y, sizeX, sizeY, color)
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
            if r > 1024 then r = 1024 end

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
            if r > 1024 then r = 1024 end
            
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
            if r > 1024 then r = 1024 end

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
            if r > 1024 then r = 1024 end
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
        flush = function()
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
            api.flush()
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
                error("integer must be in [0 3]", 2)
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
                fontIndex = customFontIndexesCache[customFont]
                if not fontIndex then
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
                dFontX, dFontY = font.width, font.height
                monoFont = true
            end
            updateFontSize()
            newDataFlag = true
        end,
        getFont = function()
            return currentSettedFont
        end,

        getFontWidth = function ()
            return fontX
        end,
        getFontHeight = function ()
            return fontY
        end,
        getRealFontWidth = function ()
            return dFontX
        end,
        getRealFontHeight = function ()
            return dFontY
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

        setBrightness = function(value) --float from 0
            checkArg(1, value, "number")
            if value < 0 then value = 0 end
            if value > 255 then value = 255 end
            if dataTunnel.brightness ~= value then
                dataTunnel.brightness = value
                dataTunnel.dataUpdated = true
            end
        end,
        getBrightness = function(value)
            return dataTunnel.brightness
        end,

        setLight = function(value)
            checkArg(1, value, "number")
            value = math.floor(value + 0.5)
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

        reset = function()
            if api.setFontScale then api.setFontScale(1, 1) end
            if api.setTextSpacing then api.setTextSpacing(1) end
            if api.setFont then api.setFont() end
            if api.setRotation then api.setRotation(0) end
            if api.setUtf8Support then api.setUtf8Support(false) end
            if api.setClicksAllowed then api.setClicksAllowed(false) end
            if api.setMaxClicks then api.setMaxClicks(16) end
            if api.clearClicks then api.clearClicks() end
            if api.setSkipAtNotSight then api.setSkipAtNotSight(false) end
            if api.setRenderAtDistance then api.setRenderAtDistance(false) end
            if api.setViewport then api.setViewport() end
            if api.setBrightness then api.setBrightness(1) end
            if api.setLight then api.setLight(DEFAULT_ALPHA_VALUE) end
            if api.setOptimizationLevel then api.setOptimizationLevel(16) end
            dataTunnel.display_reset = true
        end
    }

    api.update = api.flush
    api.getBuffer = api.get
    api.getCurrent = api.get

    local internal = {
        rawPush = function(tbl)
            for i = 1, #tbl do
                stack[stackIndex] = tbl[i]
                stackIndex = stackIndex + 1
            end
        end
    }

    return api, internal
end

--adds a touch screen API (does not implement click processing)
function canvasAPI.addTouch(api, dataTunnel)
    dataTunnel = dataTunnel or {}
    dataTunnel.clicksAllowed = false
    dataTunnel.maxClicks = 16
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
        table_insert(dataTunnel.clickData, tbl)
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
        brightness = dataTunnel.brightness,
        optimizationLevel = dataTunnel.optimizationLevel,
        light = dataTunnel.light
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