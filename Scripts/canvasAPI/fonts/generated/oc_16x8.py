alphabet = ''.join(chr(i) for i in range(256)) + "абвгдеёжзийклмнопрстуфхцчшщьыъэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯ" + "…⎯💫📌📂❌⛌🗓🖹🗘⇲⇊💻🌍📷➕🗎👁𝕩✂⧉📦🖊⭐🥰😭😎🥺🤔🤓🛒🛈─━│┃┄┅┆┇┈┉┊┋┌┍┎┏┐┑┒┓└┕┖┗┘┙┚┛├┝┞┟┠┡┢┣┤┥┦┧┨┩┪┫┬┭┮┯┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋╌╍╎╏═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬╭╮╯╰╱╲╳╴╵╶╷╸╹╺╻╼╽╾╿▀▁▂▃▄▅▆▇█▉▊▋▌▍▎▏▐░▒▓▔▕▖▗▘▙▚▛▜▝▞▟◣◢•⚫∙⬤◖◗▲ ▼ ▽ △ ◥◤◢◣"

def findChar(char):
	prefix = format(ord(char), '04X') + ":"
	with open("oc_16x8.hex", 'r', encoding='utf-8') as file:
		for line in file:
			if line.startswith(prefix):
				return line
	return None

def convertChar(hex_string):
    hex_string = hex_string.strip().upper()
    byte_array = bytearray(int(hex_string[i:i+2], 16) for i in range(0, len(hex_string), 2))
    return byte_array

def to_lua_string(input_string):
    lua_string = ""
    for char in input_string:
        code = ord(char)
        if code < 32 or code == 127:
            lua_string += f"\\{code}"
        elif char == '"':
            lua_string += '\\"'
        elif char == '\\':
            lua_string += '\\\\'
        else:
            lua_string += char
    return "\"" + lua_string + "\""

def readCharLine(i, binchar, charlen):
	if charlen >= 32:
		return format(binchar[i*2], '08b').replace('0', '.') + format(binchar[(i*2)+1], '08b').replace('0', '.')
	else:
		return format(binchar[i], '08b').replace('0', '.')

with open("oc_16x8.hex", 'r', encoding='utf-8') as file:
	with open("oc_16x8.lua", 'w') as lua:
		lua.write("font.fonts.oc_16x8 = {\n")
		lua.write("  mono = false,\n")
		lua.write("  returnWidth = 8,\n")
		lua.write("  returnHeight = 16,\n")
		lua.write("  width = 8,\n")
		lua.write("  height = 16,\n")
		lua.write("  chars = {\n")

		for _chr in alphabet:
			line = findChar(_chr)
			unicode_code, data = line.split(":")
			char = chr(int(unicode_code, 16))

			binchar = convertChar(data)
			charlen = len(binchar)

			lua.write("    [" + to_lua_string(char) + "] = {\n")
			lua.write(f"        width = {int(charlen / 2)},\n")
			lua.write("        height = 16,\n")
			lua.write("        offsetX = 0,\n")
			lua.write("        offsetY = 0,\n")
			for i in range(16):
				charline = readCharLine(i, binchar, charlen)
				if i == 15:
					lua.write("        \"" + charline + "\"\n")
				else:
					lua.write("        \"" + charline + "\",\n")
			lua.write("    },\n")

		lua.write("  }\n")
		lua.write("}\n")

		lua.write("\n")
		lua.write("font.fonts.oc_16x8.index = font.fontIndex\n")
		lua.write("font.fonts[font.fontIndex] = font.fonts.oc_16x8\n")
		lua.write("font.fontIndex = font.fontIndex + 1\n")