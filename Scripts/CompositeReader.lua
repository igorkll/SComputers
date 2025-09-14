dofile "$CONTENT_DATA/Scripts/Config.lua"

CompositeReader = class(nil)

CompositeReader.maxParentCount = 1
CompositeReader.maxChildCount = -1
CompositeReader.connectionInput = sm.interactable.connectionType.composite
CompositeReader.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
CompositeReader.colorNormal = sm.color.new(0x940e0eff)
CompositeReader.colorHighlight = sm.color.new(0xd21414ff)

CompositeReader.UV_NON_ACTIVE = 2
CompositeReader.UV_ACTIVE_OFFSET = 6

--SERVER --
function CompositeReader.server_onCreate(self)
	local data = self.storage:load()
	if data ~= nil then
		self.register = data.register
	else
		self.register = ""
	end
    sc.readersRefs[self.interactable:getId()] = self
end

function CompositeReader:server_onDestroy()
    sc.readersRefs[self.interactable:getId()] = nil
end

function CompositeReader.server_onFixedUpdate(self, dt)
	self:sv_update()
end

function CompositeReader:sv_update()
	local parent = self.interactable:getSingleParent()
	if parent ~= nil then
		local data = sc.computersDatas[parent:getId()].public
		if data ~= nil then
			local value = data.registers[self.register]
			if value ~= nil then
				if value == true then
					value = 1
				elseif value == false then
					value = 0
				end
				self.interactable:setActive(value ~= 0)
				self.interactable:setPower(value)
			else
				self.interactable:setActive(false)
				self.interactable:setPower(0)
			end
		else
			self.interactable:setActive(false)
			self.interactable:setPower(0)
		end
	else
		self.interactable:setActive(false)
		self.interactable:setPower(0)
	end
end

function CompositeReader.server_updateRegister(self, reg)
	if #reg > 64 then return end
	self.storage:save({
		register = reg
	})
	self.register = reg
	self.network:sendToClients("client_updateRegister", self.register)
end

function CompositeReader.server_onRequiredRegister(self, data, client)
	self.network:sendToClient(client, "client_updateRegister", self.register)
end

-- CLIENT --

function CompositeReader.client_onFixedUpdate(self, dt)
	if self.interactable:isActive() then
		self.interactable:setUvFrameIndex(CompositeReader.UV_NON_ACTIVE + CompositeReader.UV_ACTIVE_OFFSET)
	else
		self.interactable:setUvFrameIndex(CompositeReader.UV_NON_ACTIVE)
	end
end

function CompositeReader.client_onCreate(self)
	self.network:sendToServer("server_onRequiredRegister")
	self.last_reg = ""
	self.saved_reg = ""
end

function CompositeReader.client_onInteract(self, char, state)
	if state then
		if self.gui == nil then
			self:client_createGUI()
		end
		self.last_reg = self.saved_reg
		self.gui:setText("RegisterName", formatBeforeGui(self.saved_reg))
		self.gui:open()
	end
end

function CompositeReader.client_updateRegister(self, reg)
	if self.gui == nil then
		self:client_createGUI()
	end
	self.saved_reg = reg
	self.last_reg = reg
end

function CompositeReader.client_createGUI(self)
	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/CompositeReader.layout", false)
	self.gui:setTextChangedCallback("RegisterName", "client_onRegisterNameChanged")
	self.gui:setButtonCallback("Save", "client_onSaveRegister")
end

function CompositeReader.client_onRegisterNameChanged(self, widget, data)
	self.last_reg = formatAfterGui(data)
end

function CompositeReader.client_onSaveRegister(self)
	self.saved_reg = self.last_reg
	self.network:sendToServer("server_updateRegister", self.saved_reg)
	self.gui:close()
end

function CompositeReader.client_onDestroy(self)
	if self.gui ~= nil then
		self.gui:destroy()
	end
end