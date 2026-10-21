local canvasGUI = {}
canvasGUI.jsonGuiSetup = { isInteractive = true, needsCursor = true }
canvasGUI.jsonGuiSetup_hud = { isHud = true, isInteractive = false, needsCursor = false }
canvasGUI.additionalPixelSize = 1
canvasGUI.debugCanvas = false

local math_floor = math.floor

local colorStringCache = {}
local colorStringCacheSize = 0
local function lFormatColor(color)
    local cached = colorStringCache[color]
    if cached then return cached end
    if colorStringCacheSize > 4096 then
        colorStringCache = {}
        colorStringCacheSize = 0
    end
    local r = math_floor(color / 65536) / 255
    local g = (math_floor(color / 256) % 256) / 255
    local b = (color % 256) / 255
    local s = r .. " " .. g .. " " .. b
    colorStringCache[color] = s
    colorStringCacheSize = colorStringCacheSize + 1
    return s
end

function canvasGUI.createGuiTable(x, y, rx, ry, width, height, padding, title, anchor)
    local pixelSizeX = (width - padding * 2) / rx
    local pixelSizeY = (height - padding * 2) / ry

    return {
        Anchor = anchor,
        Childs = {
            [1] = {
                Skin = "WhiteSkin",
                Type = "Widget",
                Colour = "0 0 0",
                x = padding,
                y = padding,
                width = pixelSizeX * rx,
                height = pixelSizeY * ry,
            },
            [2] = {
                Caption = title,
                FontName = "SM_HeaderTiny",
                Skin = "TextBox",
                TextAlign = "Center",
                TextColour = "1 1 1",
                Type = "TextBox",
                height = padding,
                width = width,
                x = 0,
                y = 0,
            },
        },
        InheritsPick = true,
        Name = "BackPanel",
        NeedKey = false,
        NeedMouse = false,
        Skin = "BackgroundInteractableWide",
        Type = "Widget",
        x = x, y = y,
        width = width, height = height,
    }
end

function canvasGUI.createGuiCanvas(x, y, rx, ry, width, height, padding, title, anchor, jsonGuiSetup)
    title = title or ""
    anchor = anchor or "Center"
    jsonGuiSetup = jsonGuiSetup or canvasGUI.jsonGuiSetup

    local buffer = {}
    local bufferBase = 0x000000
    local bufferDirty = true

    local pixelSizeX, pixelSizeY, pxExpand, pyExpand
    local function recalcGeometry()
        pixelSizeX = (width - padding * 2) / rx
        pixelSizeY = (height - padding * 2) / ry
        if canvasGUI.debugCanvas then
            pxExpand = -2
            pyExpand = -2
        else
            pxExpand = canvasGUI.additionalPixelSize
            pyExpand = canvasGUI.additionalPixelSize
        end
    end
    recalcGeometry()

    local guiTable
    local guiInstance
    local childsCount = 2

    local function createGuiTable()
        guiTable = canvasGUI.createGuiTable(x, y, rx, ry, width, height, padding, title, anchor)
    end

    createGuiTable()

    local widgetPool = {}
    local widgetPoolCount = 0
    local function acquireWidget()
        local n = widgetPoolCount
        if n == 0 then return { Skin = "WhiteSkin", Type = "Widget" } end
        local w = widgetPool[n]
        widgetPool[n] = nil
        widgetPoolCount = n - 1
        return w
    end
    local function releaseWidget(w)
        widgetPoolCount = widgetPoolCount + 1
        widgetPool[widgetPoolCount] = w
    end

    local visited = {}
    local visitedGen = 0

    local function decompose(callback)
        visitedGen = visitedGen + 1
        local gen = visitedGen
        local v, buf, base = visited, buffer, bufferBase

        for y = 0, ry - 1 do
            local rowBase = y * rx
            for x = 0, rx - 1 do
                local i = rowBase + x
                if v[i] ~= gen then
                    local color = buf[i]
                    if color == nil then color = base end
                    if color ~= base then
                        local w = 1
                        while x + w < rx do
                            local j = rowBase + x + w
                            if v[j] == gen then break end
                            local c = buf[j]
                            if c == nil then c = base end
                            if c ~= color then break end
                            w = w + 1
                        end

                        local h = 1
                        while y + h < ry do
                            local nextRowBase = (y + h) * rx
                            local ok = true
                            for k = 0, w - 1 do
                                local j = nextRowBase + x + k
                                if v[j] == gen then ok = false; break end
                                local c = buf[j]
                                if c == nil then c = base end
                                if c ~= color then ok = false; break end
                            end
                            if not ok then break end
                            h = h + 1
                        end

                        for hh = 0, h - 1 do
                            local off = (y + hh) * rx + x
                            for ww = 0, w - 1 do
                                v[off + ww] = gen
                            end
                        end

                        callback(x, y, w, h, color)
                    end
                end
            end
        end
    end

    local function buildChilds()
        local childs = guiTable.Childs

        for i = 3, childsCount do
            local w = childs[i]
            if w then
                releaseWidget(w)
                childs[i] = nil
            end
        end

        childs[1].Colour = lFormatColor(bufferBase)

        local idx = 3
        decompose(function(x, y, w, h, color)
            local widget = acquireWidget()
            widget.Colour = lFormatColor(color)
            widget.x = x * pixelSizeX + padding
            widget.y = y * pixelSizeY + padding
            widget.width  = w * pixelSizeX + pxExpand
            widget.height = h * pixelSizeY + pyExpand
            childs[idx] = widget
            idx = idx + 1
        end)

        childsCount = idx - 1
        bufferDirty = false
    end

    local api
    api = {
        update = function() end,

        open = function()
            if not guiInstance then
                guiInstance = sm.jsonGui.createGui(jsonGuiSetup)
            end
            if bufferDirty then buildChilds() end
            guiInstance:render(guiTable)
        end,

        close = function()
            if guiInstance and guiInstance:isActive() then
                guiInstance:close()
            end
        end,

        destroy = function()
            api.close()
            guiInstance = nil
        end,

        isRendering = function()
            if guiInstance and guiInstance:isActive() then
                return true
            end
            return false
        end,

        resize = function(nrx, nry)
            local oldChilds = guiTable.Childs
            for i = 3, childsCount do
                local w = oldChilds[i]
                if w then releaseWidget(w) end
            end

            rx, ry = nrx, nry
            recalcGeometry()
            buffer = {}
            bufferBase = 0x000000
            bufferDirty = true
            createGuiTable()
            childsCount = 2

            if api.isRendering() then
                buildChilds()
                guiInstance:render(guiTable)
            end
        end,

        clear = function(color)
            buffer = {}
            bufferBase = color or 0
            bufferDirty = true
        end,

        setPixel = function(x, y, color)
            x = math_floor(x)
            y = math_floor(y)
            if x < 0 or y < 0 or x >= rx or y >= ry then return end
            local idx = x + y * rx
            local old = buffer[idx]
            if old == nil then old = bufferBase end
            if color ~= old then
                if color == bufferBase then
                    buffer[idx] = nil
                else
                    buffer[idx] = color
                end
                bufferDirty = true
            end
        end,

        flush = function()
            if not api.isRendering() then return end
            if bufferDirty then
                buildChilds()
                guiInstance:render(guiTable)
            end
        end
    }

    return api
end

_G.canvasGUI = canvasGUI