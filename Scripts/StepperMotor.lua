dofile '$CONTENT_DATA/Scripts/Config.lua'

StepperMotor = class(nil)

StepperMotor.maxParentCount = -1
StepperMotor.maxChildCount = 16
StepperMotor.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.electricity
StepperMotor.connectionOutput = sm.interactable.connectionType.bearing
StepperMotor.colorNormal = sm.color.new(0x9f6213ff)
StepperMotor.colorHighlight = sm.color.new(0xde881bff)
StepperMotor.componentType = "motor"

--StepperMotor.nonActiveImpulse = 0.25
StepperMotor.nonActiveImpulse = 0
StepperMotor.chargeAdditions = 4000000

-- SERVER --

function StepperMotor:sv_resourcesLimit()
	return self.data and self.data.survival and sc.restrictions.resourceConsumption
end

function StepperMotor.server_createData(self)
	return {
		getVelocity = function () return self.velocity end,
		setVelocity = function (v)
		    if type(v) == "number" then
				self.velocity = sm.util.clamp(v, -self.mVelocity, self.mVelocity)
			else
				error("Value must be number")
			end
		end,
		getStrength = function () return self.maxImpulse end,
		setStrength = function (v)
		    if type(v) == "number" then
				self.maxImpulse = sm.util.clamp(v, 0, self.mImpulse)
			else
				error("Value must be number")
			end
		end,
		getAngle = function () return self.angle end,
		setAngle = function (v)
			if type(v) == "number" or type(v) == "nil" then
				self.angle = v and sm.util.clamp(v, -3.402e+38, 3.402e+38) or nil
			else
				error("Value must be number or nil")
			end
		end,
		isActive = function () return self.isActive end,
		setActive = function (v) 
			if type(v) == "boolean" then
				self.isActive = v
			elseif type(v) == "number" then
				self.isActive = v > 0
			else
				error("Type must be boolean or number")
			end
		end,

		getAvailableBatteries = function ()
			return self:sv_resourcesLimit() and (self.batteries or 0) or math.huge
		end,
		getCharge = function ()
			return self.sdata.energy
		end,
		getChargeDelta = function ()
			return self.chargeDelta
		end,
		isWorkAvailable = function ()
			if self:sv_resourcesLimit() then
				if self.sdata.energy > 0 then
					return true
				end

				if self.batteries and self.batteries > 0 then
					return true
				end

				return false
			end
			return true
		end,
		getBearingsCount = function ()
			return self.bearingsCount or 0
		end,

		maxStrength = function ()
			return self.mImpulse
		end,
		maxVelocity = function ()
			return self.mVelocity
		end,
		getChargeAdditions = function ()
			return StepperMotor.chargeAdditions
		end,
		setSoundType = function (num)
			checkArg(1, num, "number")
			self.soundtype = num
		end,
		getSoundType = function ()
			return self.soundtype
		end,
		getBearingAngle = function(i)
			local angle = (self.bearingList[i] or error("incorrect index of bearing", 2)).angle
			return -angle
		end
	}
end

function StepperMotor:sv_getBearingData()
	self.bearingList = self.interactable:getBearings()
	self.bearingsCount = #self.bearingList
end

function StepperMotor.server_onCreate(self)
	self.chargeDelta = 0
	
	self.soundtype = 1
	self.mVelocity = 10000
	self.mImpulse = 10000000
	self.sdata = self.storage:load() or {energy = 0, label = ""}
	self:sv_setData(self.sdata)
	if self.data and self.data.survival then
		self.mVelocity = self.data.v or 10
		self.mImpulse = self.data.i or 10
	else
		self.isCreative = true
	end

	self.velocity = 0
	self.maxImpulse = 0
	self.angle = nil
	self.isActive = false
	self.wasActive = false
	self:sv_getBearingData()

	sc.motorsDatas[self.interactable:getId()] = self:server_createData()

	if sc.creativeCheck(self, self.isCreative) then return end
end

function StepperMotor:sv_setData(data)
	data.label = tostring(data.label or "")
    self.sdata = data
	self.interactable.publicData = {
        label = self.sdata.label
    }
    self.network:sendToClients("cl_setData", self.sdata)
    self.storage:save(self.sdata)
end

function StepperMotor.server_onDestroy(self)
	sc.motorsDatas[self.interactable:getId()] = nil
end

