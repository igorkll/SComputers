local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local string_format = string.format
local math_ceil = math.ceil
local string_byte = string.byte
local type = type
local tostring = tostring
local pairs = pairs
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local ipairs = ipairs
local pairs = pairs
local sm_color_new = sm.color.new

function colorCombineRaw(v, color1, color2)
    return color1.r + v * (color2.r - color1.r), color1.g + v * (color2.g - color1.g), color1.b + v * (color2.b - color1.b)
end

function colorCombine(v, color1, color2)
    return sm_color_new(colorCombineRaw(v, color1, color2))
end

function colorCombineAdd(color, v, addColor)
	color.r = color.r + (v * (addColor.r - color.r))
	color.g = color.g + (v * (addColor.g - color.g))
	color.b = color.b + (v * (addColor.b - color.b))
end

function colorCombineToNumber(v, color1, color2)
    return (math_floor((color1.r + v * (color2.r - color1.r)) * 256) * 256 * 256) + (math_floor((color1.g + v * (color2.g - color1.g)) * 256) * 256) + math_floor((color1.b + v * (color2.b - color1.b)) * 256)
end

function colorCombineToString(v, color1, color2)
    return numberToColorpart(math_floor(color1.r + v * (color2.r - color1.r))) .. numberToColorpart(math_floor(color1.g + v * (color2.g - color1.g))) .. numberToColorpart(math_floor(color1.b + v * (color2.b - color1.b))) .. "ff"
end

function tableShuffle(array)
    local n = #array
    for i = n, 2, -1 do
        local j = math.random(i)
        array[i], array[j] = array[j], array[i]
    end
end

function doesRayIntersectSphere(P0, P1, C, r)
    local D = {x = P1.x - P0.x, y = P1.y - P0.y, z = P1.z - P0.z}
    local Lx = P0.x - C.x
    local Ly = P0.y - C.y
    local Lz = P0.z - C.z

    local a = D.x^2 + D.y^2 + D.z^2
    local b = 2 * (Lx * D.x + Ly * D.y + Lz * D.z)
    local c = Lx^2 + Ly^2 + Lz^2 - r^2

    local discriminant = b^2 - 4 * a * c

    if discriminant < 0 then
        return false
    end

    return true
end

function multiColorCombine(colors)
	local r, g, b = 0, 0, 0
	local sum = 0
	for _, color in ipairs(colors) do
		r = r + color.r
		g = g + color.g
		b = b + color.b
		sum = sum + 1
	end
    return sm.color.new(r / sum, g / sum, b / sum)
end

function mt_hook(mt)
	local empty_class = class(mt)
    empty_class.__index = mt.__index
    return empty_class()
end

local maxrep = 1024 * 1024
local orep = string.rep
function customRep(s, n, sep)
    checkArg(1, s, "string")
    checkArg(2, n, "number")
    checkArg(3, sep, "string", "nil")

    if n <= 0 then
        return ""
    end

    local allocations = n * #s
    if sep then
        local seplen = #sep
        allocations = allocations + ((n * seplen) - seplen)
    end
    if allocations > maxrep then
        error("the maximum amount of allocations via string.rep is 1024kb", 2)
    end

    local result = {pcall(orep, s, n, sep)}
    if result[1] then
        return result[2]
    else
        error(tostring(result[2]), 2)
    end
end

function isTweaksAvailable()
	return not not sc.getApi("getmetatable")
end

function tweaks()
	local getmetatable = sc.getApi("getmetatable")
	if getmetatable then
		local string_mt = getmetatable("")
		string_mt.__index.rep = customRep
	end
end

function unTweaks()
	local getmetatable = sc.getApi("getmetatable")
	if getmetatable then
		local string_mt = getmetatable("")
		string_mt.__index.rep = orep
	end
end

local jsonEncodeInputCheck
function jsonEncodeInputCheck(tbl, level, itemsCount)
	itemsCount = itemsCount or 0

	if level >= 8 then
		error("too many nested tables. max 8", level + 3)
	end

	local isStringKey = false
	local isNumberKey = false
	for key, value in pairs(tbl) do
		local keytype = type(key)
		local valuetype = type(value)

		------ check count
		if itemsCount > 256 then
			error("your table cannot contain more than 256 items", level + 3)
		end
		itemsCount = itemsCount + 1

		------ key check
		if keytype == "string" then
			isStringKey = true
		elseif keytype == "number" then
			isNumberKey = true
		else
			error("keys in json can only be string or number", level + 3)
		end
		if isStringKey and isNumberKey then
			error("keys in json cannot be both string and number in the same subtable", level + 3)
		end
		
		------ value check
		if
		valuetype ~= "nil" and
		valuetype ~= "boolean" and
		valuetype ~= "table" and
		valuetype ~= "number" and
		valuetype ~= "string" and
		valuetype ~= "table" then
			error("unsupported type \"" .. valuetype .. "\" in json", level + 3)
		end
		
		if valuetype == "table" then
			itemsCount = jsonEncodeInputCheck(value, level + 1, itemsCount)
		end
	end
	
	return itemsCount
