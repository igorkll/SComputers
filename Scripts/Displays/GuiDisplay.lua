dofile("$CONTENT_DATA/Scripts/Config.lua")
GuiDisplay = class(canvasAPI.canvasService)
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
    self.canvasGUI = canvasGUI.createGuiCanvas(32, 32, 500, 500, 25)
end

function GuiDisplay:client_onInteract(_, state)
    if state then
        self.canvasGUI:open()
    end
end

function GuiDisplay:client_onFixedUpdate(delta)
    self.canvasGUI:update()
    self:canvasService(self.canvasGUI.isRendering())
end

function GuiDisplay:client_onDestroy()
    self.canvasGUI:destroy()
end
