print("canvas: loading fonts...")

font = {}
font.fonts = {}
font.fontIndex = 1
font.fontsOptimized = {}

dofile("$CONTENT_DATA/Scripts/canvasAPI/fonts/manual_fonts.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/fonts/converted_fonts.lua")
dofile("$CONTENT_DATA/Scripts/canvasAPI/fonts/generated_fonts.lua")

---------------------------------------------------

local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local string_byte = string.byte

function font.optimizeFont(lfont)
    local optimized = {}
	optimized.returnWidth = lfont.returnWidth
	optimized.returnHeight = lfont.returnHeight
	if lfont.mono or lfont.mono == nil then
		optimized.width = lfont.width
		optimized.height = lfont.height
		optimized.mono = true

		local pixels
		local chr
		for k, v in pairs(lfont.chars) do
			pixels = {}

			for ix = lfont.width, 1, -1 do
				for iy = #v, 1, -1 do
					chr = v[iy]:sub(ix, ix)
					if chr == "1" then
						table_insert(pixels, ix-1)
						table_insert(pixels, iy-1)
					end
				end
			end

			optimized[k] = pixels
			if #k == 1 then
				optimized[string_byte(k)] = pixels
			end
		end
	else
		if not optimized.spaceSize then
			local getSizeChar = lfont.chars[" "] or lfont.chars["a"] or lfont.chars["A"] or lfont.chars["8"]
			if not getSizeChar then
				for i, v in ipairs(lfont.chars) do
					getSizeChar = v
					break
				end
			end
			if getSizeChar and getSizeChar[1] then
				optimized.spaceSize = #getSizeChar[1]
			end
			if not optimized.spaceSize or optimized.spaceSize == 0 then
				optimized.spaceSize = 5
			end
		end

		local upperFont = 0
		for k, v in pairs(lfont.chars) do
			if not v.processed then
				if not v.width then
					v.width = (v[1] and #v[1]) or 0
				end
				if not v.height then
					v.height = #v
				end
				v.origWidth = v.width
				v.origHeight = v.height
				v.lOffsetX = v.offsetX
				v.lOffsetY = -v.offsetY
				v.width = v.width + math.abs(v.offsetX)
				v.height = v.height + math.abs(v.offsetY)
				if v.lOffsetY > upperFont then
					upperFont = v.lOffsetY
				end
				v.processed = true
			end
		end

		if not optimized.width then
			optimized.width = 0
			for k, v in pairs(lfont.chars) do
				if v.width > optimized.width then
					optimized.width = v.width
				end
			end
		end

		if not optimized.height then
			optimized.height = 0
			for k, v in pairs(lfont.chars) do
				if v.height > optimized.height then
					optimized.height = v.height
				end
			end
		end

		for k, v in pairs(lfont.chars) do
			local pixels = {}
			pixels[0] = v.width

			local addWidth = 0
			local addHeight = (optimized.height - v.origHeight) - upperFont

			for iy, w in ipairs(v) do
				for ix = 1, #w do
					local chr = w:sub(ix, ix)
					if chr == "1" then
						table_insert(pixels, (ix - 1) + addWidth + v.lOffsetX)
						table_insert(pixels, (iy - 1) + addHeight + v.lOffsetY)
					end
				end
			end

			optimized[k] = pixels
			if #k == 1 then
				optimized[string_byte(k)] = pixels
			end
		end
	end
    return optimized
end

---------------------------------------------------

font.fontsOptimized = {}
for i, fdata in ipairs(font.fonts) do
    font.fontsOptimized[i] = font.optimizeFont(fdata)
end

font.default = font.fonts[1]
font.optimized = font.fontsOptimized[1]