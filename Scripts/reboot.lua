dofile("$CONTENT_DATA/Scripts/Config.lua")
reboot = class()
reboot.maxParentCount = -1
reboot.maxChildCount = -1
reboot.connectionInput = sm.interactable.connectionType.seated + sm.interactable.connectionType.composite + sm.interactable.connectionType.logic
reboot.connectionOutput = sm.interactable.connectionType.composite + sm.interactable.connectionType.logic
reboot.colorNormal = sm.color.new("#8a05a6")
reboot.colorHighlight = sm.color.new("#d50bff")

function reboot:server_onFixedUpdate()
    local active = false
    local rebootFlag = false

    for _, parent in ipairs(self.interactable:getParents()) do
        local publicApi = sc.computersDatas[parent.id]
        if publicApi and publicApi.self and publicApi.self.crashstate then
            if publicApi.self.crashstate.hasException then
                active = true
            end
        else
			local _s_uuid = tostring(parent.shape.uuid)
			if (not (parent:hasSteering() or parent:getType() == "steering" or _s_uuid == "ccaa33b6-e5bb-4edc-9329-b40f6efe2c9e" or _s_uuid == "e627986c-b7dd-4365-8fd8-a0f8707af63d")) and parent:isActive() then
				rebootFlag = true
			end
		end
    end

    for _, child in ipairs(self.interactable:getChildren()) do
        local publicApi = sc.computersDatas[child.id]
        if publicApi and publicApi.self and publicApi.self.crashstate and publicApi.self.crashstate.hasException then
            active = true
            break
        end
    end

    if rebootFlag and not self.oldReboot then
        self:sv_reboot()
    end
    self.oldReboot = rebootFlag

    self.interactable:setActive(active)
end

function reboot:sv_reboot(force)
    local blink

    for _, parent in ipairs(self.interactable:getParents()) do
        local publicApi = sc.computersDatas[parent.id]
        if publicApi then
            if force or (publicApi.self and not publicApi.self.storageData.noSoftwareReboot) then
                publicApi.self.reboot_flag = true
                blink = true
            end
        end
    end

    for _, child in ipairs(self.interactable:getChildren()) do
        local publicApi = sc.computersDatas[child.id]
        if publicApi then
            if force or (publicApi.self and not publicApi.self.storageData.noSoftwareReboot) then
                publicApi.self.reboot_flag = true
                blink = true
            end
        end
    end

    if blink then
        self.network:sendToClients("cl_blink")
    end
end

function reboot:sv_n_reboot()
    self:sv_reboot(true)
end



function reboot:client_onFixedUpdate()
    if self.blick then
        self.blick = nil
    else
        if self.interactable:isActive() and sm.game.getCurrentTick() % 60 >= 30 then
            self.interactable:setUvFrameIndex(7)
        else
            self.interactable:setUvFrameIndex(0)
        end
    end
end

function reboot:client_onInteract(_, state)
    if state then
        self.network:sendToServer("sv_n_reboot")
    end
end

function reboot:cl_blink()
    self.interactable:setUvFrameIndex(6)
    self.blick = true
end