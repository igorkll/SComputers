dofile( "$CONTENT_DATA/Scripts/Config.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

SmartSign = class()
SmartSign.maxParentCount = 1
SmartSign.maxChildCount = 0
SmartSign.connectionInput = sm.interactable.connectionType.composite
SmartSign.connectionOutput = sm.interactable.connectionType.none
SmartSign.colorNormal = sm.color.new(0x7F7F7Fff)
SmartSign.colorHighlight = sm.color.new(0xFFFFFFff)
SmartSign.componentType = "smartsign" --absences can cause problems

local guiData = {}
guiData.json = sm.json.open( "$GAME_DATA/Gui/JsonGuis/DigitalSign.gui" )
guiData.textLimitBox = FindWidget( guiData.json, "TextLimit" )
guiData.textBox = FindWidget( guiData.json, "EnterTextBox" )
guiData.buttons = FindWidget( guiData.json, "ButtonGrid" ).Childs
guiData.button1ColorDefault = guiData.buttons[1].Childs[1].TextColour

function SmartSign:sv_publicApi()
    local api
    api = {
        setText = function (text)
            self.sv.saved.text = tostring(text or "")
            self.saveFlag = true
        end,
        getText = function()
            return self.sv.saved.text or ""
        end,

        setTheme = function (num)
            checkArg(1, num, "number")
            self.sv.saved.selected = clamp( num or 1, 1, 8 )
            self.saveFlag = true
        end,
        getTheme = function()
            return self.sv.saved.selected or 1
        end,

        getMaxTextLen = function()
            return self.data.maxTextLength or 6
        end
    }

    self.interactable.publicData = {
        sc_component = {
            type = SmartSign.componentType,
            api = api
        }
    }
end

function SmartSign.server_onCreate( self )
	self.sv = {}
	self.sv.saved = {}
    self.sv.saved = { selected = 1, text = "" }
    self.network:setClientData( self.sv.saved )

    self:sv_publicApi()
end

function SmartSign:server_onFixedUpdate()
    if self.saveFlag then
        self:sv_n_changeState( self.sv.saved )
        self.saveFlag = nil
    end
end

function SmartSign.client_onCreate( self )
	self.cl = {}
	self.cl.state = { selected = 1, text = "" }
	self.cl.defaultColor = sm.item.getShapeDefaultColor( self.shape.uuid )

	if self.data then
		if self.data.effectName then
			self.cl.textEffect = sm.effect.createEffect( self.data.effectName, self.interactable )
		end
		if self.cl.textEffect then
			if self.data.offsetPosition then
				self.cl.textEffect:setOffsetPosition ( sm.vec3.new( self.data.offsetPosition.x, self.data.offsetPosition.y, self.data.offsetPosition.z) )
			end
			if self.data.scale then
				self.cl.textEffect:setScale( sm.vec3.new( self.data.scale.x, self.data.scale.y, self.data.scale.z ) )
			end
			if self.data.asg then
				self.cl.textEffect:setParameter( "ASG", sm.vec3.new( self.data.asg.a, self.data.asg.s, self.data.asg.g ) )
			end
			self.cl.textEffect:start()
		end
	end
end

function SmartSign.client_onFixedUpdate( self )
	if self.cl.currentColor ~= self.shape.color then
		self:cl_updateGui()
		if self.cl.jsonGui then
			self.cl.jsonGui:render( guiData.json )
		end
		self:cl_updateLook()

		self.cl.currentColor = self.shape.color
	end
end

function SmartSign.cl_updateGui( self )
	for i, button in ipairs( guiData.buttons ) do
		button.StateSelected = i == self.cl.state.selected
	end

	if self.shape.color ~= self.cl.defaultColor then
		guiData.buttons[1].Childs[1].TextColour = self.shape.color:getGuiColorStr()
	else
		guiData.buttons[1].Childs[1].TextColour = guiData.button1ColorDefault
	end

	guiData.textBox.MaxTextLength = self.data.maxTextLength or 6
	guiData.textBox.Caption = self.cl.state.text or ""
end

function SmartSign.cl_updateLook( self )
	if self.cl.textEffect then
		self.cl.textEffect:stop()

		if self.cl.state.selected == 1 and self.shape.color ~= self.cl.defaultColor then
			self.cl.textEffect:setParameter( "Color", self.shape.color )
		else
			self.cl.textEffect:setParameter( "Color", ColorFromGuiColor( guiData.buttons[self.cl.state.selected].Childs[1].TextColour ) )
		end

		self.interactable:setUvFrameIndex( self.cl.state.selected - 1 )
	
		self.cl.textEffect:setParameter( "TextContent", self.cl.state.text or "" )

		local offsetPos = nil
		if self.data and self.data.offsetPosition then
			offsetPos = sm.vec3.new( self.data.offsetPosition.x, self.data.offsetPosition.y, self.data.offsetPosition.z)
		else
			offsetPos = sm.vec3.new( 0,0,0 )
		end
		
		local scale = nil
		if self.data and self.data.scale then
			scale = sm.vec3.new( self.data.scale.x, self.data.scale.y, self.data.scale.z)
		else
			scale = sm.vec3.new( 1.2, 1.2, 1.2 )
		end

		if self.cl.textWidth > ( self.data.maxTextWidth or 50 ) then
			scale = scale * (self.data.oversizeScale or 0.75 )
		end

		self.cl.textEffect:setOffsetPosition ( offsetPos )
		self.cl.textEffect:setScale( scale )

		self.cl.textEffect:start()
	end
end

function SmartSign.client_onClientDataUpdate( self, data )
	self.cl.state = data
	self:cl_updateGui()
	self:cl_textLimit( self.cl.state.text )
	if self.cl.jsonGui then
		self.cl.jsonGui:render( guiData.json )
	end
	self:cl_updateLook()
end

function SmartSign.client_onDestroy( self, dt )
	self.cl.textEffect:stop()
	self.cl.textEffect:destroy()
end

--[[
function SmartSign.client_onInteract( self, character, state )
	if state then
		self.cl.jsonGui = sm.jsonGui.createGui()
		self:cl_updateGui()
		self:cl_textLimit( self.cl.state.text )
		self.cl.jsonGui:render( guiData.json )
	end
end
]]

function SmartSign.cl_textLimit( self, text )
	local width, height = sm.gui.computeTextSize( text, self.data.fontName, "Left", -1, false )
	local length = sm.util.utf8StringLength( text )
	guiData.textLimitBox.Caption = "#{INTERACTABLE_TEXTSIGN_TEXT_LIMIT} " .. length .. "/".. (self.data.maxTextLength or 6)
	self.cl.textWidth = width
end

function SmartSign.cl_onTextEdit( self, name, text )
	self:cl_updateGui()
	self:cl_textLimit( text )
	if self.cl.jsonGui then
		self.cl.jsonGui:render( guiData.json )
	end
end

function SmartSign.cl_onTextEnter( self, name, text )
	if text ~= self.cl.state.text then
		self.cl.state.text = text
		self.network:sendToServer( "sv_n_changeState", self.cl.state )
	else
		self:cl_updateGui()
		self:cl_textLimit( text )
		if self.cl.jsonGui then
			self.cl.jsonGui:render( guiData.json )
		end
	end
end

function SmartSign.cl_onClick( self, name )
	if name == "Button1" then
		self.cl.state.selected = 1
	elseif name == "Button2" then
		self.cl.state.selected = 2
	elseif name == "Button3" then
		self.cl.state.selected = 3
	elseif name == "Button4" then
		self.cl.state.selected = 4
	elseif name == "Button5" then
		self.cl.state.selected = 5
	elseif name == "Button6" then
		self.cl.state.selected = 6
	elseif name == "Button7" then
		self.cl.state.selected = 7
	elseif name == "Button8" then
		self.cl.state.selected = 8
	end
	self.network:sendToServer( "sv_n_changeState", self.cl.state )
end

function SmartSign.sv_n_changeState(self, state )
	self.sv.saved = state
	self.network:setClientData( self.sv.saved )
end

function SmartSign.cl_onGuiClosed( self )
	self.cl.jsonGui = nil
end
