dofile "$MOD_DATA/Scripts/Config.lua"

NetworkPort = class(nil)

NetworkPort.maxParentCount = -1
NetworkPort.maxChildCount = -1
NetworkPort.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.networking
NetworkPort.connectionOutput = sm.interactable.connectionType.networking
NetworkPort.colorNormal = sm.color.new(0xedc84cff)
NetworkPort.colorHighlight = sm.color.new(0xebcf71ff)

NetworkPort.MAX_STORED_PACKETS = 128

-- CLIENT --

--[[
function NetworkPort.getParentCount(self, connectionType)
    return #
end

function NetworkPort.getChildCount(self, connectionType)
    return #self.interactable:getChildren(connectionType)
end

function NetworkPort.getNetworkConnectionsCount(self)
    return self:getChildCount() + self:getParentCount(sm.interactable.connectionType.networking)
end

function NetworkPort.client_getAvailableChildConnectionCount(self, connectionType)
    return 1 - self:getNetworkConnectionsCount()
end


]]

function NetworkPort.client_getAvailableParentConnectionCount(self, connectionType)
    local checks = sm.interactable.connectionType.composite
    if bit.band(connectionType, checks) ~= 0 then
        return 1 - #self.interactable:getParents(checks)
    end
    return 1
end



-- SERVER --

function NetworkPort:getUniqueId()
    return self.interactable:getId()
end

function NetworkPort.createData(self)
    return {
        getMaxPacketsCount = function () return NetworkPort.MAX_STORED_PACKETS end,
        getPacketsCount = function () 
            return #self.packets
        end,
        nextPacket = function () 
            local packet = table.remove(self.packets, 1)
            if not packet then return nil, nil end
            return packet.data, packet.source
        end,
        send = function (packet)
            checkArg(1, packet, "string")
            self:server_putPacket(packet)
        end,
        sendTo = function (id, packet)
            checkArg(1, id, "number")
            checkArg(2, packet, "string")
            self:server_putPacket(packet, id)
        end,
        clear = function ()
            self.packets = {}
        end,
        getUniqueId = function ()
            return self:getUniqueId()
        end,

        sendTable = function (tbl)
            checkArg(1, tbl, "table")
            jsonEncodeInputCheck(tbl, 0)
            self:server_putPacket(sm.json.writeJsonString(tbl))
        end,
        sendTableTo = function (id, tbl)
            checkArg(1, id, "number")
            checkArg(2, tbl, "table")
            jsonEncodeInputCheck(tbl, 0)
            self:server_putPacket(sm.json.writeJsonString(tbl), id)
        end,
        nextTable = function () 
            local packet = table.remove(self.packets, 1)
            if not packet then return nil, nil end
            local okay, tbl = pcall(sm.json.parseJsonString, packet.data)
            if okay then
                return tbl, packet.source
            end
        end,
    }
end

-- interface method
function NetworkPort.propagatePackets(self, packets) --получение
    self.reciveBlick = true

    local packs = self.packets
    local id = self:getUniqueId()

    local max = NetworkPort.MAX_STORED_PACKETS
    local insert = table.insert

    local dcopy = sc.deepcopy

    for i, packet in ipairs(packets) do
        if not packet.id or packet.id == id then
            if #packs <= max then
                insert(packs, dcopy(packet))
            else
                break
            end
        end
    end
end

function NetworkPort.server_putPacket(self, packet, id) --помешения на отправку из компа
    assert(type(packet) == "string", "network data must be string")
    if #self.packetsToSend < NetworkPort.MAX_STORED_PACKETS then
        table.insert(self.packetsToSend, {
            data = packet,
            id = id,
            source = self:getUniqueId()
        })
    else
        error("packet buffer overflow")
    end
end

function NetworkPort.server_sendPackets(self) --отправка
    local childs = self.interactable:getChildren(sm.interactable.connectionType.networking) or {}
    local parents = self.interactable:getParents(sm.interactable.connectionType.networking) or {}

    for index, child in ipairs(childs) do
        local script = sc.networking[child:getId()]
        if script then
            script:propagatePackets(self.packetsToSend)
        end
    end
    for index, parent in ipairs(parents) do
        local script = sc.networking[parent:getId()]
        if script then
            script:propagatePackets(self.packetsToSend)
        end
    end

    self.packetsToSend = {}
