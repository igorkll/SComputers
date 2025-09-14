terminal = class()
terminal.maxParentCount = -1
terminal.maxChildCount = 0
terminal.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.seated
terminal.connectionOutput = sm.interactable.connectionType.none
terminal.colorNormal = sm.color.new(0x7F7F7Fff)
terminal.colorHighlight = sm.color.new(0xFFFFFFff)
terminal.componentType = "terminal" --absences can cause problems
terminal.outputLimit = 1024 * 64

function terminal:server_onCreate()
    self.syntax = false

    self.interactable.publicData = {
        sc_component = {
            type = terminal.componentType,
            api = {
                read = function()
                    local text = self.ctext
                    self.ctext = nil
                    return text
                end,
                clear = function ()
                    self.writes = nil
                    self.clear = true
                end,
                write = function (str)
                    if not self.writes then self.writes = {} end
                    table.insert(self.writes, "#ffffff" .. tostring(str))
                end,
                setSyntax = function(syntax)
                    checkArg(1, syntax, "boolean")
                    self.syntax = syntax
                    self.flushSyntaxEnable = true
                end,
                isSyntax = function()
                    return self.syntax
                end
            }
        }
    }
end

function terminal:server_onFixedUpdate()
	if sc.needScreenSend() then self.allow_update = true end

    if self.allow_update and (self.clear or self.writes) then
        if self.clear then
            self.network:sendToClients("cl_clr")
            self.clear = nil
        end

        if self.writes then
            self.network:sendToClients("cl_log", self.writes)
            self.writes = nil
        end

        self.allow_update = nil
    end

    if self.flushSyntaxEnable then
        self.network:sendToClients("cl_setSyntaxEnable", self.syntax)
        self.flushSyntaxEnable = nil
    end
end

function terminal:sv_text(text)
    self.ctext = text
end

-------------------------------------------

function terminal:client_onCreate()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/terminal.layout", false)
    self.gui:setButtonCallback("send", "cl_send")
    self.gui:setButtonCallback("up", "cl_up")
    self.gui:setButtonCallback("down", "cl_down")
    self.gui:setTextAcceptedCallback("text", "cl_send")
    self.gui:setTextChangedCallback("text", "cl_edit")

    self.lastdata = ""
    self.cltext = ""
    self.log = ""
    self.history = {}
end

function terminal:client_onFixedUpdate()
    if self.cl_syntax then
        if localStorage.current.palette ~= self.palette then
            self.needUpdateSyntax = true
            self.palette = localStorage.current.palette
        end
    end

    if better and better.isAvailable() then
        local upButton = better.keyboard.isKey(better.keyboard.keys.arrow_u)
        local downButton = better.keyboard.isKey(better.keyboard.keys.arrow_d)

        if upButton and not self.upButton then
            self.upDelay = 5 --why is there a delay? Otherwise, the cursor would sometimes end up at the beginning of the line instead of the end
            self.downDelay = nil
        end

        if downButton and not self.downButton then
            self.upDelay = nil
            self.downDelay = 5
        end

        self.upButton = upButton
        self.downButton = downButton

        if self.upDelay then
            self.upDelay = self.upDelay - 1
            if self.upDelay <= 0 then
                self:cl_up()
                self.upDelay = nil
            end
        end

        if self.downDelay then
            self.downDelay = self.downDelay - 1
            if self.downDelay <= 0 then
                self:cl_down()
                self.downDelay = nil
            end
        end
    end
end

function terminal:client_onInteract(_, state)
    if state then
        if self.needUpdateSyntax then
            self.gui:setText("text", syntax_make(formatBeforeGui(self.cltext)))
            self.needUpdateSyntax = nil
        end
        self.palette = localStorage.current.palette
        self.gui:open()
    end
end

function terminal:cl_setSyntaxEnable(syntax)
    self.cl_syntax = syntax
end

function terminal:cl_edit(_, text)
    self.cltext = formatAfterGui(text)
    self.actualText = self.cltext
    self.historyIndex = nil

    if self.cl_syntax then
        if (#self.cltext > #self.lastdata and self.cltext:sub(1, #self.lastdata) == self.lastdata) or
        (#self.cltext < #self.lastdata and self.lastdata:sub(1, #self.cltext) == self.cltext) then
            self.gui:setText("text", syntax_make(formatBeforeGui(self.cltext)))
            self.needUpdateSyntax = nil
        else
            self.needUpdateSyntax = true
        end
    end
    self.lastdata = self.cltext
end

function terminal:cl_log(log)
    for index, text in ipairs(log) do
        local beepFind = text:find("%" .. string.char(7))
        if beepFind then
            sm.audio.play("Horn", self.shape.worldPosition)
            text = text:sub(1, beepFind - 1) .. text:sub(beepFind + 1, #text)
        end
        self.log = self.log .. text
    end
    self.log = self.log:sub(math.max(1, #self.log - terminal.outputLimit), #self.log)
    self.gui:setText("log", self.log)
end

function terminal:cl_clr()
    self.log = ""
    self.gui:setText("log", self.log)
end

function terminal:cl_send()
    self.gui:setText("text", "")
    if self.history[#self.history] ~= self.cltext and self.cltext ~= "" then
        table.insert(self.history, self.cltext)
    end
    self.network:sendToServer("sv_text", self.cltext)
    self.cltext = ""
    self.actualText = nil
    self.historyIndex = nil
end

function terminal:cl_up()
    if self.historyIndex then
        self.historyIndex = self.historyIndex - 1
        if self.historyIndex < 1 then
            self.historyIndex = 1
        end
    else
        self.historyIndex = #self.history
        if self.historyIndex == 0 then
            self.historyIndex = nil
            return
        end
    end
    self.cltext = self.history[self.historyIndex]
    self:cl_updText()
end

function terminal:cl_down()
    if self.historyIndex then
        self.historyIndex = self.historyIndex + 1
        if self.historyIndex > #self.history then
            self.historyIndex = nil
            self.cltext = self.actualText or ""
        else
            self.cltext = self.history[self.historyIndex]
        end
        self:cl_updText()
    end
end

function terminal:cl_updText()
    self.lastdata = self.cltext
    if self.cl_syntax then
        self.gui:setText("text", syntax_make(formatBeforeGui(self.cltext)))
    else
        self.gui:setText("text", formatBeforeGui(self.cltext))
    end
end