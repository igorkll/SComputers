function sc_reglib_image()
local sm_color_new = sm.color.new
local string_byte = string.byte
local string_char = string.char
local checkArg = checkArg
local formatColor = sc.formatColor
local concat = table.concat
local type = type

local colorslib = sc.lib_require("colors")

local function customFormatColor(color)
    return formatColor(color, sm.color.new(0, 0, 0, 0), true)
end

local function findPixelDataOffset(bmpData)
    -- Размер заголовка BMP (54 байта)
    local headerSize = 54

    -- Прочитать значение поля bfOffBits из BITMAPFILEHEADER (смещение 10-го байта)
    local bfOffBits = 0
    for i = 1, 4 do
        bfOffBits = bfOffBits + bmpData:byte(10 + i) * 256^(i - 1)
    end

    -- Вычислить смещение пиксельных данных
    local pixelDataOffset = headerSize + bfOffBits

    return pixelDataOffset
end


local function getPaletteFromBMP(filedata)
  local header = string.sub(filedata, 1, 54)

  local paletteOffset = bit.bor(bit.lshift(string.byte(header, 11), 0),
                                 bit.lshift(string.byte(header, 12), 8),
                                 bit.lshift(string.byte(header, 13), 16),
                                 bit.lshift(string.byte(header, 14), 24))

  local palette = {}
  for i = 0, 255 do
    local colorData = string.sub(filedata, paletteOffset + i * 4 + 1, paletteOffset + i * 4 + 4)
    local r, g, b = string.byte(colorData, 1, 3)
    palette[i] = {r, g, b}
  end

  return palette
end


local function colorToBytes(color)
    return string_char(math.floor((color.r * 255) + 0.5)) .. string_char(math.floor((color.g * 255) + 0.5)) ..
    string_char(math.floor((color.b * 255) + 0.5)) .. string_char(math.floor((color.a * 255) + 0.5))
end

local function bytesToColor(bytes)
    --[[
    return sm_color_new(
        string_byte(bytes, 1) / 255,
        string_byte(bytes, 2) / 255,
        string_byte(bytes, 3) / 255,
        string_byte(bytes, 4) / 255
    )
    ]]
    
    if string_byte(bytes, 4) == 0 then
        return
    end
    return colorslib.pack(string_byte(bytes, 1), string_byte(bytes, 2), string_byte(bytes, 3))
end

