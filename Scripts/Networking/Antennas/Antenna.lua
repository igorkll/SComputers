dofile "$MOD_DATA/Scripts/Config.lua"

Antenna = class(nil)
Antenna.maxParentCount = -1
Antenna.maxChildCount = -1
Antenna.connectionInput = sm.interactable.connectionType.networking + sm.interactable.connectionType.composite
Antenna.connectionOutput = sm.interactable.connectionType.networkCamera
Antenna.colorNormal = sm.color.new(0xedc84cff)
Antenna.colorHighlight = sm.color.new(0xebcf71ff)

function Antenna.writeToBuffer(self, packets, buffer)
	local insert = table.insert
	--local id = self.super.interactable:getId()

	--local copy = sc.networking.packetCopyPath

	for i, packet in ipairs(packets) do
		--local transmitters = packet.transmitters

		--if transmitters[id] == nil then
		--	transmitters[id] = true

		--	packet = copy(packet)
		--	insert(packet.transmitterPath, id)

			insert(buffer, packet)
		--end
	end
end

function Antenna:selfID()
	if self.interactable then
		return self.interactable.id
	else
		return self.tool.id
	end
end

function Antenna.receivePackets(self, packets) --вызываеться с отправляюшей антенны
	if self.activeState then
		self:writeToBuffer(packets, self.receivePacketBuffer)
	end
end

function Antenna.setChannel(self, c)
	if c >= 0 and c < 32 and c % 1 == 0 then
		self.channel = c
	else
		error("channel value is integer in [0; 31]")
	end
end

function Antenna.sendPackets(self) --отправка пакетов по ралиоканалу
	if self.activeState then
		local thisPos = self.shape:getWorldPosition()
		local distSq = self.radius and (self.radius * self.radius)
		local packets = self.sendPacketBuffer

		local recvPacks = Antenna.receivePackets

		for k, v in pairs(sc.antennasRefs) do
			if v.channel == self.channel and v ~= self then
				local shape = v.shape
				local pos = shape:getWorldPosition()

				local delta = pos - thisPos

				if not distSq or delta:length2() <= distSq then --если она в радиусе действия или у нашей антены нет радиуса
					recvPacks(v, packets) --вызываем метод приема у целевой антены
				end
			end
		end

		self:doBlick()
	end

	self.sendPacketBuffer = {}
end

function Antenna:findTargets()
	local tbl = {}

	if self.activeState then
		local thisPos = self.shape:getWorldPosition()
		local distSq = self.radius and (self.radius * self.radius)
		local packets = self.sendPacketBuffer

		for k, v in pairs(sc.antennasRefs) do
			if v.channel == self.channel and v ~= self then
				local shape = v.shape
				local pos = shape:getWorldPosition()

				local delta = pos - thisPos

				if not distSq or delta:length2() <= distSq then --если она в радиусе действия или у нашей антены нет радиуса
					table.insert(tbl, v)
				end
			end
		end
	end

	return tbl
end

function Antenna.transmitPackets(self)
	if self.activeState and self.interactable then
		local parents = self.interactable:getParents(sm.interactable.connectionType.networking) or {}

		for index, parent in ipairs(parents) do
			local script = sc.networking[parent:getId()]
			if script then
				script:propagatePackets(self.receivePacketBuffer)
			end
		end

		self:doBlick()
	end

	self.receivePacketBuffer = {}
end

function Antenna.propagatePackets(self, packets)
	self:writeToBuffer(packets, self.sendPacketBuffer)
end

function Antenna.server_onCreate(self)
	local id = self:selfID()

	self.data = self.data or {}

	self.radius = self.data.radius
	self.sendPacketBuffer = {}
	self.receivePacketBuffer = {}
	self.activeState = true
	
	local data = self.storage:load()
	if data ~= nil then
		self.channel = data.channel or 0
	else
		self.channel = 0
	end

	sc.antennasRefs[id] = self
	sc.networking[id] = self
	sc.antennasApis[id] = {
		getRadius = function ()
			return self.radius or math.huge
		end,
		getChannel = function ()
			return self.temp_setchannel or self.channel
		end,
		setChannel = function (c)
			if c >= 0 and c < 32 and c % 1 == 0 then
				self.temp_setchannel = c
			else
				error("channel value is integer in [0; 31]")
			end
		end,
		setActive = function (state)
			checkArg(1, state, "boolean")
			self.activeState = state
		end,
		isActive = function ()
			return self.activeState
		end
	}

	if self.radius and self.radius <= 4 and self.data.screen then
		self.network:sendToClients("cl_blink", true)
	end
