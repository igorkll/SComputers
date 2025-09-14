function sc_reglib_colors()
local colors = {num = {}, str = {}, sm = {}}
colors.names = {"Gray", "Yellow", "LimeGreen", "Green", "Cyan", "Blue", "Violet", "Magenta", "Red", "Orange"}

colors.num.Gray	      = {0xEEEEEE, 0x7F7F7F, 0x4A4A4A, 0x222222}
colors.num.Yellow     = {0xF5F071, 0xE2DB13, 0x817C00, 0x323000}
colors.num.LimeGreen  = {0xCBF66F, 0xA0EA00, 0x577D07, 0x375000}
colors.num.Green      = {0x68FF88, 0x19E753, 0x0E8031, 0x064023}
colors.num.Cyan       = {0x7EEDED, 0x2CE6E6, 0x118787, 0x0A4444}
colors.num.Blue       = {0x4C6FE3, 0x0A3EE2, 0x0F2E91, 0x0A1D5A}
colors.num.Violet     = {0xAE79F0, 0x7514ED, 0x500AA6, 0x35086C}
colors.num.Magenta    = {0xEE7BF0, 0xCF11D2, 0x720A74, 0x520653}
colors.num.Red        = {0xF06767, 0xD02525, 0x7C0000, 0x560202}
colors.num.Orange     = {0xEEAF5C, 0xDF7F00, 0x673B00, 0x472800}

colors.str.Gray	      = {"EEEEEE", "7F7F7F", "4A4A4A", "222222"}
colors.str.Yellow     = {"F5F071", "E2DB13", "817C00", "323000"}
colors.str.LimeGreen  = {"CBF66F", "A0EA00", "577D07", "375000"}
colors.str.Green	  = {"68FF88", "19E753", "0E8031", "064023"}
colors.str.Cyan       = {"7EEDED", "2CE6E6", "118787", "0A4444"}
colors.str.Blue       = {"4C6FE3", "0A3EE2", "0F2E91", "0A1D5A"}
colors.str.Violet     = {"AE79F0", "7514ED", "500AA6", "35086C"}
colors.str.Magenta    = {"EE7BF0", "CF11D2", "720A74", "520653"}
colors.str.Red        = {"F06767", "D02525", "7C0000", "560202"}
colors.str.Orange     = {"EEAF5C", "DF7F00", "673B00", "472800"}

for name, tbl in pairs(colors.str) do
    colors.sm[name] = {}
    for i, data in ipairs(tbl) do
        colors.sm[name][i] = sm.color.new(data)
    end
end

for name, tbl in pairs(colors.num) do
    colors[name] = tbl
end

--------------------------------------

local math_floor = math.floor
local bit_rshift = bit.rshift
local sc_formatColor = sc.formatColor
local sm_color_new = sm.color.new
local bit_band = bit.band
local math_max = math.max
local math_min = math.min
local string_format = string.format

function colors.hsvToRgb(h, s, v)
    local r, g, b

    local i = math_floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local i6 = i % 6

    if i6 == 0 then
        r, g, b = v, t, p
    elseif i6 == 1 then
        r, g, b = q, v, p
    elseif i6 == 2 then
        r, g, b = p, v, t
    elseif i6 == 3 then
        r, g, b = p, q, v
    elseif i6 == 4 then
        r, g, b = t, p, v
    elseif i6 == 5 then
        r, g, b = v, p, q
    end

    return r, g, b
end

function colors.hsvToRgb256(hue, saturation, value)
    local r, g, b

    if saturation == 0 then
        r = value
        g = value
        b = value
        return r, g, b
    end

    local region = math_floor(hue / 43)
    local remainder = (hue - (region * 43)) * 6
    local p = bit_rshift(value * (255 - saturation), 8)
    local q = bit_rshift(value * (255 - bit_rshift(saturation * remainder, 8)), 8)
    local t = bit_rshift(value * (255 - bit_rshift(saturation * (255 - remainder), 8)), 8)

    if region == 0 then
        r = value; g = t; b = p;
    elseif region == 1 then
        r = q; g = value; b = p;
    elseif region == 2 then
        r = p; g = value; b = t;
    elseif region == 3 then
        r = p; g = q; b = value;
    elseif region == 4 then
        r = t; g = p; b = value;
    else
        r = value; g = p; b = q;
    end

    return r, g, b
end

function colors.pack(r, g, b)
    return (r * 256 * 256) + (g * 256) + b
end

function colors.unpack(color)
    return math_floor(color / 256 / 256), math_floor(color / 256) % 256, color % 256
end

function colors.packFloat(r, g, b)
    return colors.pack(math_floor(r * 255), math_floor(g * 255), math_floor(b * 255))
end

function colors.unpackFloat(color)
    local r, g, b = colors.unpack(color)
    return r / 255, g / 255, b / 255
end

local colors_unpack = colors.unpack
local colors_packFloat = colors.packFloat
local colors_unpackFloat = colors.unpackFloat
local colors_pack = colors.pack

local function colorpartToStrpart(number)
    local hex = string_format("%x", number)
    if #hex < 2 then
        hex = "0" .. hex
    end
    return hex
end

local function strpartToColorpart(colorpart)
    return tonumber(colorpart, 16)
end

function colors.formatToNumber(color)
    local t = type(color)
    if t == "Color" then
        return colors_packFloat(color.r, color.g, color.b)
    elseif t == "string" then
        return colors_pack(strpartToColorpart(color:sub(1, 2)), strpartToColorpart(color:sub(3, 4)), strpartToColorpart(color:sub(5, 6)))
    elseif t == "number" then
        return color
    end

    return 0x000000
end

function colors.formatToColor(color)
    local t = type(color)
    if t == "Color" then
        return color
    elseif t == "string" then
        return sm_color_new(color)
    elseif t == "number" then
        return sm_color_new(colors_unpackFloat(color))
    end

    return sm_color_new(0, 0, 0)
end
local colors_formatToColor = colors.formatToColor

function colors.formatToString(color)
    local t = type(color)
    if t == "Color" then
        return colorpartToStrpart(color.r * 255) .. colorpartToStrpart(color.r * 255) .. colorpartToStrpart(color.r * 255)
    elseif t == "string" then
        return color
    elseif t == "number" then
        local r, g, b = colors_unpack(color)
        return colorpartToStrpart(r) .. colorpartToStrpart(g) .. colorpartToStrpart(b)
    end

    return "000000"
end
local colors_formatToString = colors.formatToString

function colors.combineColorToNumber(value, color1, color2)
    return colors_packFloat(colorCombineRaw(value, colors_formatToColor(color1), colors_formatToColor(color2)))
end

function colors.combineColorToColor(value, color1, color2)
    return colorCombine(value, colors_formatToColor(color1), colors_formatToColor(color2))
end

local colors_combineColorToNumber = colors.combineColorToNumber
function colors.combineColorToString(value, color1, color2)
    return colors_formatToString(colors_combineColorToNumber(value, colors_formatToColor(color1), colors_formatToColor(color2)))
end

return colors
end