function StepperMotor.server_onFixedUpdate(self, dt)
    if sc.creativeCheck(self, self.isCreative) then return end
    
	self:sv_getBearingData()

	--------------------------------------------------------

	local container
	for _, parent in ipairs(self.interactable:getParents()) do
		if parent:hasOutputType(sm.interactable.connectionType.electricity) then
			container = parent:getContainer(0)
			break
		end
	end

	self.batteries = self:sv_mathCount()
	self.chargeDelta = 0

	--------------------------------------------------------

	local active = self.isActive
	if active and self.sdata.energy <= 0 and self:sv_resourcesLimit() then
		self:sv_removeItem()
		if self.sdata.energy <= 0 then
			active = nil
		end
	end

	if active then
		if self.angle == nil then
			for k, v in pairs(self.interactable:getBearings()) do
				v:setMotorVelocity(self.velocity, self.maxImpulse)
			end
		else
			for k, v in pairs(self.interactable:getBearings()) do
				v:setTargetAngle(self.angle, self.velocity, self.maxImpulse)
			end
		end

		if self.maxImpulse > 0 then
			for k, v in pairs(self.interactable:getBearings()) do
				self.chargeDelta = self.chargeDelta + math.abs(v:getAppliedImpulse())				
			end
			self.sdata.energy = self.sdata.energy - self.chargeDelta
		end
	elseif self.wasActive then
		for k, v in pairs(self.interactable:getBearings()) do
			v:setMotorVelocity(0, StepperMotor.nonActiveImpulse)
		end
	end
	self.wasActive = active

	if self.sdata.energy < 0 then
		self.sdata.energy = 0
	end

	local rpm = math.min(1, math.abs(self.velocity) / 100)
	local load = (self.chargeDelta / self.maxImpulse) / (self.bearingsCount or 0)
	if self.old_active ~= active or
	rpm ~= self.old_rpm or
	load ~= self.old_load or
	self.soundtype ~= self.old_type then
		if active and self.soundtype ~= 0 then
			local lload, lrpm = load, rpm
			if self.soundtype == 1 then
				lrpm = lload
			end
			self.network:sendToClients("cl_setEffectParams", {
				rpm = lrpm,
				load = lload,
				soundtype = self.soundtype
			})
		else
			self.network:sendToClients("cl_setEffectParams")
		end
	end
	self.old_active = active
	self.old_rpm = rpm
	self.old_load = load
	self.old_type = self.soundtype

	if sc.needSaveData() and self.sdata.energy ~= self.oldEnergy then
		self.storage:save(self.sdata)
		self.oldEnergy = self.sdata.energy
	end
end

function StepperMotor:sv_removeItem()
	for _, parent in ipairs(self.interactable:getParents()) do
        if parent:hasOutputType(sm.interactable.connectionType.electricity) then
			local container = parent:getContainer(0)
			if sm.container.canSpend(container, obj_consumable_battery, 1) then
				sm.container.beginTransaction()
				sm.container.spend(container, obj_consumable_battery, 1, true)
				if sm.container.endTransaction() then
					self.sdata.energy = self.sdata.energy + StepperMotor.chargeAdditions
					break
				end
			end
		end
	end
end

function StepperMotor:sv_mathCount()
    local count = 0
    for _, parent in ipairs(self.interactable:getParents()) do
        if parent:hasOutputType(sm.interactable.connectionType.electricity) then
            local container = parent:getContainer(0)
            for i = 0, container.size - 1 do
                count = count + (container:getItem(i).quantity)
            end
		end
	end
    return count
end

function StepperMotor:sv_dataRequest(_, player)
    self.network:sendToClient(player, "cl_setData", self.sdata)
end


-- CLIENT --

function StepperMotor:client_onCreate()
	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/MotorLabel.layout", false, { backgroundAlpha = 0 })
	self.gui:setTextChangedCallback("Label", "cl_onLabelChanged")
	self.gui:setButtonCallback("Save", "cl_onLabelChange")

	self.network:sendToServer("sv_dataRequest")
end

function StepperMotor:cl_onLabelChanged(_, data)
	if #data <= 32 then
		self.cl_temp_label = data
        self:cl_guiError(nil)
	else
		self:cl_guiError("label is too long")
	end
end

function StepperMotor:cl_onLabelChange()
    self.csdata.label = self.cl_temp_label
    self.network:sendToServer("sv_setData", self.csdata)
	self.gui:close()
end

function StepperMotor:client_onInteract(_, state)
	if state and self.csdata then
        self.cl_temp_label = self.csdata.label
        self.gui:setText("Label", tostring(self.cl_temp_label))
	    self:cl_guiError(nil)
		self.gui:open()
	end
end

function StepperMotor:cl_guiError(text)
	if text ~= nil then
		self.gui:setVisible("Save", false)
        self.gui:setVisible("Error", true)
		self.gui:setText("Error", text)
	else
		self.gui:setVisible("Save", true)
        self.gui:setVisible("Error", false)
		self.gui:setText("Error", "")
	end
end

function StepperMotor:cl_setData(data)
    self.csdata = data
end

function StepperMotor:client_onDestroy()
	self.gui:destroy()
end

function StepperMotor:cl_setEffectParams(tbl)
	if tbl then
		if tbl.soundtype ~= self.cl_oldSoundType then
			if self.effect then
				self.effect:setAutoPlay(false)
				self.effect:stop()
				self.effect:destroy()
				self.effect = nil
			end
			self.cl_oldSoundType = tbl.soundtype
		end

		if not self.effect then
			if tbl.soundtype == 1 or tbl.soundtype == 3 then
				self.effect = sm.effect.createEffect("ElectricEngine - Level 2", self.interactable)
			elseif tbl.soundtype == 2 then
				self.effect = sm.effect.createEffect("GasEngine - Level 3", self.interactable)
			end
			
			if self.effect then
				self.effect:setAutoPlay(true)
				self.effect:start()
			end
		end

		if self.effect then
			self.effect:setParameter("rpm", tbl.rpm)
			self.effect:setParameter("load", tbl.load)
		end
	else
		if self.effect then
			self.effect:setAutoPlay(false)
			self.effect:stop()
			self.effect:destroy()
			self.effect = nil
		end
	end
end