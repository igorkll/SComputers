sm.classhook = sm.classhook or {}
sm.classhook.hook = sm.classhook.hook or {}
sm.classhook.hook.class = sm.classhook.hook.class or {}
sm.classhook.hook.class["*"] = sm.classhook.hook.class["*"] or {}

local inputHandler

table.insert(sm.classhook.hook.class["*"],
function(class_tbl, class_name)
    local old_client_onAction = class_tbl.client_onAction
    if old_client_onAction then
        function class_tbl.client_onAction(self, action, state)
            inputHandler(self, action, state)
            return old_client_onAction(self, action, state)
        end
    end
end)

local _HOOK_LEFT, _HOOK_RIGHT = false, false

function inputHandler(self, action, state)
    if action == sm.interactable.actions.create then
        _HOOK_LEFT = state
    elseif action == sm.interactable.actions.attack then
        _HOOK_RIGHT = state
    end
end

------------------------------------------------------------------------

wasd_autotool = class()
wasd_autotool.equipWhileSeated = true

function wasd_autotool:server_onFixedUpdate()
    local player = self.tool:getOwner()
    local seat = player.character:getLockingInteractable()

    local okay, seatedCharacter
    if seat then
        okay, seatedCharacter = pcall(seat.getSeatCharacter, seat)
    end

    if seat and okay and seatedCharacter and sm.exists(seatedCharacter) and player and sm.exists(player) and sm.exists(player.character) and seatedCharacter.id == player.character.id then
        if not self.enabled then
            self.network:sendToClient(player, "cl_enable")
            self.enabled = true
        end
    elseif self.enabled then
        self.network:sendToClient(player, "cl_disable")
        self.enabled = false
    end
end

function wasd_autotool:sv_response(info, player)
    sc.wasdInfo[player.character.id] = sc.wasdInfo[player.character.id] or {}
    local wasdInfo = sc.wasdInfo[player.character.id]
    local tick = sm.game.getCurrentTick()

    if info == 1 then
        wasdInfo.button_q = tick
    elseif info == 2 then
        wasdInfo.button_r = tick
    elseif info == 3 then
        wasdInfo.mouse_l = true
    elseif info == 4 then
        wasdInfo.mouse_l = false
    elseif info == 5 then
        wasdInfo.mouse_r = true
    elseif info == 6 then
        wasdInfo.mouse_r = false
    elseif info == 7 then
        wasdInfo.mouse_c = true
    elseif info == 8 then
        wasdInfo.mouse_c = false
    end
end

----------------------------------------------------------

local isBetter = better and better.isAvailable()
local mouseApiAvailable = isBetter and better.mouse and pcall(better.mouse.isLeft)
local keyboardApiAvailable = isBetter and better.keyboard and pcall(better.keyboard.isKey, 0)

local old_q_state = false
local old_r_state = false
local old_mouse_l_state = false
local old_mouse_c_state = false
local old_mouse_r_state = false

function wasd_autotool:cl_process()

end

function wasd_autotool:cl_processWithoutBetterApi()
    --print(_HOOK_LEFT, _HOOK_RIGHT)
    if _HOOK_LEFT ~= old_mouse_l_state then
        if _HOOK_LEFT then
            sc.localInputState.mouse_l = true
            self.network:sendToServer("sv_response", 3)
        else
            sc.localInputState.mouse_l = false
            self.network:sendToServer("sv_response", 4)
        end
    end
    old_mouse_l_state = _HOOK_LEFT
    
    if _HOOK_RIGHT ~= old_mouse_r_state then
        if _HOOK_RIGHT then
            sc.localInputState.mouse_r = true
            self.network:sendToServer("sv_response", 5)
        else
            sc.localInputState.mouse_r = false
            self.network:sendToServer("sv_response", 6)
        end
    end
    old_mouse_r_state = _HOOK_RIGHT
end

function wasd_autotool:cl_processWithBetterApi()
    if mouseApiAvailable then
        local left = better.mouse.isLeft()
        local center = better.mouse.isCenter()
        local right = better.mouse.isRight()
        
        if left ~= old_mouse_l_state then
            if left then
                sc.localInputState.mouse_l = true
                self.network:sendToServer("sv_response", 3)
            else
                sc.localInputState.mouse_l = false
                self.network:sendToServer("sv_response", 4)
            end
        end
        old_mouse_l_state = left
        
        if center ~= old_mouse_c_state then
            if center then
                self.network:sendToServer("sv_response", 7)
            else
                self.network:sendToServer("sv_response", 8)
            end
        end
        old_mouse_c_state = center

        if right ~= old_mouse_r_state then
            if right then
                sc.localInputState.mouse_r = true
                self.network:sendToServer("sv_response", 5)
            else
                sc.localInputState.mouse_r = false
                self.network:sendToServer("sv_response", 6)
            end
        end
        old_mouse_r_state = right
    end

    if keyboardApiAvailable then    
        local q_state = better.keyboard.isKey(better.keyboard.keys.q)
        local r_state = better.keyboard.isKey(better.keyboard.keys.r)
        
        local q_pulse = q_state and not old_q_state
        old_q_state = q_state
    
        if q_pulse then
            self.network:sendToServer("sv_response", 1)
        end
        
        local r_pulse = r_state and not old_r_state
        old_r_state = r_state

        if r_pulse then
            self.network:sendToServer("sv_response", 2)
        end
    end
end

function wasd_autotool:client_onFixedUpdate()
    if not self.tool:isLocal() then
        return
    end
    
    if self.forceToolEnabled then
        sm.tool.forceTool(self.tool)
    end

    self:cl_process()

    if isBetter then
        self:cl_processWithBetterApi()
    else
        self:cl_processWithoutBetterApi()
    end
end

function wasd_autotool:client_onEquippedUpdate(primaryState, secondaryState)
    if isBetter then
        return true, true
    end

    if self.tool:isLocal() then
        if primaryState == sm.tool.interactState.start then
            sc.localInputState.mouse_l = true
            self.network:sendToServer("sv_response", 3)
        elseif primaryState == sm.tool.interactState.stop then
            sc.localInputState.mouse_l = false
            self.network:sendToServer("sv_response", 4)
        end
        
        if secondaryState == sm.tool.interactState.start then
            sc.localInputState.mouse_r = true
            self.network:sendToServer("sv_response", 5)
        elseif secondaryState == sm.tool.interactState.stop then
            sc.localInputState.mouse_r = false
            self.network:sendToServer("sv_response", 6)
        end
    end

    return true, true
end

function wasd_autotool:client_onToggle()
    if isBetter then
        return true
    end

    if self.tool:isLocal() then
        self.network:sendToServer("sv_response", 1)
    end

    return true
end

function wasd_autotool:client_onReload()
    if isBetter then
        return true
    end

    if self.tool:isLocal() then
        self.network:sendToServer("sv_response", 2)
    end

    return true
end

function wasd_autotool:cl_enable()
    if isBetter then
        return
    end

    sm.tool.forceTool(self.tool)
    self.forceToolEnabled = true
end

function wasd_autotool:cl_disable()
    if isBetter then
        return
    end

    sm.tool.forceTool(nil)
    self.forceToolEnabled = false
end