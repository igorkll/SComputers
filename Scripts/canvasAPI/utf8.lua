local bit		= bit
local error		= error
local ipairs	= ipairs
local string	= string
local table		= table
local unpack	= unpack
local table_concat = table.concat
local string_sub = string.sub
local string_byte = string.byte
local bit_bor = bit.bor
local bit_band = bit.band
local string_char = string.char
local bit_rshift = bit.rshift
local bit_lshift = bit.lshift
local table_insert = table.insert

--
-- Pattern that can be used with the string library to match a single UTF-8 byte-sequence.
-- This expects the string to contain valid UTF-8 data.
--
--charpattern = "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"

--
-- Transforms indexes of a string to be positive.
-- Negative indices will wrap around like the string library's functions.
--
local function strRelToAbs( str, ... )
	local args = { ... }

	for k, v in ipairs( args ) do
		v = v > 0 and v or #str + v + 1

		if v < 1 or v > #str then
			error( "bad index to string (out of range)", 3 )
		end

		args[ k ] = v
	end

	return unpack(args)
end

-- Decodes a single UTF-8 byte-sequence from a string, ensuring it is valid
-- Returns the index of the first and last character of the sequence
--
local function decode( str, startPos )

	startPos = strRelToAbs( str, startPos or 1 )

	local b1 = string_byte(str, startPos, startPos )

	-- Single-byte sequence
	if b1 < 0x80 then
		return startPos, startPos
	end

	-- Validate first byte of multi-byte sequence
	if b1 > 0xF4 or b1 < 0xC2 then
		return
	end

	-- Get 'supposed' amount of continuation bytes from primary byte
	local contByteCount =	b1 >= 0xF0 and 3 or
							b1 >= 0xE0 and 2 or
							b1 >= 0xC0 and 1

	local endPos = startPos + contByteCount

	-- Validate our continuation bytes
	for _, bX in ipairs { string_byte(str, startPos + 1, endPos ) } do
		if bit_band( bX, 0xC0 ) ~= 0x80 then
			return
		end
	end

	return startPos, endPos 

end

--
-- Takes zero or more integers and returns a string containing the UTF-8 representation of each
--
local function char( ... )

	local bufn = 1
	local buf = {}
	local b1, b2, b3, b4 = nil, nil, nil, nil

	for k, v in ipairs { ... } do
		if v < 0 or v > 0x10FFFF then
			error( "bad argument #" .. k .. " to char (out of range)", 2 )
		end

		b1, b2, b3, b4 = nil, nil, nil, nil

		if v < 0x80 then -- Single-byte sequence
			buf[bufn] = string_char( v )
			bufn = bufn + 1
		elseif v < 0x800 then -- Two-byte sequence
			b1 = bit_bor( 0xC0, bit_band( bit_rshift( v, 6 ), 0x1F ) )
			b2 = bit_bor( 0x80, bit_band( v, 0x3F ) )

			buf[bufn] = string_char( b1, b2 )
			bufn = bufn + 1
		elseif v < 0x10000 then -- Three-byte sequence

			b1 = bit_bor( 0xE0, bit_band( bit_rshift( v, 12 ), 0x0F ) )
			b2 = bit_bor( 0x80, bit_band( bit_rshift( v, 6 ), 0x3F ) )
			b3 = bit_bor( 0x80, bit_band( v, 0x3F ) )

			buf[bufn] = string_char( b1, b2, b3 )
			bufn = bufn + 1
		else -- Four-byte sequence

			b1 = bit_bor( 0xF0, bit_band( bit_rshift( v, 18 ), 0x07 ) )
			b2 = bit_bor( 0x80, bit_band( bit_rshift( v, 12 ), 0x3F ) )
			b3 = bit_bor( 0x80, bit_band( bit_rshift( v, 6 ), 0x3F ) )
			b4 = bit_bor( 0x80, bit_band( v, 0x3F ) )

			buf[bufn] = string_char( b1, b2, b3, b4 )
			bufn = bufn + 1
		end
	end

	return table_concat(buf, "")
end

--
-- Iterates over a UTF-8 string similarly to pairs
-- k = index of sequence, v = string value of sequence
--
local function codes( str )
	local i = 1
	local startPos, endPos
	return function()
		-- Have we hit the end of the iteration set?
		if i > #str then
			return
		end

		startPos, endPos = decode( str, i )

		if not startPos then
			error( "invalid UTF-8 code", 2 )
		end

		i = endPos + 1

		return startPos, string_sub(str, startPos, endPos)
	end
end

