dofile("$SURVIVAL_DATA/Scripts/util.lua")
GuiDisplay = class()

function GuiDisplay:client_onCreate()
    
end

function GuiDisplay:client_onInteract(_, state)
    if state then
        self:cl_openGui()
    end
end

function GuiDisplay:cl_createGuiTable()
    local guiTable = {}
    guiTable.root = sm.json.open( "$CONTENT_DATA/Gui/JsonGuis/GuiDisplay.gui" )
    guiTable.index = IndexWidgets( UnstuckPopupGui.root )
    guiTable.index["Title"].Caption = "#{MENU_YN_TITLE_ARE_YOU_SURE}"
    guiTable.index["Message"].Caption = "#{MENU_YN_MESSAGE_UNSTUCK}"

    return guiTable
end

function GuiDisplay:cl_openGui()
    if self.gui then return end

    self.guiTable = self:cl_createGuiTable()

    self.gui = sm.jsonGui.createGui({ isInteractive = true, needsCursor = true })
    self.gui:render(self.guiTable)
end

function GuiDisplay:client_onDestroy()
    if self.gui then
        self.gui:close()
        self.gui = nil
    end
end

