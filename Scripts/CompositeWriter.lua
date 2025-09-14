dofile "$CONTENT_DATA/Scripts/Config.lua"

CompositeWriter = class(nil)

CompositeWriter.maxParentCount = 1
CompositeWriter.maxChildCount = -1
CompositeWriter.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
CompositeWriter.connectionOutput = sm.interactable.connectionType.composite
CompositeWriter.colorNormal = sm.color.new(0x160f94ff)
CompositeWriter.colorHighlight = sm.color.new(0x271beaff)

CompositeWriter.UV_NON_ACTIVE = 1
CompositeWriter.UV_ACTIVE_OFFSET = 6


--SERVER --
function CompositeWriter.server_onCreate(self)
	local data = self.storage:load()
	if data ~= nil then
		self.register = data.register
	else
		self.register = ""
	end
	sc.writersRefs[self.interactable:getId()] = self
end

function CompositeWriter.server_onDestroy(self)
	sc.writersRefs[self.interactable:getId()] = nil
end

-- invoked by computer
function CompositeWriter.server_updateComputerRegisterValue(self)
	local parent = self.interactable:getSingleParent()

	for k, child in pairs(self.interactable:getChildren()) do
		local data = sc.computersDatas[child:getId()]
		if data and data.public and self.register ~= "" then
			local regs = data.public.registers
			if parent then
				regs[self.register] = parent:getPower()
			else
				regs[self.register] = 0
			end
		end
	end
end

function CompositeWriter.server_onFixedUpdate(self, dt)
	self:server_updateComputerRegisterValue()
end

function CompositeWriter.server_updateRegister(self, reg)
	if #reg > 64 then return end
	self.storage:save({
		register = reg
	})
	self.register = reg
	self.network:sendToClients("client_updateRegister", self.register)
end

function CompositeWriter.server_onRequiredRegister(self, data, client)
	self.network:sendToClient(client, "client_updateRegister", self.register)
end

-- CLIENT --

function CompositeWriter.client_onFixedUpdate(self, dt)
	if self.interactable:getSingleParent() and self.interactable:getSingleParent():isActive() then
		self.interactable:setUvFrameIndex(CompositeWriter.UV_NON_ACTIVE + CompositeWriter.UV_ACTIVE_OFFSET)
	else
		self.interactable:setUvFrameIndex(CompositeWriter.UV_NON_ACTIVE)
	end
end

function CompositeWriter.client_onCreate(self)
	self.network:sendToServer("server_onRequiredRegister")
	self.last_reg = ""
	self.saved_reg = ""
end

function CompositeWriter.client_onInteract(self, char, state)
	if state then
		if self.gui == nil then
			self:client_createGUI()
		end
		self.last_reg = self.saved_reg
		self.gui:setText("RegisterName", formatBeforeGui(self.saved_reg))
		self.gui:open()
	end
end

function CompositeWriter.client_updateRegister(self, reg)
	if self.gui == nil then
		self:client_createGUI()
	end
	self.saved_reg = reg
	self.last_reg = reg
end

function CompositeWriter.client_createGUI(self)
	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/CompositeWriter.layout", false)
	self.gui:setTextChangedCallback("RegisterName", "client_onRegisterNameChanged")
	self.gui:setButtonCallback("Save", "client_onSaveRegister")
end

function CompositeWriter.client_onRegisterNameChanged(self, widget, data)
	self.last_reg = formatAfterGui(data)
end

function CompositeWriter.client_onSaveRegister(self)
	self.saved_reg = self.last_reg
	self.network:sendToServer("server_updateRegister", self.saved_reg)
	self.gui:close()
end

function CompositeWriter.client_onDestroy(self)
	if self.gui ~= nil then
		self.gui:destroy()
	end
end