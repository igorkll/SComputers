local canvasGUI = {}
canvasGUI.jsonGuiSetup = { isInteractive = true, needsCursor = true }

function canvasGUI.createGuiTable(rx, ry, width, height, padding)
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
            guiTable.Childs[index] = {
                ["Skin"] = "WhiteSkin",
                ["Type"] = "Widget",
                ["Colour"] = "0 0 0",
                ["x"] = (ix * pixelSizeX) + padding,
                ["y"] = (iy * pixelSizeY) + padding,
                ["width"] = pixelSizeX + 2,
                ["height"] = pixelSizeY + 2
            }
            index = index + 1
        end
    end

    return guiTable
end

function canvasGUI.createGuiCanvas(rx, ry, width, height, padding)
    local guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding)
    local guiInstance

    local api
    api = {
        update = function(delta)

        end,
        open = function()
            if not guiInstance then
                guiInstance = sm.jsonGui.createGui(canvasGUI.jsonGuiSetup)
            end
            guiInstance:render(guiTable)
        end,
        close = function()
            if guiInstance and guiInstance:isActive() then
                guiInstance:close()
            end
        end,
        destroy = function()
            api.close()
        end,
        isOpened = function()
            if guiInstance and guiInstance:isActive() then
                return true
            end
            return false
        end,

        resize = function(nrx, nry)
            rx, ry = nrx, nry
            guiTable = canvasGUI.createGuiTable(rx, ry, width, height, padding)
            if guiInstance and guiInstance:isActive() then
                guiInstance:render(guiTable)
            end
        end,
        setPixel = function(x, y, str)
            guiTable[x + (y * nrx) + 1] = str
        end
    }
    return api
end

_G.canvasGUI = canvasGUI