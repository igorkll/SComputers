wasd_autotool = class()

function wasd_autotool:server_onFixedUpdate()
    local player = self.tool:getOwner()
    local seat = player.character:getLockingInteractable()

    local seatedCharacter
    if seat then
        seatedCharacter = seat:getSeatCharacter()
    end

    if seat and seatedCharacter and sm.exists(seatedCharacter) and player and sm.exists(player) and sm.exists(player.character) and seatedCharacter.id == player.character.id then
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
    local tick = sm.game.getCurrentTick() + 1

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
local mouseApiAvailable = isBetter and pcall(better.mouse.isLeft)
local keyboardApiAvailable = isBetter and pcall(better.keyboard.isKey, 0)

local old_q_state = false
local old_r_state = false
local old_mouse_l_state = false
local old_mouse_c_state = false
local old_mouse_r_state = false

function wasd_autotool:client_onFixedUpdate()
    if isBetter then
        local left = better.mouse.isLeft()
        local center = better.mouse.isCenter()
        local right = better.mouse.isRight()

        local q_state = better.keyboard.isKey(better.keyboard.keys.q)
        local r_state = better.keyboard.isKey(better.keyboard.keys.r)

        if self.tool:getOwner().character:getLockingInteractable() then
            if mouseApiAvailable then
                if left ~= old_mouse_l_state then
                    if left then
                        self.network:sendToServer("sv_response", 3)
                    else
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
                        self.network:sendToServer("sv_response", 5)
                    else
                        self.network:sendToServer("sv_response", 6)
                    end
                end
                old_mouse_r_state = right
            end

            if keyboardApiAvailable then
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
    end
end

function wasd_autotool:client_onEquippedUpdate(primaryState, secondaryState)
    if mouseApiAvailable then
        return true, true
    end

    if self.tool:isLocal() then
        if primaryState == sm.tool.interactState.start then
            self.network:sendToServer("sv_response", 3)
        elseif primaryState == sm.tool.interactState.stop then
            self.network:sendToServer("sv_response", 4)
        end
        
        if secondaryState == sm.tool.interactState.start then
            self.network:sendToServer("sv_response", 5)
        elseif secondaryState == sm.tool.interactState.stop then
            self.network:sendToServer("sv_response", 6)
        end
    end

    return true, true
end

function wasd_autotool:client_onToggle()
    if keyboardApiAvailable then
        return true
    end

    if self.tool:getOwner().character:getLockingInteractable() then
        self.network:sendToServer("sv_response", 1)
    end

    return true
end

function wasd_autotool:client_onReload()
    if keyboardApiAvailable then
        return true
    end

    if self.tool:getOwner().character:getLockingInteractable() then
        self.network:sendToServer("sv_response", 2)
    end

    return true
end

function wasd_autotool:cl_enable()
    self.equipped = true
    sm.tool.forceTool(self.tool)
end

function wasd_autotool:cl_disable()
    self.equipped = false
    sm.tool.forceTool(nil)
end