end
_G.jsonEncodeInputCheck = jsonEncodeInputCheck

function NormalizeQuaternion(quaternion)
    local magnitude = math_sqrt(quaternion.x^2 + quaternion.y^2 + quaternion.z^2 + quaternion.w^2)
    if magnitude ~= 0 then
        quaternion.x = quaternion.x / magnitude
        quaternion.y = quaternion.y / magnitude
        quaternion.z = quaternion.z / magnitude
        quaternion.w = quaternion.w / magnitude
    end
    return quaternion
end

function map(value, low, high, low_2, high_2)
    return low_2 + (high_2 - low_2) * ((value - low) / (high - low))
end

function constrain(value, min, max)
    return math_min(math_max(value, min), max)
end

local constrain, map = constrain, map
function mapClip(value, low, high, low_2, high_2)
    return constrain(map(value, low, high, low_2, high_2), low_2, high_2)
end

function mathDist(pos1, pos2)
    return math_sqrt(((pos1.x - pos2.x) ^ 2) + ((pos1.y - pos2.y) ^ 2) + ((pos1.z - pos2.z) ^ 2))
end

function round(number, numbers)
    numbers = numbers or 3
    return tonumber(string_format("%." .. tostring(math_floor(numbers)) .. "f", number))
end

function mathRound(number)
    return math.floor(number + 0.5)
end

function isNan(number)
    return number ~= number
end

function probability(probabilityNum)
    return math_random() > ((99 - probabilityNum) / 99)
end

function require(name)
	return dofile(name .. ".lua")
end

local tcCache = {}
local function tableChecksum(input, blkey)
	local value, input_type = 5132, type(input)
	if input_type == "table" then
		local ldop = 0
		for k, v in pairs(input) do
			if not blkey or k ~= blkey then
				value = value + (tableChecksum(k) * tableChecksum(v)) + ldop
				ldop = ldop + math_ceil(value / 48891)
			end
		end
		value = value + ldop
	elseif input_type == "number" then
		value = (input + 17) * 2
	elseif input_type == "Vec3" then
		value = value + (input.x * 3)
		value = value - (input.y * 14)
		value = value - (input.z * 7)
	elseif input_type == "Color" then
		value = value + (input.r * 2)
		value = value - (input.g * 4)
		value = value + (input.b * 8)
	elseif input_type == "boolean" then
		if input then
			value = value + 8231
		else
			value = value - 3265
		end
	elseif input_type == "nil" then
		value = value - 984
	else
		local strInput = tostring(input)
		if tcCache[strInput] then
			return tcCache[strInput]
		end

		for i = 1, #strInput do
			value = value + ((string_byte(strInput, i) + i) * i)
		end

		tcCache[strInput] = value
	end
	
	return value
end
_G.tableChecksum = tableChecksum
_G.tcCache = tcCache

function tableEquals(tbl1, tbl2)
	if #tbl1 ~= #tbl2 then
		return false
	end
	return tableChecksum(tbl1) == tableChecksum(tbl2)
end

local sm_quat_new = sm.quat.new
local math_sin = math.sin
local math_cos = math.cos

local function doQuat(x, y, z, w)
    local sin = math_sin(w / 2)
    return sm_quat_new(sin * x, sin * y, sin * z, math_cos(w / 2))
end

function fromEuler(x, y, z) --custom implementation
	return doQuat(1, 0, 0, x) * doQuat(0, 1, 0, y) * doQuat(0, 0, 1, z)
end

function fromEulerVec(vec) --custom implementation
	local x, y, z = vec.x, vec.y, vec.z
	return doQuat(1, 0, 0, x) * doQuat(0, 1, 0, y) * doQuat(0, 0, 1, z)
end

local sqrt = math.sqrt
local atan2 = math.atan2
local asin = math.asin
local pi = math.pi

--[[
function toEuler(q)
    local angles = sm.vec3.new(0, 0, 0)

    -- roll (x-axis rotation)
    local sinr_cosp = 2 * (q.w * q.x + q.y * q.z)
    local cosr_cosp = 1 - 2 * (q.x * q.x + q.y * q.y)
    angles.x = atan2(sinr_cosp, cosr_cosp)

    -- pitch (y-axis rotation)
    local sinp = sqrt(1 + 2 * (q.w * q.y - q.x * q.z))
    local cosp = sqrt(1 - 2 * (q.w * q.y - q.x * q.z))
    angles.y = 2 * atan2(sinp, cosp) - pi / 2

    -- yaw (z-axis rotation)
    local siny_cosp = 2 * (q.w * q.z + q.x * q.y)
    local cosy_cosp = 1 - 2 * (q.y * q.y + q.z * q.z)
    angles.z = atan2(siny_cosp, cosy_cosp)

    return angles
end
]]

--[[
function toEuler(quat)
	local x, y, z, w = quat.x, quat.y, quat.z, quat.w
	local rollDegrees = atan2(2*(w*x + y*z), 1 - 2*(x*x + y*y))
	local pitchDegrees = asin(2*(w*y - z*x))
	local yawDegrees = atan2(2*(w*z + x*y), 1 - 2*(y*y + z*z))
	return sm.vec3.new(rollDegrees, pitchDegrees, yawDegrees)
end
]]

