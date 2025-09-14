dofile("$CONTENT_DATA/Scripts/Config.lua")
wasd = class()
wasd.maxParentCount = 1
wasd.maxChildCount = 1
wasd.connectionInput = sm.interactable.connectionType.power
wasd.connectionOutput = sm.interactable.connectionType.composite
wasd.colorNormal = sm.color.new("#007355")
wasd.colorHighlight = sm.color.new("#00e4aa")
wasd.componentType = "wasd"

local function getWasdInfo(self)
	local parent = self.interactable:getSingleParent()
	if parent then
		local seated = parent:getSeatCharacter()
		if seated then
			local wasdInfo = sc.wasdInfo[seated.id]
			if wasdInfo then
				return wasdInfo
			end
		end
	end
end

function wasd:server_onCreate()
    self.interactable.publicData = {
        sc_component = {
            type = wasd.componentType,
            api = {
                isSeated = function ()
                    return not not self.seated
                end,
                isW = function ()
                    return not not self.W
                end,
                isS = function ()
                    return not not self.S
                end,
                isA = function ()
                    return not not self.A
                end,
                isD = function ()
                    return not not self.D
                end,
                getADvalue = function ()
                    return self.AD or 0
                end,
                getWSvalue = function ()
                    return self.WS or 0
                end,

				isMouseL = function()
					local wasdInfo = getWasdInfo(self)
					return not not (wasdInfo and wasdInfo.mouse_l)
				end,
				isMouseC = function()
					local wasdInfo = getWasdInfo(self)
					return not not (wasdInfo and wasdInfo.mouse_c)
				end,
				isMouseR = function()
					local wasdInfo = getWasdInfo(self)
					return not not (wasdInfo and wasdInfo.mouse_r)
				end,
				isQ = function()
					local wasdInfo = getWasdInfo(self)
					return not not (wasdInfo and wasdInfo.button_q == sm.game.getCurrentTick())
				end,
				isR = function()
					local wasdInfo = getWasdInfo(self)
					return not not (wasdInfo and wasdInfo.button_r == sm.game.getCurrentTick())
				end
            }
        }
    }
end

function wasd:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    if parent then
        self.WS = parent:getPower()
        self.seated = parent:isActive()

		if not self.seated and self._oldSeated then
			sc.wasdInfo[self._oldSeated] = {}
		end

		local seated = parent:getSeatCharacter()
		self._oldSeated = seated and seated.id or self._oldSeated
    else
        self.seated = false
    end
    if not self.seated then
        self.WS = 0
    end
    self.W = self.WS > 0
    self.S = self.WS < 0

    if self.seated ~= self.old_active then
        self.old_active = self.seated
        self.network:sendToClients("cl_setActive", self.old_active)
    end
end

function wasd:sv_dataRequest()
    self.old_active = nil
end

function wasd:client_onCreate()
    self.network:sendToServer("sv_dataRequest")
end

function wasd:client_onFixedUpdate()
    if sm.isHost then
        local ADValue =  0
        local count = 0
        local seated = false
        for k, v in pairs(self.interactable:getParents()) do
            if v:isActive() then
                seated = true
            end
            local _s_uuid = tostring(v:getShape():getShapeUuid())
            if v:getType() == "steering" or _s_uuid == "ccaa33b6-e5bb-4edc-9329-b40f6efe2c9e" or _s_uuid == "e627986c-b7dd-4365-8fd8-a0f8707af63d" then
                ADValue = ADValue + (v:getPoseWeight(0) - 0.5) * 2
                count = count + 1
            elseif v:hasSteering() then
                ADValue = ADValue + v:getSteeringAngle()
                count = count + 1
            else
                ADValue = ADValue + v:getPower()
                count = count + 1
            end
        end
        if count > 0 then
            ADValue = constrain(ADValue / count, -1, 1)
        end

        if not seated then
            ADValue = 0
        end
        self.AD = ADValue
        self.A = ADValue < 0
        self.D = ADValue > 0
        if self.OLD_AD then
            if self.AD < self.OLD_AD then self.D = false end
            if self.AD > self.OLD_AD then self.A = false end
        end
        self.OLD_AD = self.AD
    end
end

function wasd:cl_setActive(active)
    self.interactable:setUvFrameIndex(active and 6 or 0)
end