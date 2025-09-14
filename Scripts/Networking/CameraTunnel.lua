dofile("$CONTENT_DATA/Scripts/RaycastCamera.lua")
dofile("$CONTENT_DATA/Scripts/Networking/Antennas/Antenna.lua")
CameraTunnel = class()
CameraTunnel.maxParentCount = 1
CameraTunnel.maxChildCount = 2 --simultaneous connection of the antenna and the computer is allowed (for changing channels)
CameraTunnel.connectionInput = sm.interactable.connectionType.networking + sm.interactable.connectionType.networkCamera
CameraTunnel.connectionOutput = sm.interactable.connectionType.networking + sm.interactable.connectionType.composite
CameraTunnel.colorNormal = sm.color.new("#b3e000")
CameraTunnel.colorHighlight = sm.color.new("#e6e808")
CameraTunnel.componentType = "camera"
CameraTunnel.poseWeightCount = 1
cameraTunnels = cameraTunnels or {}
cameraTunnelSelfs = cameraTunnelSelfs or {}

function CameraTunnel:server_onCreate()
    self.sdata = self.storage:load() or {channel = 0}
    self.active = false
    cameraTunnelSelfs[self.interactable.id] = self

    self.camApi = nil
    self.staticCamApi = {}
    for methodName in pairs(RaycastCamera.createData(self, true)) do
        self.staticCamApi[methodName] = function(...)
            if not self.camApi then
                error("there is no connection to the camera", 2)
            end
            self.needSendBlick = true
            
            --for a proper stack traceback
            local result = {pcall(self.camApi[methodName], ...)}
            if result[1] then
                return unpack(result, 2)
            else
                error(result[2], 2)
            end
        end
    end

    self.staticCamApi["isCameraAvailable"] = function ()
        return not not self.camApi
    end

    self.staticCamApi["setCameraChannel"] = function (channel)
        checkArg(1, channel, "number")
        if channel >= 0 and channel <= 31 and channel % 1 == 0 then
            self.sdata.channel = channel
            self.channelChanged = true    
        else
            error("integer not in [0; 31]", 2)
        end
    end

    self.staticCamApi["getCameraChannel"] = function ()
        return self.sdata.channel
    end

    self.staticCamApi["isChannelBusy"] = function (channel)
        local parent = self.interactable:getSingleParent()
        local child = self.interactable:getChildren()[1]
        local antenna, camera
        if parent and child then
            if sc.antennasRefs[parent.id] then
                antenna = sc.antennasRefs[parent.id]
            elseif sc.camerasRefs[parent.id] then
                camera = sc.camerasRefs[parent.id]
                if sc.antennasRefs[child.id] then
                    antenna = sc.antennasRefs[child.id]
                end
            end
        end

        if antenna then
            for _, targetAntenna in ipairs(antenna:findTargets()) do
                if targetAntenna.activeState then
                    for _, tunnel in ipairs(targetAntenna.interactable:getParents()) do
                        local tunnelSelf = cameraTunnelSelfs[tunnel.id]
                        if tunnelSelf and
                            tunnel.shape.uuid == self.shape.uuid and
                            tunnel.shape.id ~= self.shape.id and
                            tunnelSelf.sdata.channel == channel and
                            tunnelSelf.transmitterMode then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    self.interactable.publicData = {
        sc_component = {
            type = CameraTunnel.componentType,
            api = self.staticCamApi
        }
    }
end

function CameraTunnel:server_onFixedUpdate()
    if self.channelChanged then
        self.storage:save(self.sdata)
        self:sv_dataRequest()
        self.channelChanged = nil
    end

    local parent = self.interactable:getSingleParent()
    local child = self.interactable:getChildren()[1]
    
    local antenna, camera
    if parent and child then
        if sc.antennasRefs[parent.id] then
            antenna = sc.antennasRefs[parent.id]
        elseif sc.camerasRefs[parent.id] then
            camera = sc.camerasRefs[parent.id]
            if sc.antennasRefs[child.id] then
                antenna = sc.antennasRefs[child.id]
            end
        end
    end

    self.camApi = nil
    self.transmitterMode = false
    local camApiTransmitted = false
    if antenna and camera then
        self.transmitterMode = true
        for _, targetAntenna in ipairs(antenna:findTargets()) do
            if targetAntenna.activeState then
                for _, tunnel in ipairs(targetAntenna.interactable:getChildren()) do
                    local tunnelSelf = cameraTunnelSelfs[tunnel.id]
                    if tunnelSelf and tunnel.shape.uuid == self.shape.uuid and tunnelSelf.sdata.channel == self.sdata.channel then
                        camApiTransmitted = true
                        cameraTunnels[tunnel.id] = {camera, antenna}
                    end
                end
            end
        end
    elseif antenna then
        local tunnel = cameraTunnels[self.interactable.id]
        if tunnel then
            if self.needSendBlick then
                antenna.sendBlick = true
                tunnel[2].sendBlick = true
            end

            self.camApi = tunnel[1].camApi
            cameraTunnels[self.interactable.id] = nil
        end
    end
    self.needSendBlick = nil

    self.active = self.camApi or camApiTransmitted
    if self.active ~= self.oldActive then
        self.oldActive = self.active
        self:sv_dataRequest()
    end
end

function CameraTunnel:sv_changeChannel(channel)
    self.sdata.channel = channel
    self.storage:save(self.sdata)
    self:sv_dataRequest()
end

function CameraTunnel:sv_dataRequest(_, caller)
    local cldata = {channel = self.sdata.channel, active = self.active}
    if caller then
        self.network:sendToClient(caller, "cl_updateLocalData", cldata)
    else
        self.network:sendToClients("cl_updateLocalData", cldata)
    end
end

function CameraTunnel:server_onDestroy()
    cameraTunnelSelfs[self.interactable.id] = nil
end

-------------------------------------------------------

function CameraTunnel:client_onCreate()
    self.network:sendToServer("sv_dataRequest")

    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Antenna.layout", false, { backgroundAlpha = 0.5 })
	self.gui:setTextChangedCallback("Channel", "cl_onChannelChanged")
	self.gui:setButtonCallback("Save", "cl_onSave")
    self.gui:setText("Title", "Camera Tunnel")
end

function CameraTunnel:cl_onChannelChanged(widget, data)
	if data:match("%d*") == data then
		local channel = tonumber(data)
		if channel >= 0 and channel <= 31 then
			self.channelToSend = channel
			self:cl_guiError(nil)
		else
			self:cl_guiError("integer not in [0; 31]")
		end
	else
		self:cl_guiError("bad integer")
	end
end

function CameraTunnel:cl_guiError(text)
	if text ~= nil then
		self.gui:setVisible("Save", false)
		self.gui:setText("Error", text)
	else
		self.gui:setVisible("Save", true)
		self.gui:setText("Error", "")
	end
end

function CameraTunnel:cl_onSave()
    self.cldata.channel = self.channelToSend
	self.network:sendToServer("sv_changeChannel", self.channelToSend)
	self.gui:close()
end

function CameraTunnel:client_onInteract(_, state)
    if state then
        self.gui:setText("Channel", tostring(self.cldata.channel))
        self.gui:open()
    end
end

function CameraTunnel:cl_updateLocalData(cldata)
    self.cldata = cldata
    self.channelToSend = self.cldata.channel
    self.interactable:setPoseWeight(0, cldata.active and 1 or 0)
    self.interactable:setUvFrameIndex(cldata.active and 6 or 0)
end