local canvasGUI = {}
canvasGUI.jsonGuiSetup = { isInteractive = true, needsCursor = true }
canvasGUI.additionalPixelSize = 2

local math_floor = math.floor

local function lFormatColor(color)
    local r, g, b = math_floor(color / 256 / 256) / 255, (math_floor(color / 256) % 256) / 255, (color % 256) / 255
    return r .. " " .. g .. " " .. b
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

    local index = 1
    for iy = 0, ry - 1 do
        for ix = 0, rx - 1 do
            local addSizeX = canvasGUI.additionalPixelSize
            local addSizeY = canvasGUI.additionalPixelSize
            if ix == (rx - 1) then
                addSizeX = 0
            end
            if iy == (ry - 1) then
                addSizeY = 0
            end
            guiTable.Childs[index] = {
                ["Skin"] = "WhiteSkin",
                ["Type"] = "Widget",
                ["Colour"] = "0 0 0",
                ["x"] = (ix * pixelSizeX) + padding,
                ["y"] = (iy * pixelSizeY) + padding,
                ["width"] = pixelSizeX + addSizeX,
                ["height"] = pixelSizeY + addSizeY
            }
            index = index + 1
        end
    end

    if title then
        table.insert(guiTable.Childs, {
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
        })
    end

    return guiTable
end

function canvasGUI.createGuiCanvas(rx, ry, width, height, padding, title)
    local buffer = {}
    local bufferBase = 0x000000

    local guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding, title)
    local guiInstance

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
            buffer = {}
            bufferBase = color
            guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding, title)
            api.flush()
        end,
        clear = function(color)
            buffer = {}
            bufferBase = color
        end,
        setPixel = function(x, y, str)
            guiTable.Childs[x + (y * rx) + 1]["Colour"] = str
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