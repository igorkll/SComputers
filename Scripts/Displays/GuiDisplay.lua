GuiDisplay = class()
GuiDisplay.maxParentCount = 1
GuiDisplay.maxChildCount = 0
GuiDisplay.connectionInput = sm.interactable.connectionType.composite
GuiDisplay.colorNormal = sm.color.new(0xbbbb1aff)
GuiDisplay.colorHighlight = sm.color.new(0xecec1fff)
GuiDisplay.componentType = "display"

function GuiDisplay:server_onCreate()
    
end

---------------------------------------------

function GuiDisplay:client_onCreate()
    
end

function GuiDisplay:client_onInteract(_, state)
    if state then
        self:cl_openGui()
    end
end

function GuiDisplay:client_onFixedUpdate()
    if self.gui then
        local active = self.gui:isActive()
        if active then
            self.gui_activated = true
        elseif self.gui_activated then
            self.gui:close()
            self.gui = nil
        end
    end
end

function GuiDisplay:getIndex(x, y)
    return x + (y * 64)
end

function GuiDisplay:setColor(x, y, color)
    guiTable.Childs[self:getIndex(ix, iy)] = sc.formatColor(color)
end

function GuiDisplay:cl_createGuiTable(width, height, rx, ry)
    local padding = 50
    local pWidth = width - (padding * 2)
    local pHeight = height - (padding * 2)
    local pixelSizeX = pWidth / rx
    local pixelSizeY = pHeight / ry
    local guiTable = sm.json.open("$CONTENT_DATA/Gui/JsonGuis/GuiDisplay.gui")

    for ix = 0, rx - 1 do
        for iy = 0, ry - 1 do
            guiTable.Childs[self:getIndex(ix, iy)] = {
                ["Skin"] = "WhiteSkin",
                ["Type"] = "Widget",
                ["x"] = (ix * pixelSizeX) + padding,
                ["y"] = (iy * pixelSizeY) + padding,
                ["width"] = pixelSizeX,
                ["height"] = pixelSizeY
            }
            self:setColor(ix, iy, (ix + iy) % 256)
        end
    end

    guiTable.width = width
    guiTable.height = height
    guiTable._rx = rx
    guiTable._ry = ry

    return guiTable
end

function GuiDisplay:cl_openGui()
    if self.gui then return end

    self.gui_activated = false
    self.gui_table = self:cl_createGuiTable(500, 500, 64, 64)

    self.gui = sm.jsonGui.createGui({ isInteractive = true, needsCursor = true })
    self.gui:render(self.gui_table)
end

function GuiDisplay:client_onDestroy()
    if self.gui then
        self.gui:close()
        self.gui = nil
    end
end