end

function Antenna.server_onDestroy(self)
	local id = self:selfID()
	sc.antennasRefs[id] = nil
	sc.networking[id] = nil
	sc.antennasApis[id] = nil
end

function Antenna:doBlick()
	local ctick = sm.game.getCurrentTick()
	if (not self.lastSendBlinkTime or ctick - self.lastSendBlinkTime > 20) and self.data.screen then
		self.network:sendToClients("cl_blink")
		self.lastSendBlinkTime = ctick
	end
end

function Antenna.server_onFixedUpdate(self)
	if #self.sendPacketBuffer > 0 then
		self:sendPackets()
	end

	if #self.receivePacketBuffer > 0 then
		self:transmitPackets()
	end
	
	if self.temp_setchannel then
		self:server_changeChannel(self.temp_setchannel)
		self.temp_setchannel = nil
	end

	if self.sendBlick then
		self:doBlick()
		self.sendBlick = nil
	end

	if (self.channel ~= self.old_channel or self.activeState ~= self.old_activeState) and sc.needSaveData() then
		self:sv_save()
		self.old_channel = self.channel
		self.old_activeState = self.activeState
	end
end

function Antenna:sv_save()
	self.storage:save({
		channel = self.channel
	})
end

function Antenna.server_changeChannel(self, channel)
	self:setChannel(channel)
	self.network:sendToClients("client_changeChannel", channel)
end


function Antenna.server_requireChannel(self, data, client)
	self.network:sendToClient(client, "client_changeChannel", self.channel)
	if self.radius and self.radius <= 4 and self.data.screen then
		self.network:sendToClients("cl_blink", true)
	end
end


function Antenna.client_onCreate(self)
	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Antenna.layout", false, { backgroundAlpha = 0.5 })
	self.gui:setTextChangedCallback("Channel", "client_onChannelChanged")
	self.gui:setButtonCallback("Save", "client_onSave")

	self.channelToSend = 0
	self.serverChannel = 0

	self.network:sendToServer("server_requireChannel")
end

function Antenna.client_onDestroy(self)
	self.gui:destroy()
end

function Antenna.client_onInteract(self, char, state)
	if state then
		self:client_guiOpen()
	end
end

function Antenna.client_changeChannel(self, channel)
	self.serverChannel = channel
end

function Antenna.client_onChannelChanged(self, widget, data)
	if data:match("%d*") == data then
		local channel = tonumber(data)
		if channel >= 0 and channel <= 31 then
			self.channelToSend = channel
			self:client_guiError(nil)
		else
			self:client_guiError("integer not in [0; 31]")
		end
	else
		self:client_guiError("bad integer")
	end
end

function Antenna.client_onSave(self)
	self.network:sendToServer("server_changeChannel", self.channelToSend)
	self:client_guiClose()
end

function Antenna.client_guiOpen(self)
	self.channelToSend = self.serverChannel
	self.gui:setText("Channel", tostring(self.serverChannel))
	self:client_guiError(nil)
	self.gui:open()
end

function Antenna.client_guiError(self, text)
	if text ~= nil then
		self.gui:setVisible("Save", false)
		self.gui:setText("Error", text)
	else
		self.gui:setVisible("Save", true)
		self.gui:setText("Error", "")
	end
end

function Antenna.client_guiClose(self)
	self.gui:close()
end

function Antenna:client_onFixedUpdate()
	if self.interactable and self.blink_time then
		self.blink_time = self.blink_time - 1
		if self.blink_time <= 0 then
			self.interactable:setUvFrameIndex(self.isNfc and 1 or 0)
			self.blink_time = nil
		end
	end
end

function Antenna:cl_blink(data)
	if self.interactable then
		if data then
			self.isNfc = data
			self.interactable:setUvFrameIndex(1)
		else
			self.interactable:setUvFrameIndex(self.isNfc and 7 or 6)
			self.blink_time = 7
		end
	end
end