function toEuler(quat)
	local x, y, z, w = quat.x, quat.y, quat.z, quat.w
	local ex = atan2(2 * (w * x + y * z), 1 - 2 * (x^2 + y^2))
	local ey = asin(2 * (w * y - z * x))
	local ez = atan2(2 * (w * z + x * y), 1 - 2 * (y^2 + z^2))
	if ex ~= ex then ex = 0 end --is nan check
	if ey ~= ey then ey = 0 end --is nan check
	if ez ~= ez then ez = 0 end --is nan check
	return sm.vec3.new(ex, ey, ez)
end

-------------------------------------------------------

function splitByMaxSize(str, max)
    max = math_floor(max + 0.5)
    if max <= 0 then
        max = 1
    end

    local strs = {}
    while #str > 0 do
		sc.yield()

        table_insert(strs, str:sub(1, max))
        str = str:sub(#strs[#strs] + 1)
    end
    return strs
end

function splitByMaxSizeWithTool(tool, str, max)
    max = math.floor(max + 0.5)
    if max <= 0 then
        max = 1
    end

    local strs = {}
    while true do
        local strlen = tool.len(str)
        if strlen == 0 then
            break
        end
        
        sc.yield()
        table.insert(strs, tool.sub(str, 1, max))
        str = tool.sub(str, tool.len(strs[#strs]) + 1, strlen)
    end
    return strs
end

function paths_path(str)
	local strs = FileSystem.strSplit(string, str, {"/"})
	if str:sub(1, 1) == "/" then
		table_remove(strs, 1)
	end
	if strs[#strs] == "" then
		table_remove(strs)
	end
	table_remove(strs)
	return table_concat(strs, "/")
end

function checkArg(n, have, ...)
	have = type(have)
	local tbl = {...}
	for _, t in ipairs(tbl) do
		if have == t then
			return
		end
	end
	error(string_format("bad argument #%d (%s expected, got %s)", n, table_concat(tbl, " or "), have), 3)
end

local orig_backslash = "\\"
local magic_backslash = "¦"
function formatBeforeGui(text)
	text = text:gsub("#", "##"):gsub(orig_backslash .. "n", magic_backslash .. "n")
	return text
end
function formatAfterGui(text)
	text = text:gsub(magic_backslash .. "n", orig_backslash .. "n")
	return text
end

ftgui = formatBeforeGui

function makeErrorColor(msg)
	local lines = strSplit(string, msg, "\n", true)
	for i, v in ipairs(lines) do
		if i == 1 then
			lines[i] = "#ffffff" .. v
		else
			lines[i] = "#00ff62" .. v
		end
	end
	return table.concat(lines, "\n")
end

function strSplit(tool, str, seps, noYield)
    if type(seps) ~= "table" then
        seps = {seps}
    end
    
    local seplens = {}
    for i, sep in ipairs(seps) do
        --seps[i] = tostring(sep)
        seplens[i] = tool.len(sep)
    end

    local parts = {{}}
    local index = 1
    local strlen = tool.len(str)
    while index <= strlen do
		if not noYield then
			sc.yield()
		end

        while true do
            if not noYield then
                sc.yield()
            end

            local finded = false
            for i, sep in ipairs(seps) do
                if not noYield then
                    sc.yield()
                end
                
                if sep ~= "" and tool.sub(str, index, index + (seplens[i] - 1)) == sep then
                    table.insert(parts, {})
                    index = index + seplens[i]
                    finded = true
                    break
                end
            end
            if not finded then
                break
            end
        end

        table.insert(parts[#parts], tool.sub(str, index, index))
        index = index + 1
    end

    for i, part in ipairs(parts) do
        parts[i] = table.concat(part)
    end

    return parts
end

function strSplitNoYield(tool, str, seps)
    return strSplit(tool, str, seps, true)
end

function createPID(kp, ki, kd, dt)
	kp = kp or 1
	ki = ki or 0
	kd = kd or 0
	dt = dt or 40

	local I = 0
	local prevErr = 0
	return function (target, input)
		local err = target - input
		I = I + (err * dt)
		local D = (err - prevErr) / dt
		prevErr = err
		return (err * kp) + (I * ki) + (D * kd)
	end
end

function freezeDetector(name, callback, ...)
	local clock = os.clock()
	local result = {callback(...)}
	local delta = os.clock() - clock
    if delta > 0.05 then
        print("freezeDetector", name, sm.game.getCurrentTick() % (40 * 5), delta)
    end
	return unpack(result)
end

local findTags = {":", "\"]:"}
function parseErrorLine(msg, computerTag)
	local line
	for _, tag in ipairs(findTags) do
		local strs = strSplitNoYield(string, msg, computerTag .. tag)
		for i, v in ipairs(strs) do
			v = strSplitNoYield(string, v, ":")[1] or v
			line = tonumber(v) or line
		end
		if line then
			break
		end
	end
	return line
end