local function bytesToColorBMP(bytes, palette)
    --[[
    if #bytes == 4 then
        return sm_color_new(
            string_byte(bytes, 3) / 255,
            string_byte(bytes, 2) / 255,
            string_byte(bytes, 1) / 255,
            string_byte(bytes, 4) / 255
        )
    elseif #bytes == 3 then
        return sm_color_new(
            string_byte(bytes, 3) / 255,
            string_byte(bytes, 2) / 255,
            string_byte(bytes, 1) / 255
        )
    elseif #bytes == 1 then
        local r, g, b = unpack(palette[string_byte(bytes)])
        return sm_color_new(
            r / 255,
            g / 255,
            b / 255
        )
    else
        --error("failed to parse " .. tostring(#bytes) .. " bytes: " .. bytes)
        return sm_color_new(
            1,
            0,
            0
        )
    end
    ]]
    if #bytes == 4 then
        if string_byte(bytes, 4) == 0 then
            return
        end
        return colorslib.pack(string_byte(bytes, 3), string_byte(bytes, 2), string_byte(bytes, 1))
    elseif #bytes == 3 then
        return colorslib.pack(string_byte(bytes, 3), string_byte(bytes, 2), string_byte(bytes, 1))
    elseif #bytes == 1 then
        local tbl = palette[string_byte(bytes)]
        return colorslib.pack(tbl[1], tbl[2], tbl[3])
    else
        return 0xff0000
    end
end

local function colorToString(color)
    return tostring(color):sub(1, 6)
end

local redMul = 256 * 256
local greenMul = 256 
local bytePalette = {0x000000, 0x000040, 0x000080, 0x0000BF, 0x0000FF, 0x002400, 0x002440, 0x002480, 0x0024BF, 0x0024FF, 0x004900, 0x004940, 0x004980, 0x0049BF, 0x0049FF, 0x006D00, 0x006D40, 0x006D80, 0x006DBF, 0x006DFF, 0x009200, 0x009240, 0x009280, 0x0092BF, 0x0092FF, 0x00B600, 0x00B640, 0x00B680, 0x00B6BF, 0x00B6FF, 0x00DB00, 0x00DB40, 0x00DB80, 0x00DBBF, 0x00DBFF, 0x00FF00, 0x00FF40, 0x00FF80, 0x00FFBF, 0x00FFFF, 0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x330000, 0x330040, 0x330080, 0x3300BF, 0x3300FF, 0x332400, 0x332440, 0x332480, 0x3324BF, 0x3324FF, 0x334900, 0x334940, 0x334980, 0x3349BF, 0x3349FF, 0x336D00, 0x336D40, 0x336D80, 0x336DBF, 0x336DFF, 0x339200, 0x339240, 0x339280, 0x3392BF, 0x3392FF, 0x33B600, 0x33B640, 0x33B680, 0x33B6BF, 0x33B6FF, 0x33DB00, 0x33DB40, 0x33DB80, 0x33DBBF, 0x33DBFF, 0x33FF00, 0x33FF40, 0x33FF80, 0x33FFBF, 0x33FFFF, 0x3C3C3C, 0x4B4B4B, 0x5A5A5A, 0x660000, 0x660040, 0x660080, 0x6600BF, 0x6600FF, 0x662400, 0x662440, 0x662480, 0x6624BF, 0x6624FF, 0x664900, 0x664940, 0x664980, 0x6649BF, 0x6649FF, 0x666D00, 0x666D40, 0x666D80, 0x666DBF, 0x666DFF, 0x669200, 0x669240, 0x669280, 0x6692BF, 0x6692FF, 0x66B600, 0x66B640, 0x66B680, 0x66B6BF, 0x66B6FF, 0x66DB00, 0x66DB40, 0x66DB80, 0x66DBBF, 0x66DBFF, 0x66FF00, 0x66FF40, 0x66FF80, 0x66FFBF, 0x66FFFF, 0x696969, 0x787878, 0x878787, 0x969696, 0x990000, 0x990040, 0x990080, 0x9900BF, 0x9900FF, 0x992400, 0x992440, 0x992480, 0x9924BF, 0x9924FF, 0x994900, 0x994940, 0x994980, 0x9949BF, 0x9949FF, 0x996D00, 0x996D40, 0x996D80, 0x996DBF, 0x996DFF, 0x999200, 0x999240, 0x999280, 0x9992BF, 0x9992FF, 0x99B600, 0x99B640, 0x99B680, 0x99B6BF, 0x99B6FF, 0x99DB00, 0x99DB40, 0x99DB80, 0x99DBBF, 0x99DBFF, 0x99FF00, 0x99FF40, 0x99FF80, 0x99FFBF, 0x99FFFF, 0xA5A5A5, 0xB4B4B4, 0xC3C3C3, 0xCC0000, 0xCC0040, 0xCC0080, 0xCC00BF, 0xCC00FF, 0xCC2400, 0xCC2440, 0xCC2480, 0xCC24BF, 0xCC24FF, 0xCC4900, 0xCC4940, 0xCC4980, 0xCC49BF, 0xCC49FF, 0xCC6D00, 0xCC6D40, 0xCC6D80, 0xCC6DBF, 0xCC6DFF, 0xCC9200, 0xCC9240, 0xCC9280, 0xCC92BF, 0xCC92FF, 0xCCB600, 0xCCB640, 0xCCB680, 0xCCB6BF, 0xCCB6FF, 0xCCDB00, 0xCCDB40, 0xCCDB80, 0xCCDBBF, 0xCCDBFF, 0xCCFF00, 0xCCFF40, 0xCCFF80, 0xCCFFBF, 0xCCFFFF, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0, 0xFF0000, 0xFF0040, 0xFF0080, 0xFF00BF, 0xFF00FF, 0xFF2400, 0xFF2440, 0xFF2480, 0xFF24BF, 0xFF24FF, 0xFF4900, 0xFF4940, 0xFF4980, 0xFF49BF, 0xFF49FF, 0xFF6D00, 0xFF6D40, 0xFF6D80, 0xFF6DBF, 0xFF6DFF, 0xFF9200, 0xFF9240, 0xFF9280, 0xFF92BF, 0xFF92FF, 0xFFB600, 0xFFB640, 0xFFB680, 0xFFB6BF, 0xFFB6FF, 0xFFDB00, 0xFFDB40, 0xFFDB80, 0xFFDBBF, 0xFFDBFF, 0xFFFF00, 0xFFFF40, 0xFFFF80, 0xFFFFBF, 0xFFFFFF}
local function colorToByte(color)
    local color24Bit = (math.floor(color.r * 255) * redMul) + (math.floor(color.g * 255) * greenMul) + math.floor(color.b * 255)
    local closestDelta, closestIndex, delta, paletteColor, paletteR, paletteG, paletteB = math.huge, 1

    local r = color24Bit / 65536
    r = r - r % 1
    
    local g = (color24Bit - r * 65536) / 256
    g = g - g % 1
    
    local b = color24Bit - r * 65536 - g * 256

    for index = 1, #bytePalette do
        paletteColor = bytePalette[index]
        
        if color24Bit == paletteColor then
            return index - 1
        else
            paletteR = paletteColor / 65536
            paletteR = paletteR - paletteR % 1
            paletteG = (paletteColor - paletteR * 65536) / 256
            paletteG = paletteG - paletteG % 1
            paletteB = paletteColor - paletteR * 65536 - paletteG * 256

            delta = (paletteR - r) ^ 2 + (paletteG - g) ^ 2 + (paletteB - b) ^ 2
            
            if delta < closestDelta then
                closestDelta, closestIndex = delta, index
            end
        end
    end

    return closestIndex - 1
end

local function byteToColor(byte)
    return bytePalette[byte + 1]
end

-----------------------------------

local image = {}

local function addMethods(img)
    img.draw = image.draw
    img.getSize = image.getSize
    img.set = image.set
    img.get = image.get
    img.rawGet = image.rawGet
    img.encode = image.encode
    img.encode8 = image.encode8
    img.save = image.save
    img.save8 = image.save8
    img.drawForTicks = image.drawForTicks
    img.fromCamera = image.fromCamera
    img.fromCameraAll = image.fromCameraAll
end

-----------------------------------

function image.encode(img)
    if img.x > 256 then return error("resolution x greater than 256", 2) end
    if img.y > 256 then return error("resolution y greater than 256", 2) end

    local data = ""
    data = data .. string_char(img.x - 1)
    data = data .. string_char(img.y - 1)

    local datas = {}
    local i = 1
    for y = 0, img.y - 1 do
        for x = 0, img.x - 1 do
            sc.smartYield()
            datas[i] = colorToBytes(customFormatColor(img.data[x + (y * img.x)]))
            i = i + 1
        end
    end

    return data .. concat(datas)
end

function image.encode8(img)
    if img.x > 256 then return error("resolution x greater than 256", 2) end
    if img.y > 256 then return error("resolution y greater than 256", 2) end

    local data = ""
    data = data .. string_char(img.x - 1)
    data = data .. string_char(img.y - 1)

    local datas = {}
    local i = 1
    for y = 0, img.y - 1 do
        for x = 0, img.x - 1 do
            sc.smartYield()
            datas[i] = string_char(colorToByte(customFormatColor(img.data[x + (y * img.x)])))
            i = i + 1
        end
    end

    return data .. concat(datas)
end

function image.decode(data)
    local resX, resY = data:byte(1) + 1, data:byte(2) + 1

    local img = {x = resX, y = resY, data = {}, datamax = (resX - 1) + ((resY - 1) * resX)}
    local i = 3
    for y = 0, resY - 1 do
        for x = 0, resX - 1 do
            sc.smartYield()
            img.data[x + (y * resX)] = bytesToColor(data:sub(i, i + 3))
            i = i + 4
        end
    end
    addMethods(img)
    return img
end

function image.decode8(data)
    local resX, resY = data:byte(1) + 1, data:byte(2) + 1

    local img = {x = resX, y = resY, data = {}, datamax = (resX - 1) + ((resY - 1) * resX)}
    local i = 3
    for y = 0, resY - 1 do
        for x = 0, resX - 1 do
            sc.smartYield()
            img.data[x + (y * resX)] = byteToColor(data:byte(i))
            i = i + 1
        end
    end
    addMethods(img)
    return img
end

function image.decodeBmp(bmp_content)
    local bmp_header = bmp_content:sub(1, 54)

    local resX = string.byte(bmp_header, 19) + bit.lshift(string.byte(bmp_header, 20), 8) + bit.lshift(string.byte(bmp_header, 21), 16) + bit.lshift(string.byte(bmp_header, 22), 24)
    local resY = string.byte(bmp_header, 23) + bit.lshift(string.byte(bmp_header, 24), 8) + bit.lshift(string.byte(bmp_header, 25), 16) + bit.lshift(string.byte(bmp_header, 26), 24)
    local bpp = string.byte(bmp_header, 29) + bit.lshift(string.byte(bmp_header, 30), 8)
   
    local startRead, palette
    if bpp == 8 then bpp = -1 end --8 bit depth tempory unavailable
    if bpp == 32 then
        startRead = 54 + (4 * 24)
    elseif bpp == 24 then
        startRead = 54
    elseif bpp == 8 then
        startRead = 54 + (3 * 24)
        palette = getPaletteFromBMP(bmp_content)
    else
        error("not supported color depth, supported only: 32, 24", 2)
    end
    startRead = startRead + 1
    local colorbytes = bpp / 8

    local img = {x = resX, y = resY, data = {}, datamax = (resX - 1) + ((resY - 1) * resX)}
    local i = startRead

    for y = resY - 1, 0, -1 do
        for x = 0, resX - 1 do
            sc.smartYield()
            local str = bmp_content:sub(i, i + (colorbytes - 1))
            img.data[x + (y * resX)] = bytesToColorBMP(str, palette)
            i = i + colorbytes
        end

        local rowLength = resX * colorbytes
        local padding = (4 - (rowLength % 4)) % 4
        i = i + padding
    end
    addMethods(img)
    return img
end

-----------------------------------

function image.new(resX, resY, color)
    checkArg(1, resX, "number")
    checkArg(2, resY, "number")
    checkArg(3, color, "Color", "number", "string", "nil")

    local img = {x = resX, y = resY, data = {}, datamax = (resX - 1) + ((resY - 1) * resX)}
    for y = 0, resY - 1 do
        for x = 0, resX - 1 do
            sc.smartYield()
            img.data[x + (y * resX)] = color
        end
    end
    addMethods(img)
    return img
end

function image.load(disk, path)
    checkArg(1, disk, "table")
    checkArg(2, path, "string")

    local extension = string.find(path, "%.[^%.]*$")
    if extension then
        extension = string.sub(path, extension + 1)
    end
    local data = disk.readFile(path)
    if extension == "bmp" then
        return image.decodeBmp(data)
    elseif extension == "scimg8" then
        return image.decode8(data)
    else
        return image.decode(data)
    end 
end

function image.save(img, disk, path)
    checkArg(1, img, "table")
    checkArg(2, disk, "table")
    checkArg(3, path, "string")

    if not disk.hasFile(path) then
        disk.createFile(path)
    end
    return disk.writeFile(path, image.encode(img))
end

function image.save8(img, disk, path)
    checkArg(1, img, "table")
    checkArg(2, disk, "table")
    checkArg(3, path, "string")

    if not disk.hasFile(path) then
        disk.createFile(path)
    end
    return disk.writeFile(path, image.encode8(img))
end

-----------------------------------

local function needDrawColor(color)
    return color and (type(color) ~= "Color" or color.a > 0)
end

function image.draw(img, display, posX, posY)
    checkArg(1, img, "table")
    checkArg(2, display, "table")
    checkArg(3, posX, "number", "nil")
    checkArg(4, posY, "number", "nil")
    posX = posX or 0
    posY = posY or 0

    for y = 0, img.y - 1 do
        for x = 0, img.x - 1 do
            sc.smartYield()
            local color = img.data[x + (y * img.x)]
            if needDrawColor(color) then
                display.drawPixel(posX + x, posY + y, color)
            end
        end
    end
end

function image.drawForTicks(img, display, ticks, posX, posY)
    checkArg(1, img, "table")
    checkArg(2, display, "table")
    checkArg(3, ticks, "number", "nil")
    checkArg(4, posX, "number", "nil")
    checkArg(5, posY, "number", "nil")
    ticks = ticks or 40
    posX = posX or 0
    posY = posY or 0
    if ticks < 1 then error("ticks < 1", 2) end

    local pixelForDraw = math.floor(((img.x * img.y) / ticks) + 0.5)
    local currentPixel = 0

    return function ()
        for i = 1, pixelForDraw do
            sc.smartYield()

            if currentPixel > img.datamax then return true end
            local color = img.data[currentPixel]

            if needDrawColor(color) then
                local x = currentPixel % img.x
                local y = math.floor(currentPixel / img.x)
                display.drawPixel(posX + x, posY + y, color)
            end

            currentPixel = currentPixel + 1
        end
    end
end

function image.getSize(img)
    checkArg(1, img, "table")
    return img.x, img.y
end

function image.set(img, x, y, color)
    checkArg(1, img, "table")
    checkArg(2, x, "number")
    checkArg(3, y, "number")
    checkArg(4, color, "Color", "number", "string", "nil")
    if x < 0 or x >= img.x then error("invalid pixel pos", 2) end
    if y < 0 or y >= img.y then error("invalid pixel pos", 2) end
    img.data[x + (y * img.x)] = color
end

function image.get(img, x, y)
    checkArg(1, img, "table")
    checkArg(2, x, "number")
    checkArg(3, y, "number")
    if x < 0 or x >= img.x then error("invalid pixel pos", 2) end
    if y < 0 or y >= img.y then error("invalid pixel pos", 2) end
    return customFormatColor(img.data[x + (y * img.x)])
end

function image.rawGet(img, x, y)
    checkArg(1, img, "table")
    checkArg(2, x, "number")
    checkArg(3, y, "number")
    if x < 0 or x >= img.x then error("invalid pixel pos", 2) end
    if y < 0 or y >= img.y then error("invalid pixel pos", 2) end
    return img.data[x + (y * img.x)]
end

function image.fromCamera(img, camera, methodName, ...)
    checkArg(1, img, "table")
    checkArg(2, camera, "table")
    checkArg(3, methodName, "string")

    local v_x, v_y, v_sizeX, v_sizeY = camera.getViewport()
    camera.setViewport()
    local sx, sy, data = img.x, img.y, img.data
    local vdisplay = {
        noCameraEncode = true,
        getWidth = function ()
            return sx
        end,
        getHeight = function ()
            return sy
        end,
        drawPixel = function (x, y, color)
            data[x + (y * sx)] = color
        end
    }
    camera[methodName](vdisplay, ...)
    camera.setViewport(v_x, v_y, v_sizeX, v_sizeY)
end

function image.fromCameraAll(img, camera, methodName, ...)
    checkArg(1, img, "table")
    checkArg(2, camera, "table")
    checkArg(3, methodName, "string")

    local v_x, v_y, v_sizeX, v_sizeY = camera.getViewport()
    camera.setViewport()
    camera.resetCounter()
    local oldStep = camera.getStep()
    camera.setStep(img.y)

    local notEnd = true
    local notStart
    local sx, sy, data = img.x, img.y, img.data
    local vdisplay = {
        noCameraEncode = true,
        getWidth = function ()
            return sx
        end,
        getHeight = function ()
            return sy
        end,
        drawPixel = function (x, y, color)
            if x ~= 0 or y ~= 0 then
                notStart = true
            end
            if notStart and x == 0 and y == 0 then
                notEnd = false
            end
            
            data[x + (y * sx)] = color
        end
    }

    local i = 0
    while notEnd do
        sc.smartYield()
        i = i + 1
        camera[methodName](vdisplay, ...)
    end

    camera.setStep(oldStep)
    camera.setViewport(v_x, v_y, v_sizeX, v_sizeY)
end

-----------------------------------

return image
end