--
-- Returns an integer-representation of the UTF-8 sequence(s) in a string
-- startPos defaults to 1, endPos defaults to startPos
--
local function codepoint( str, startPos, endPos )

	startPos, endPos = strRelToAbs( str, startPos or 1, endPos or startPos or 1 )

	local ret = {}
	local seqStartPos, seqEndPos
	local len, b1, cp, bX

	repeat
		seqStartPos, seqEndPos = decode( str, startPos )

		if not seqStartPos then
			error( "invalid UTF-8 code", 2 )
		end

		-- Increment current string index
		startPos = seqEndPos + 1

		-- Amount of bytes making up our sequence
		len = seqEndPos - seqStartPos + 1

		if len == 1 then -- Single-byte codepoint

			table_insert( ret, string_byte(str, seqStartPos))

		else -- Multi-byte codepoint

			b1 = string_byte(str, seqStartPos )
			cp = 0

			for i = seqStartPos + 1, seqEndPos do

				bX = string_byte(str, i )

				cp = bit_bor( bit_lshift( cp, 6 ), bit_band( bX, 0x3F ) )
				b1 = bit_lshift( b1, 1 )

			end

			cp = bit_bor( cp, bit_lshift( bit_band( b1, 0x7F ), ( len - 1 ) * 5 ) )

			table_insert( ret, cp )

		end
	until seqEndPos >= endPos

	return unpack( ret )

end

--
-- Returns the length of a UTF-8 string. false, index is returned if an invalid sequence is hit
-- startPos defaults to 1, endPos defaults to -1
--
local function len( str, startPos, endPos )
    if #str == 0 then return 0 end
	startPos, endPos = strRelToAbs( str, startPos or 1, endPos or -1 )

	local len, seqStartPos, seqEndPos = 0
	repeat
		seqStartPos, seqEndPos = decode( str, startPos )

		-- Hit an invalid sequence?
		if not seqStartPos then
			return false, startPos
		end

		-- Increment current string pointer
		startPos = seqEndPos + 1

		-- Increment length
		len = len + 1
	until seqEndPos >= endPos

	return len
end

--
-- Returns the byte-index of the n'th UTF-8-character after the given byte-index (nil if none)
-- startPos defaults to 1 when n is positive and -1 when n is negative
-- If 0 is zero, this function instead returns the byte-index of the UTF-8-character startPos lies within.
--
local function offset( str, n, startPos )

	startPos = strRelToAbs( str, startPos or ( n >= 0 and 1 ) or #str )

	-- Find the beginning of the sequence over startPos
	if n == 0 then
		local seqStartPos, seqEndPos
		for i = startPos, 1, -1 do
			seqStartPos, seqEndPos = decode( str, i )

			if seqStartPos then
				return seqStartPos
			end
		end
		return
	end

	if not decode( str, startPos ) then
		error( "initial position is not beginning of a valid sequence", 2 )
	end

	local itStart, itEnd, itStep = nil, nil, nil

	if n > 0 then -- Find the beginning of the n'th sequence forwards
		itStart = startPos
		itEnd = #str
		itStep = 1
	else -- Find the beginning of the n'th sequence backwards
		n = -n
		itStart = startPos
		itEnd = 1
		itStep = -1
	end

	local seqStartPos
	for i = itStart, itEnd, itStep do
		seqStartPos = decode( str, i )

		if seqStartPos then
			n = n - 1

			if n == 0 then
				return seqStartPos
			end
		end
	end
end

--
-- Forces a string to contain only valid UTF-8 data.
-- Invalid sequences are replaced with U+FFFD.
--
local function force( str )
	local bufn = 1
	local buf = {}

	local curPos, endPos = 1, #str

	local seqStartPos, seqEndPos
	repeat
		seqStartPos, seqEndPos = decode( str, curPos )

		if seqStartPos then
			buf[bufn] = string_sub(str, seqStartPos, seqEndPos )
			bufn = bufn + 1

			curPos = seqEndPos + 1
		else
			buf[bufn] = char( 0xFFFD )
			bufn = bufn + 1
			
			curPos = curPos + 1
		end
	until curPos > endPos

	return table_concat( buf, "" )
end






-----------------------------------------------

utf8 = {}
utf8.force = force
utf8.offset = offset
utf8.len = len
utf8.codepoint = codepoint
utf8.codes = codes
utf8.char = char

function utf8.sub(text, i, j)
	local charsn = 1
    local chars = {}
    for _, code in codes(text) do
        chars[charsn] = code
		charsn = charsn + 1
    end

    return table_concat({unpack(chars, i, j)})
end

function utf8.code(str, i)
	local charsn = 1
	for _, code in codes(str) do
		if charsn == i then
			return code
		end
		charsn = charsn + 1
    end
end