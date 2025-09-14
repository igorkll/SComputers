dofile("$CONTENT_DATA/Scripts/Config.lua")
led = class()
led.maxParentCount = 1
led.maxChildCount = -1
led.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.loopConnection
led.connectionOutput = sm.interactable.connectionType.loopConnection
led.colorNormal = sm.color.new("#d4d4d4")
led.colorHighlight = sm.color.new("#ffffff")
led.componentType = "led"
led.scaleAdd = 0.001
led.effectScale = sm.vec3.new(0.25 + led.scaleAdd, 0.25 + led.scaleAdd, 0.25 + led.scaleAdd)

ledsDatas = ledsDatas or {}

local black = sm.color.new(0, 0, 0)
local ledKey = {}

function led:server_onCreate()
    self.currentColor = sm.color.new(0, 0, 0)
    self.glow = 1

    self.interactable.publicData = {
        sc_component = {
            type = led.componentType,
            api = {
                setColor = function (index, color)
                    color = sc.formatColor(color, true)

                    if index <= 0 then
                        self.currentColor = color
                        return
                    end

                    index = index - 1
                    for _, child in ipairs(self.lastChilds or self.interactable:getChildren()) do
                        if ledsDatas[child.id] then
                            ledsDatas[child.id].setColor(index, color)
                        end
                    end
                end,
                setGlow = function (index, multiplier)
                    checkArg(1, multiplier, "number")

                    if index <= 0 then
                        if multiplier < 0 or multiplier > 1 then
                            error("the range should be from 0 to 1", 2)
                        end
                        if multiplier ~= self.glow then
                            self.glow = multiplier
                        end
                        return
                    end

                    index = index - 1
                    for _, child in ipairs(self.lastChilds or self.interactable:getChildren()) do
                        if ledsDatas[child.id] then
                            ledsDatas[child.id].setGlow(index, multiplier)
                        end
                    end
                end,
                getStripLength = function(lLedKey, firstLed)
                    if lLedKey ~= ledKey then
                        firstLed = nil
                    elseif firstLed == self.interactable.id then
                        error("a cycle has been found in the connection of LEDs")
                    end

                    local len = 0
                    for _, child in ipairs(self.lastChilds or self.interactable:getChildren()) do
                        if ledsDatas[child.id] then
                            local llen = ledsDatas[child.id].getStripLength(ledKey, firstLed or self.interactable.id)
                            if llen > len then
                                len = llen
                            end
                        end
                    end
                    return len + 1
                end
            }
        }
    }
    self.interactable.publicData.sc_component.api.getStripLenght = self.interactable.publicData.sc_component.api.getStripLength --legacy
    ledsDatas[self.interactable.id] = self.interactable.publicData.sc_component.api

    self.network:sendToClients("cl_setColor", self:makeColor())
    if self.shape.color ~= black then
        self.shape:setColor(black)
    end
end

function led:server_onFixedUpdate()
	if sc.needScreenSend() then self.allow_update = true end
    
    if sm.game.getCurrentTick() % 20 == 0 then
        self.lastChilds = self.interactable:getChildren()
    end

    if self.allow_update and (self.currentColor ~= self._currentColor or self.glow ~= self._glow) then
		self.network:sendToClients("cl_setColor", self:makeColor())

		self._currentColor = sm.color.new(self.currentColor.r, self.currentColor.g, self.currentColor.b, self.currentColor.a)
        self._glow = self.glow
        self.allow_update = nil
    end
end

function led:server_onDestroy()
    ledsDatas[self.interactable.id] = nil
end

function led:sv_dataRequest(_, caller)
    self.network:sendToClient(caller, "cl_setColor", self:makeColor())
end

function led:makeColor()
    return sm.color.new(self.currentColor.r, self.currentColor.g, self.currentColor.b, self.glow)
end

------------------------------------------------

function led:client_onCreate()
    self.network:sendToServer("sv_dataRequest")

    self.effect = sm.effect.createEffect(canvasAPI.getEffectName(), self.interactable)
    self.effect:setParameter("uuid", self.shape.uuid)
    self.effect:setScale(led.effectScale)
    self.effect:start()
end

function led:cl_setColor(color)
    self.effect:setParameter("color", color)
end