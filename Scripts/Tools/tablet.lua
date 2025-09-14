if not ScriptableComputer then
    dofile("$CONTENT_DATA/Scripts/ScriptableComputer.lua")
end
--dofile("$CONTENT_DATA/Scripts/Displays/DisplayBase.lua")

local rend = {"$CONTENT_DATA/Tools/Renderables/tablet.rend"}
tablet = class(ScriptableComputer)
sm.tool.preloadRenderables(rend)

---------------------------------------------------------------

function tablet.doQuat(x, y, z, w)
    local sin = math.sin(w / 2)
    return sm.quat.new(sin * x, sin * y, sin * z, math.cos(w / 2))
end

function tablet.eilToQuat(vec)
    return tablet.doQuat(1, 0, 0, vec.x) * tablet.doQuat(0, 1, 0, vec.y) * tablet.doQuat(0, 0, 1, vec.z)
end

---------------------------------------------------------------

function tablet:server_onCreate()
    ScriptableComputer.server_onCreate(self)

    self.player = self.tool:getOwner()
    self.character = self.player.character

    self.display = self.display or sc.display.createDisplay(self, self.data.screenX, self.data.screenY, self.data.screenV)
	sc.display.server_init(self.display)
    self.envSettings.vcomponents.display = {sc.display.server_createData(self.display)}
end

function tablet:server_onDestroy()
    ScriptableComputer.server_onDestroy(self)

    sc.display.server_destroy(self.display)
end

function tablet:server_onFixedUpdate(dt)
    self.player = self.tool:getOwner()
    self.character = self.player.character

    sc.display.server_update(self.display, dt)
    ScriptableComputer.server_onFixedUpdate(self)
end

function tablet:sv_toggle()
    self.storageData.active_button = not self.storageData.active_button
    self.network:sendToClient(self.player, "cl_alertMessage", self.storageData.active_button and "power on" or "power off")
end

---------------------------------------------------------------

function tablet:client_onCreate()
    if self.tool:isLocal() then
        self.player = self.tool:getOwner()
        self.character = self.player.character
        

        self.display = self.display or sc.display.createDisplay(self, self.data.screenX, self.data.screenY, self.data.screenV)
        self:cl_resetData()
    	sc.display.client_init(self.display)
    end
    ScriptableComputer.client_onCreate(self)
end

function tablet:client_onToggle()
    self.network:sendToServer("sv_toggle")
end

function tablet:client_onReload()
    ScriptableComputer.client_onInteract(self, nil, true)
    return true
end

function tablet:client_onEquippedUpdate(primaryState, secondaryState)
    if not self.tool:isLocal() then return end

    if primaryState == sm.tool.interactState.start then
        self.display.tablet_left = true
    end
    if primaryState == sm.tool.interactState.stop then
        self.display.tablet_left = nil
    end

    if secondaryState == sm.tool.interactState.start then
        self.display.tablet_right = true
    end
    if secondaryState == sm.tool.interactState.stop then
        self.display.tablet_right = nil
    end

    local dx, dy = sm.localPlayer.getMouseDelta()
    dx = dx * self.data.screenX * 0.8
    --dy = dy * self.data.screenX * 0.8
    --dx = math.floor(dx + 0.5)
    --dy = math.floor(dy + 0.5)
    self.display.tablet_posX = self.display.tablet_posX - dx
    --self.display.tablet_posY = self.display.tablet_posY - dy
    self.display.tablet_posY = self.data.screenX * constrain((0.18 - self.character.direction.z) * 1.2, 0, 1)
    if self.display.tablet_posX < 0 then self.display.tablet_posX = 0 end
    if self.display.tablet_posY < 0 then self.display.tablet_posY = 0 end
    if math.ceil(self.display.tablet_posX) >= self.display.width then self.display.tablet_posX = self.display.width - 1 end
    if math.ceil(self.display.tablet_posY) >= self.display.height then self.display.tablet_posY = self.display.height - 1 end


    --self.tool:updateFpAnimation("handbook_use_idle", 1, (math.sin(sm.game.getCurrentTick() * 0.05) * 0.02) + 0.5)
    return true, true
end

function tablet:client_onEquip()
    if not self.tool:isLocal() then return end

    self:cl_resetData()
    self.display.tablet_posX = self.display.width / 2
    self.display.tablet_posY = 0

    --self.tool:setTpRenderables(rend)
    --self.tool:setFpRenderables(rend)

    --self.direction = sm.localPlayer.getDirection()
end

function tablet:client_onUnequip()
    if not self.tool:isLocal() then return end
    self:cl_resetData()
end

function tablet:client_onDestroy()
    ScriptableComputer.client_onDestroy(self)

    if self.display then
        self:cl_resetData()
        sc.display.client_destroy(self.display)
        sc.display.client_update(self.display)
    end
end

function tablet.client_onFixedUpdate(self, dt)
    ScriptableComputer.client_onFixedUpdate(self, dt)
    if self.tool:isLocal() then
    	sc.display.client_update(self.display, dt)
    end
end

function tablet:cl_resetData()
    self.display.tablet_left = nil
    self.display.tablet_right = nil
    
    self.display.tablet_posX = nil
    self.display.tablet_posY = nil
end





function tablet.client_onReceiveDrawStack(self, stack)
	sc.display.client_drawStack(self.display, stack)
end

function tablet.client_onInteract(self, character, state)
	sc.display.client_onInteract(self.display, character, state)
end

function tablet.client_canInteract(self, character)
	return sc.display.client_canInteract(self.display, character)
end

function tablet.client_canTinker(self, character)
	return sc.display.client_canTinker(self.display, character)
end

function tablet.client_onTinker(self, character, state)
	sc.display.client_onTinker(self.display, character, state)
end

function tablet.client_onDataResponse(self, data)
	sc.display.client_onDataResponse(self.display, data)
end

function tablet.server_recvPress(self, p, client)
	sc.display.server_recvPress(self.display, p, client)
end

function tablet.server_onDataRequired(self, client)
	sc.display.server_onDataRequired(self.display, client)
end

---------------------------------------------------------------

function tablet:cl_onExample(...)
    ScriptableComputer.cl_onExample(self, ...)
end