end

function NetworkPort.server_onCreate(self)
    self.packets = {}
    self.packetsToSend = {}

    local id = self.interactable:getId()

    sc.networkPortsDatas[id] = self:createData()
    sc.networking[id] = self
end

function NetworkPort.server_onDestroy(self)
    local id = self.interactable:getId()

    sc.networkPortsDatas[id] = nil
    sc.networking[id] = nil
end

function NetworkPort.server_onFixedUpdate(self, dt)
    local ctick = sm.game.getCurrentTick()
    
    if #self.packetsToSend > 0 then
        self:server_sendPackets()

        if not self.lastSendBlinkTime1 or ctick - self.lastSendBlinkTime1 > 20 then
            self.network:sendToClients("cl_blink", 1)
            self.lastSendBlinkTime1 = ctick
        end
    end

    if self.reciveBlick then
        if not self.lastSendBlinkTime2 or ctick - self.lastSendBlinkTime2 > 20 then
            self.network:sendToClients("cl_blink", 2)
            self.lastSendBlinkTime2 = ctick
        end

		self.reciveBlick = false
    end
end

------------------------

NetworkPort.ledShape = sm.uuid.new("b46ae32a-9037-4360-9f98-3bef1cd4f366")

NetworkPort.sendOn = sm.color.new("#00ed76")
NetworkPort.sendOn.a = 1
NetworkPort.reciveOn = sm.color.new("#edb100")
NetworkPort.reciveOn.a = 1

NetworkPort.sendOff = NetworkPort.sendOn * 0.5
NetworkPort.sendOff.a = 0
NetworkPort.reciveOff = NetworkPort.reciveOn * 0.9
NetworkPort.reciveOff.a = 0

NetworkPort.ledScale = sm.vec3.new(0.06, 0.04, 0)
NetworkPort.sendLedOffset = sm.vec3.new(-0.076, 0.1, 0.12)
NetworkPort.reciveLedOffset = sm.vec3.new(0.076, 0.1, 0.12)

function NetworkPort:client_onCreate()
    self.sendLed = sm.effect.createEffect(canvasAPI.getEffectName(), self.interactable)
    self.reciveLed = sm.effect.createEffect(canvasAPI.getEffectName(), self.interactable)

    self.sendLed:setParameter("uuid", NetworkPort.ledShape)
    self.reciveLed:setParameter("uuid", NetworkPort.ledShape)

    self.sendLed:setParameter("color", NetworkPort.sendOff)
    self.reciveLed:setParameter("color", NetworkPort.reciveOff)

    self.sendLed:setScale(NetworkPort.ledScale)
    self.reciveLed:setScale(NetworkPort.ledScale)

    self.sendLed:setOffsetPosition(NetworkPort.sendLedOffset)
    self.reciveLed:setOffsetPosition(NetworkPort.reciveLedOffset)

    self.sendLed:start()
    self.reciveLed:start()
end

function NetworkPort:client_onFixedUpdate()
	if self.blink_time1 then
		self.blink_time1 = self.blink_time1 - 1
		if self.blink_time1 <= 0 then
			self.sendLed:setParameter("color", NetworkPort.sendOff)
			self.blink_time1 = nil
		end
	end

	if self.blink_time2 then
		self.blink_time2 = self.blink_time2 - 1
		if self.blink_time2 <= 0 then
			self.reciveLed:setParameter("color", NetworkPort.reciveOff)
			self.blink_time2 = nil
		end
	end
end

function NetworkPort:cl_blink(btype)
    if self.interactable then
        if btype == 1 then
            self.blink_time1 = 7
            self.sendLed:setParameter("color", NetworkPort.sendOn)
        elseif btype == 2 then
            self.blink_time2 = 7
            self.reciveLed:setParameter("color", NetworkPort.reciveOn)
        end
    end
end