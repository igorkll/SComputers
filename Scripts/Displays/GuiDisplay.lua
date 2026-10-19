dofile("$SURVIVAL_DATA/Scripts/util.lua")
GuiDisplay = class()

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

function GuiDisplay:cl_createGuiTable()
    local guiTable = {}
    guiTable.root = sm.json.open( "$GAME_DATA/Gui/JsonGuis/PopUp_YN.gui" )
    guiTable.index = IndexWidgets( guiTable.root )
    guiTable.index["Title"].Caption = "#{MENU_YN_TITLE_ARE_YOU_SURE}"
    guiTable.index["Message"].Caption = "#{MENU_YN_MESSAGE_UNSTUCK}"

    return guiTable
end

function GuiDisplay:cl_openGui()
    if self.gui then return end

    self.gui_activated = false
    self.gui_table = self:cl_createGuiTable()

    self.gui = sm.jsonGui.createGui({ isInteractive = true, needsCursor = true })
    self.gui:render(self.gui_table.root)
end

function GuiDisplay:client_onDestroy()
    if self.gui then
        self.gui:close()
        self.gui = nil
    end
end
