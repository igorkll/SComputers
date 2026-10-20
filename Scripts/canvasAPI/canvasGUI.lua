local canvasGUI = {}
canvasGUI.jsonGuiSetup = { isInteractive = true, needsCursor = true }
canvasGUI.additionalPixelSize = 2

local math_floor = math.floor
local table_insert = table.insert

local function lFormatColor(color)
    local r, g, b = math_floor(color / 256 / 256) / 255, (math_floor(color / 256) % 256) / 255, (color % 256) / 255
    return table.concat({r, " ", g, " ", b})
end

function canvasGUI.createGuiTable(rx, ry, width, height, padding, title)
    local guiTable = {
        ["Anchor"] = "Center",
        ["Childs"] = {},
        ["InheritsPick"] = true,
        ["Name"] = "BackPanel",
        ["NeedKey"] = false,
        ["NeedMouse"] = false,
        ["Skin"] = "BackgroundInteractableWide",
        ["Type"] = "Widget",

        ["x"] = 0,
        ["y"] = 0,
        ["width"] = width,
        ["height"] = height
    }

    local padWidth = width - (padding * 2)
    local padHeight = height - (padding * 2)
    local pixelSizeX = padWidth / rx
    local pixelSizeY = padHeight / ry

    guiTable.Childs[1] = {
        ["Skin"] = "WhiteSkin",
        ["Type"] = "Widget",
        ["Colour"] = "0 0 0",
        ["x"] = 0 + padding,
        ["y"] = 0 + padding,
        ["width"] = pixelSizeX * rx,
        ["height"] = pixelSizeY * ry
    }

    guiTable.Childs[2] = {
        ["Caption"] = title,
        ["FontName"] = "SM_HeaderTiny",
        ["Skin"] = "TextBox",
        ["TextAlign"] = "Center",
        ["TextColour"] = "1 1 1",
        ["Type"] = "TextBox",
        ["height"] = padding,
        ["width"] = width,
        ["x"] = 0,
        ["y"] = 0
    }

    return guiTable
end

function canvasGUI.createGuiCanvas(rx, ry, width, height, padding, title)
    local buffer = {}
    local bufferBase = 0x000000

    local guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding, title)
    local guiTableChildsMax = 2 + (rx * ry)
    local guiTableInfo = {}
    local guiInstance

    local function childInsert(tbl)
        for i = 3, math.huge do
            if guiTable.Childs[i] == nil then
                guiTable.Childs[i] = tbl
                return i
            end
        end
    end

    local function setDot(x, y, color)
        local padWidth = width - (padding * 2)
        local padHeight = height - (padding * 2)
        local pixelSizeX = padWidth / rx
        local pixelSizeY = padHeight / ry

        local idx = x + (y * rx)
        local currentRect = guiTableInfo[idx]

        if currentRect then
            if currentRect[3] > 1 or currentRect[4] > 1 then

            end

            if color == bufferBase then
                guiTableInfo[idx] = nil
                
            else
                currentRect[5] = color
                guiTable.Childs[currentRect[6]]["Colour"] = lFormatColor(color)
            end
        else
            local guiTableIdx = childInsert({
                ["Skin"] = "WhiteSkin",
                ["Type"] = "Widget",
                ["Colour"] = lFormatColor(color),
                ["x"] = (x * pixelSizeX) + padding,
                ["y"] = (y * pixelSizeY) + padding,
                ["width"] = pixelSizeX + canvasGUI.additionalPixelSize,
                ["height"] = pixelSizeY + canvasGUI.additionalPixelSize
            })

            guiTableInfo[idx] = {x, y, 1, 1, color, guiTableIdx}
        end
    end

    local api
    api = {
        update = function()

        end,
        open = function()
            if not guiInstance then
                guiInstance = sm.jsonGui.createGui(canvasGUI.jsonGuiSetup)
            end
            guiInstance:render(guiTable)
        end,
        close = function()
            if api.isRendering() then
                guiInstance:close()
            end
        end,
        destroy = function()
            api.close()
        end,
        isRendering = function()
            if guiInstance and guiInstance:isActive() then
                return true
            end
            return false
        end,

        resize = function(nrx, nry)
            rx, ry = nrx, nry
            guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding, title)
            guiTableChildsMax = 2 + (rx * ry)
            guiTableInfo = {}
            api.clear(0)
            api.flush()
        end,
        clear = function(color)
            buffer = {}
            bufferBase = color
            guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding, title)
            guiTable.Childs[1]["Colour"] = lFormatColor(color)
        end,
        setPixel = function(x, y, color)
            local idx = x + (y * rx)
            if color ~= buffer[idx] then
                setDot(x, y, color)
                buffer[idx] = color
            end
        end,
        flush = function()
            if api.isRendering() then
                guiInstance:render(guiTable)
            end
        end
    }
    return api
end

_G.canvasGUI = canvasGUI