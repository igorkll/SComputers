pistonController = class()
pistonController.maxParentCount = 1
pistonController.maxChildCount = -1
pistonController.connectionInput = sm.interactable.connectionType.composite
pistonController.connectionOutput = sm.interactable.connectionType.piston
pistonController.colorNormal = sm.color.new(0x8c6208ff)
pistonController.colorHighlight = sm.color.new(0xe39a01ff)
pistonController.componentType = "pistonController" --absences can cause problems

pistonController.defaultVelocity = 3
pistonController.defaultLengthLimit = 15
pistonController.defaultSpeedLimit = 10
pistonController.defaultForceLimit = 100000

pistonController.pistonsRestrictions = {
    ["8c741785-5eae-4c48-9f99-d62bf522a83f"] = {
        length = 7
    },
    ["31f14f52-f4d8-4b9f-9d6e-7412497c9284"] = {
        length = 9
    },
    ["46396518-8c29-4da9-81bb-a020f4baf5b2"] = {
        length = 11
    },
    ["7324219e-2b19-4098-baa3-9876984ead08"] = {
        length = 13
    },
    ["2f004fdf-bfb0-46f3-a7ac-7711100bee0c"] = {
        length = 15
    },
    ["6b919779-1aa4-4d1a-9186-513d0965dc98"] = {
        length = 255,
        speed = 50,
        force = 10000000
    }
}

function pistonController:server_onCreate()
    self.sdata = self.storage:load() or {label = ""}
    self:sv_setData(self.sdata)

    self.interactable.publicData = {
        sc_component = {
            type = pistonController.componentType,
            api = {
                setLength = function(index, length)
                    checkArg(1, index, "number")
                    checkArg(2, length, "number")
                    self.pistonsLength[index] = length
                end,
                getLength = function(index)
                    checkArg(1, index, "number")
                    return self.pistonsLength[index] or 0
                end,

                setVelocity = function(index, velocity)
                    checkArg(1, index, "number")
                    checkArg(2, velocity, "number")
                    self.pistonsVelocity[index] = velocity
                end,
                getVelocity = function(index)
                    checkArg(1, index, "number")
                    return self.pistonsVelocity[index] or pistonController.defaultVelocity
                end,

                setForce = function(index, force)
                    checkArg(1, index, "number")
                    checkArg(2, force, "number")
                    self.pistonsForce[index] = force
                end,
                getForce = function(index)
                    checkArg(1, index, "number")
                    return self.pistonsForce[index] or pistonController.defaultForceLimit
                end,
                

                getPistonsCount = function()
                    return self.pistonsCount
                end,
                isPistonAvailable = function(index)
                    checkArg(1, index, "number")
                    return not not self.pistonsAvailable[index]
                end,
                getMaxVelocity = function(index)
                    checkArg(1, index, "number")
                    local restrictions = self.pistonsAvailable[index]
                    if restrictions then
                        return restrictions.speed or pistonController.defaultSpeedLimit
                    end
                end,
                getMaxLength = function(index)
                    checkArg(1, index, "number")
                    local restrictions = self.pistonsAvailable[index]
                    if restrictions then
                        return restrictions.length or pistonController.defaultLengthLimit
                    end
                end,
                getMaxForce = function(index)
                    checkArg(1, index, "number")
                    local restrictions = self.pistonsAvailable[index]
                    if restrictions then
                        return restrictions.force or pistonController.defaultForceLimit
                    end
                end
            },
            label = function()
                return self.sdata.label
            end
        }
    }
    
    self.pistonsCount = 0
    self.pistonsLength = {}
    self.pistonsVelocity = {}
    self.pistonsAvailable = {}
    self.pistonsForce = {}
    self:sv_update()
end

function pistonController:server_onFixedUpdate()
    self:sv_update()
end

function pistonController:sv_update()
    self.pistonsAvailable = {}
    self.pistonsCount = 0
    for k, v in pairs(self.interactable:getPistons()) do
        local index = k - 1
        local restrictions = pistonController.pistonsRestrictions[tostring(v.uuid)]
        v:setTargetLength(
            math.max(math.min(restrictions.length or pistonController.defaultLengthLimit, self.pistonsLength[index] or 0), 0),
            math.max(math.min(restrictions.speed or pistonController.defaultSpeedLimit, self.pistonsVelocity[index] or pistonController.defaultVelocity), 0),
            math.max(math.min(restrictions.force or pistonController.defaultForceLimit, self.pistonsForce[index] or pistonController.defaultForceLimit), 0)
        )

        self.pistonsAvailable[index] = restrictions
        self.pistonsCount = self.pistonsCount + 1
    end
end

function pistonController:sv_setData(data)
	data.label = tostring(data.label or "")
    self.sdata = data
    self.network:sendToClients("cl_setData", self.sdata)
    self.storage:save(self.sdata)
end

function pistonController:sv_dataRequest(_, player)
    self.network:sendToClient(player, "cl_setData", self.sdata)
end

-------------------------------------------------------------------

function pistonController:client_onCreate()
	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/MotorLabel.layout", false, { backgroundAlpha = 0 })
	self.gui:setTextChangedCallback("Label", "cl_onLabelChanged")
	self.gui:setButtonCallback("Save", "cl_onLabelChange")
    self.gui:setText("Title", "PistonController Label")

    self.network:sendToServer("sv_dataRequest")
end

function pistonController:cl_onLabelChanged(_, data)
	if #data <= 32 then
		self.cl_temp_label = data
        self:cl_guiError(nil)
	else
		self:cl_guiError("label is too long")
	end
end

function pistonController:cl_setData(data)
    self.csdata = data
end

function pistonController:cl_guiError(text)
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

function pistonController:cl_onLabelChange()
    self.csdata.label = self.cl_temp_label
    self.network:sendToServer("sv_setData", self.csdata)
	self.gui:close()
end

function pistonController:client_onInteract(_, state)
	if state and self.csdata then
        self.cl_temp_label = self.csdata.label
        self.gui:setText("Label", tostring(self.cl_temp_label))
	    self:cl_guiError(nil)
		self.gui:open()
	end
end