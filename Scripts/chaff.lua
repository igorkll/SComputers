chaff = class()
chaff.maxParentCount = 1
chaff.maxChildCount = 0
chaff.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.logic
chaff.connectionOutput = sm.interactable.connectionType.none
chaff.colorNormal = sm.color.new(0x7F7F7Fff)
chaff.colorHighlight = sm.color.new(0xFFFFFFff)
chaff.componentType = "chaff" --absences can cause problems
chaff.maxCharges = 5 * (40 / 4)

function chaff:server_onCreate()
    self:sv_reload()

    self.interactable.publicData = {
        sc_component = {
            type = chaff.componentType,
            api = {
                isAvailable = function()
                    return self:sv_isAvailable()
                end,
                push = function()
                    return self:sv_push()
                end,
                shot = function()
                    return self:sv_shot()
                end,
                maxCharges = function()
                    return chaff.maxCharges
                end,
                getCharges = function()
                    return self.charges
                end
            }
        }
    }
end

function chaff:server_onFixedUpdate()
    local onLift = self.shape.body:isOnLift()
    if onLift and not self.onLift then
        self:sv_reload()
    end
    self.onLift = onLift

    if not scomputers.realIsComputerConnected(self.interactable) then
        local parent = self.interactable:getSingleParent()
        if parent and parent:isActive() then
            self:sv_push()
        end
    end

    if self.pushTimer then
        if self.pushTimer % 4 == 0 then
            if not self:sv_shot() then
                self.pushTimer = nil
            end
        end
        if self.pushTimer then
            self.pushTimer = self.pushTimer + 1
        end
    end

    if self.shotFlag then
        local body = self:sv_getBodyForChraff()
        if body then
            scomputers.addChaffObject(self.shape.worldPosition, body.id, body.mass)
        else
            scomputers.addChaffObject(self.shape.worldPosition, math.random(1, 99999), (math.random() * (15000 - 50)) + 50)
        end
        self.network:sendToClients("cl_n_addChaffObject", self.shape.worldPosition)
        
        self.shotFlag = nil
    end
end

function chaff:sv_getBodyForChraff()
    local ctick = sm.game.getCurrentTick()
    if self.bodyCounter_updateTime and ctick - self.bodyCounter_updateTime > 160 then
        self.bodyCounter = 0
    end
    self.bodyCounter = (self.bodyCounter or 0) + 1
    self.bodyCounter_updateTime = ctick
    return self.shape.body:getCreationBodies()[self.bodyCounter] --after it exceeds the number of bodies in the creation, there will be nil, which will lead to the generation of new random bodies
end

function chaff:sv_isAvailable()
    return self.isAvailable and self.charges > 0
end

function chaff:sv_reload()
    self.isAvailable = true
    self.charges = chaff.maxCharges
end

function chaff:sv_push()
    if not self.isAvailable then
        return false
    end
    self.pushTimer = 0
    self.isAvailable = false
    return true
end

function chaff:sv_shot()
    if self.charges <= 0 then
        return false
    end
    self.charges = self.charges - 1
    self.shotFlag = true
    return true
end

function chaff:cl_n_addChaffObject(position)
    scomputers.addChaffObject(position)
end