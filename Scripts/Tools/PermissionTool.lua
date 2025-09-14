dofile "$CONTENT_DATA/Scripts/Config.lua"

PermissionTool = class(nil)

function PermissionTool.isHost()
    return sm.localPlayer.getPlayer():getId() == 1
end

function PermissionTool.server_deleteOther(self)
    --я адаптировал код под несколько тулов одновременно
    --[[
    local survival = self.data and self.data.survival
    if not survival then
        local uuid = self.shape.uuid
        local id = self.shape:getId()
        
        for i, body in ipairs(sm.body.getAllBodies()) do
            for i2, shape in ipairs(body:getShapes()) do
                if shape.uuid == uuid and shape:getId() ~= id then
                    shape:destroyShape()
                end
            end
        end
    end
    ]]
end

function PermissionTool.server_onCreate(self)
    sc.init()
    self:server_deleteOther()
end

function PermissionTool.server_onNewSettings(self, data, client)
    local settings = data[1]
    local ssettings = self:server_getSettings()

    if _G.disablePermissionTool then
        return
    end
    if ssettings.adminOnly then
        if client:getId() ~= 1 then
            return
        end
    end
    for k, v in pairs(settings) do
        ssettings[k] = v
    end

    _G.computersAllow = data[2].enable
    sc.saveRestrictions()

    self.network:sendToClients("client_onNewSettings", self:server_getSettingsPack())
end

function PermissionTool.server_onSettingsRequired(self, data, client)
    self.network:sendToClient(client, "client_onNewSettings", self:server_getSettingsPack())
end

function PermissionTool.server_getSettingsPack(self)
    return {sc.restrictions, {enable = not not _G.computersAllow}}
end

function PermissionTool.server_getSettings(self)
    return sc.restrictions
end

function PermissionTool:server_onFixedUpdate()
    if sc.restrictionsUpdated or _G.updateToolSettings then
        self.network:sendToClients("client_onNewSettings", self:server_getSettingsPack())
        _G.updateToolSettings = nil
    end
end

function PermissionTool:server_onDestroy()
end

function PermissionTool:sv_rebootAll()
    sc.rebootAll = true
end

--------------------------------------------------------------

function PermissionTool.client_onCreate(self)
    if self.tool and not self.tool:isLocal() then return end

    self.network:sendToServer("server_onSettingsRequired")
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PermissionTool.layout", false)
    self.gui:setButtonCallback("ScriptModeButton", "client_onScriptModeButtonPressed")
    self.gui:setButtonCallback("AdminOnlyButton", "client_onAdminOnlyButtonPressed")
    self.gui:setButtonCallback("lua", "client_onLuaVmPress")
    self.gui:setButtonCallback("messages", "client_onChatPress")
    self.gui:setButtonCallback("rend", "client_onRendPress")
    self.gui:setButtonCallback("opt", "client_onOptPress")
    self.gui:setButtonCallback("optSpeed", "client_onOptSPress")
    self.gui:setButtonCallback("rays", "client_onRaysPress")
    self.gui:setButtonCallback("rst", "client_onRstPress")
    self.gui:setButtonCallback("CE", "client_onComputersEnabled")
    self.gui:setButtonCallback("cpu", "client_onCpuPress")
    self.gui:setButtonCallback("allowDist", "client_onAllowDist")
    self.gui:setButtonCallback("srv", "client_onSrvPress")
    self.gui:setButtonCallback("unrestrictedSettings", "client_onUnrestrictedSettingsPress")
    self.gui:setButtonCallback("saving", "client_onSavingPress")
    self.gui:setButtonCallback("maxDisplays", "client_onMaxDisplaysPress")
    self.gui:setButtonCallback("disCompCheck", "client_onDisCompCheckPress")
    self.gui:setButtonCallback("ibridge", "client_onIbridgePress")
    self.gui:setButtonCallback("adrop", "client_onAdropPress")
    self.gui:setButtonCallback("acreative", "client_onACreativePress")
    self.gui:setButtonCallback("disableCallLimit", "client_disableCallLimit")
    self.gui:setButtonCallback("lagDetector", "client_lagDetector")
    self.gui:setButtonCallback("screenRate", "client_screenRate")
    self.gui:setButtonCallback("hostrender", "client_hostrender")
    self.gui:setButtonCallback("resourceConsumption", "client_resourceConsumption")
    self.gui:setButtonCallback("disableSplash", "client_disableSplash")
    self.gui:setVisible("admin", false)
    --self.gui:setButtonCallback("DisplaysAtLagsButton", "client_onDisplayAtLagsButtonPressed")

    self.gui:setButtonCallback("ApplyButton", "client_onApplyButtonPressed")

    _G.serverTempSettings = {}
    _G.serverSettings = sc.deepcopy(sc.defaultRestrictions)

    self.currentSettings = sc.deepcopy(_G.serverSettings)
    self.tempSettings = sc.deepcopy(_G.serverTempSettings)
end

function PermissionTool.client_onDestroy(self)
    if not self.gui then return end
    self.gui:close()
    self.gui:destroy()
    self.gui = nil
end

function PermissionTool.client_onInteract(self, char, state)
    if _G.disablePermissionTool then
        return
    end

    if state then
        self.rebootAll_cl_flag = nil
        self:cl_guiOpen()
    end
end

function PermissionTool:client_canInteract(character)
    if _G.disablePermissionTool then
        sm.gui.setInteractionText("", "#ff0000Permission Tool was disabled by the administrator", "")
        sm.gui.setInteractionText("", "", "")
        return false
    end

    return true
end

function PermissionTool.client_onNewSettings(self, data)
    local settings = data[1]
    _G.serverTempSettings = data[2]

    if settings.optSpeed then
        settings.optSpeed = round(settings.optSpeed, 1)
    end
    _G.serverSettings = settings
end

function PermissionTool.cl_guiOpen(self)
    self.tempSettings = sc.deepcopy(_G.serverTempSettings)
    self.currentSettings = sc.deepcopy(_G.serverSettings)
    self:cl_guiUpdateButtons()
    self.gui:open()
end

function PermissionTool:client_onFixedUpdate()
    if self.tool and not self.tool:isLocal() then return end

    self:cl_guiUpdateButtons()

    --print(sm.player.getAllPlayers()[1].character.direction)
end

local scriptModeTitles = {
    ["safe"] = "safe",
    ["safe_with_open"] = "safe (with sm.json.open)",
    ["unsafe"] = "unsafe"
}

function PermissionTool.cl_guiUpdateButtons(self)
    self.gui:setText("ScriptModeButton", "Script Mode: " .. (scriptModeTitles[self.currentSettings.scriptMode] or self.currentSettings.scriptMode))
    self.gui:setText("AdminOnlyButton", "Admin Only(Changes To Settings): " .. (self.currentSettings.adminOnly and "true" or "false") )
    self.gui:setText("messages", "Allow Chat/Alert/Debug Messages: " .. tostring(self.currentSettings.allowChat or false))
    self.gui:setText("rend", "Display Render Distance: " .. tostring(self.currentSettings.rend))
    self.gui:setText("optSpeed", "Optimize On Distance Speed: " .. tostring(self.currentSettings.optSpeed or "disable"))
    self.gui:setText("rays", "Raycast Render Check: " .. tostring(self.currentSettings.rays == 0 and "disable" or self.currentSettings.rays))
    self.gui:setText("CE", "Computers Enabled in This Session: " .. tostring(self.tempSettings.enable))
    self.gui:setText("allowDist", "Allow Render At Distance: " .. tostring(self.currentSettings.allowDist))
    self.gui:setText("saving", "Saving Content Once Per: " .. (self.currentSettings.saving == 0 and "immediately" or tostring(self.currentSettings.saving) .. "-tick"))
    self.gui:setText("maxDisplays", "Max Display Resolution: " .. tostring(self.currentSettings.maxDisplays))
    self.gui:setText("disCompCheck", "Disable Connect Check: " .. tostring(self.currentSettings.disCompCheck))
    self.gui:setText("ibridge", "Allow Internet-Bridge: " .. tostring(self.currentSettings.ibridge))
    self.gui:setText("adrop", "Drop Freq At Lags: " .. tostring(self.currentSettings.adrop))
    self.gui:setText("acreative", "Allow Creative-Components: " .. tostring(self.currentSettings.acreative))
    self.gui:setText("disableCallLimit", "Disable Call Limit: " .. tostring(self.currentSettings.disableCallLimit))
    self.gui:setText("resourceConsumption", "Resource Consumption: " .. tostring(self.currentSettings.resourceConsumption))
    self.gui:setText("disableSplash", "Disable Splash: " .. tostring(self.currentSettings.disableSplash) .. (self.currentSettings.disableSplash and " (dangerous)" or ""))

    if type(self.currentSettings.lagDetector) == "number" then
        self.gui:setText("lagDetector", "Anti-Lag: " .. tostring(round(self.currentSettings.lagDetector, 3)))
    else
        self.gui:setText("lagDetector", "Anti-Lag: false")
    end
    if self.currentSettings.screenRate == -1 then
        self.gui:setText("screenRate", "Screen Rate: auto")
    elseif self.currentSettings.screenRate == -2 then
        self.gui:setText("screenRate", "Screen Rate: auto (slow)")
    elseif self.currentSettings.screenRate == 1 then
        self.gui:setText("screenRate", "Screen Rate: full")
    elseif self.currentSettings.screenRate == 2 then
        self.gui:setText("screenRate", "Screen Rate: half")
    elseif self.currentSettings.screenRate == 4 then
        self.gui:setText("screenRate", "Screen Rate: quatre")
    elseif self.currentSettings.screenRate == 8 then
        self.gui:setText("screenRate", "Screen Rate: eighth")
    elseif self.currentSettings.screenRate == 40 then
        self.gui:setText("screenRate", "Screen Rate: static")
    else
        self.gui:setText("screenRate", "Screen Rate: " .. tostring(self.currentSettings.screenRate))
    end
    self.gui:setText("hostrender", "Rendering Displays On Host: " .. tostring(self.currentSettings.hostrender))
    
    if self.currentSettings.vm == "luaInLua" then
        self.gui:setText("lua", "LuaVM: LuaInLua (remade)")
    else
        self.gui:setText("lua", "LuaVM: " .. self.currentSettings.vm)
    end


    local onetick = 1 / 40
    local cputimename = "unknown"
    local altTitle
    local cpu = self.currentSettings.cpu
    cpu = round(cpu, 5)
    if cpu == onetick / 2 then
        cputimename = "half tick"
    elseif cpu == -1 then
        altTitle = "unlimited (dangerous)"
    else
        cputimename = tostring(math.floor((cpu * 40) + 0.5)) .. " tick"
    end
    if altTitle then
        self.gui:setText("cpu", "Maximum CPU Time: " .. altTitle)
    else
        self.gui:setText("cpu", "Maximum CPU Time: " .. tostring(cpu) .. " (" .. cputimename .. ")")
    end
    --self.gui:setText("DisplaysAtLagsButton", "DisplaysAtLags: " .. (self.currentSettings.displaysAtLagsMode == "draw" and "Draw" or "Skip"))

    
    
    local survival = self.data and self.data.survival
    self.gui:setVisible("ScriptModeButton", not survival or self.currentSettings.scriptMode ~= "safe")
    --self.gui:setVisible("messages", not survival or self.currentSettings.allowChat)
    self.gui:setVisible("disCompCheck", not survival or self.currentSettings.disCompCheck)
    self.gui:setVisible("AdminOnlyButton", not survival or not self.currentSettings.adminOnly)
    self.gui:setVisible("acreative", not survival or self.currentSettings.acreative)
    self.gui:setVisible("disableCallLimit", not survival or self.currentSettings.disableCallLimit)
    self.gui:setVisible("resourceConsumption", not survival or not self.currentSettings.resourceConsumption)
    self.gui:setVisible("unrestrictedSettings", not survival)

    if not self:client_canChangeSettings() then
        self.gui:setVisible("ApplyButton", false)
    elseif self.currentSettings.vm == "fullLuaEnv" then
        self.gui:setVisible("ApplyButton", not not a)
    elseif self.currentSettings.vm == "hsandbox" then
        self.gui:setVisible("ApplyButton", not not _HENV)
    elseif self.currentSettings.vm == "luaVM" then
        self.gui:setVisible("ApplyButton", not not (vm and vm.lua52))
    elseif self.currentSettings.vm == "betterAPI" then
        self.gui:setVisible("ApplyButton", not not (better and better.loadstring))
    elseif self.currentSettings.vm == "dlm" then
        self.gui:setVisible("ApplyButton", not not (not better and dlm and dlm.loadstring))
    elseif self.currentSettings.vm == "advancedExecuter" then
        self.gui:setVisible("ApplyButton", not not sm.advancedExecuter)
    else
        self.gui:setVisible("ApplyButton", true)
    end
end

function PermissionTool.client_canChangeSettings(self)
    return not _G.serverSettings.adminOnly or PermissionTool.isHost()
end

function PermissionTool.client_cheatAllow(self)
    return not not _G.allowToggleCheat
end

------------------------- BUTTONS

local noCheatMessage = "#ff0000you can't enable cheats, enter into the chat to unlock: /cl_scomputers_cheat"

function PermissionTool:client_disableSplash()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.disableSplash = not self.currentSettings.disableSplash
end

function PermissionTool:client_resourceConsumption()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.resourceConsumption = not self.currentSettings.resourceConsumption
end

function PermissionTool:client_onCpuPress()
    if not self:client_canChangeSettings() then return end

    local onetick = 1 / 40
    self.currentSettings.cpu = round(self.currentSettings.cpu, 5)
    if self.currentSettings.cpu == onetick / 2 then
        self.currentSettings.cpu = onetick
    elseif self.currentSettings.cpu == -1 then
        self.currentSettings.cpu = onetick / 2
    elseif self.currentSettings.cpu == onetick * 5 then
        self.currentSettings.cpu = onetick * 10
    elseif self.currentSettings.cpu == onetick * 10 then
        self.currentSettings.cpu = onetick * 15
    elseif self.currentSettings.cpu == onetick * 15 then
        self.currentSettings.cpu = onetick * 20
    elseif self.currentSettings.cpu == onetick * 20 then
        self.currentSettings.cpu = onetick * 25
    elseif self.currentSettings.cpu == onetick * 25 then
        self.currentSettings.cpu = onetick * 30
    elseif self.currentSettings.cpu == onetick * 30 then
        self.currentSettings.cpu = onetick * 40
    else
        self.currentSettings.cpu = self.currentSettings.cpu + onetick
        if self.currentSettings.cpu > onetick * 40 then
            self.currentSettings.cpu = -1
        end
    end
    self.currentSettings.cpu = round(self.currentSettings.cpu, 5)
end

function PermissionTool.client_onScriptModeButtonPressed(self)
    if not self:client_canChangeSettings() then return end
    local isSafe = self.currentSettings.scriptMode == "safe"
    if not self:client_cheatAllow() and isSafe then
        sm.gui.chatMessage(noCheatMessage)
        return
    end

    if self.currentSettings.scriptMode == "safe" then
        self.currentSettings.scriptMode = "safe_with_open"
    elseif self.currentSettings.scriptMode == "safe_with_open" then
        self.currentSettings.scriptMode = "unsafe"
    else
        self.currentSettings.scriptMode = "safe"
    end
    self.rebootAll_cl_flag = true
end

function PermissionTool:client_onChatPress()
    if not self:client_canChangeSettings() then return end
    --[[
    if not self:client_cheatAllow() and not self.currentSettings.allowChat then
        sm.gui.chatMessage(noCheatMessage)
        return
    end
    ]]

    self.currentSettings.allowChat = not self.currentSettings.allowChat
end

function PermissionTool:client_onDisCompCheckPress()
    if not self:client_canChangeSettings() then return end
    if not self:client_cheatAllow() and not self.currentSettings.disCompCheck then
        sm.gui.chatMessage(noCheatMessage)
        return
    end

    self.currentSettings.disCompCheck = not self.currentSettings.disCompCheck
end

function PermissionTool:client_onAdropPress()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.adrop = not self.currentSettings.adrop
end

function PermissionTool:client_onIbridgePress()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.ibridge = not self.currentSettings.ibridge
end

function PermissionTool:client_onSavingPress()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.saving = self.currentSettings.saving + 10
    if self.currentSettings.saving > 80 then
        self.currentSettings.saving = 0
    end
end

--local rates = {-1, -2, 1, 2, 4, 8}
local rates = {-1, 1, 2, 4, 40}
function PermissionTool:client_screenRate()
    if not self:client_canChangeSettings() then return end
    
    local currentIndex
    for index, value in ipairs(rates) do
        if value == self.currentSettings.screenRate then
            currentIndex = index
        end
    end
    if currentIndex then
        currentIndex = currentIndex + 1
        if currentIndex > #rates then
            currentIndex = 1
        end
    end
    self.currentSettings.screenRate = rates[currentIndex or 1]
end

function PermissionTool:client_onMaxDisplaysPress()
    if not self:client_canChangeSettings() then return end

    if self.currentSettings.maxDisplays == 0 then
        self.currentSettings.maxDisplays = 16
    else
        self.currentSettings.maxDisplays = self.currentSettings.maxDisplays * 2
    end
    if self.currentSettings.maxDisplays > 4096 then
        self.currentSettings.maxDisplays = 0
    end
end

function PermissionTool:client_onComputersEnabled()
    if not self:client_canChangeSettings() then return end

    self.tempSettings.enable = not self.tempSettings.enable
end

function PermissionTool:client_onAllowDist()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.allowDist = not self.currentSettings.allowDist
end

function PermissionTool:client_disableCallLimit()
    if not self:client_canChangeSettings() then return end
    if not self:client_cheatAllow() and not self.currentSettings.disableCallLimit then
        sm.gui.chatMessage(noCheatMessage)
        return
    end

    self.currentSettings.disableCallLimit = not self.currentSettings.disableCallLimit
end

function PermissionTool:client_lagDetector()
    if not self:client_canChangeSettings() then return end

    if self.currentSettings.lagDetector == 0.5 then
        self.currentSettings.lagDetector = 0.75
    elseif self.currentSettings.lagDetector == 0.75 then
        self.currentSettings.lagDetector = 1
    elseif self.currentSettings.lagDetector == 1 then
        self.currentSettings.lagDetector = 1.5
    elseif self.currentSettings.lagDetector == 1.5 then
        self.currentSettings.lagDetector = 2
    elseif self.currentSettings.lagDetector == 2 then
        self.currentSettings.lagDetector = 2.5
    elseif self.currentSettings.lagDetector == 2.5 then
        self.currentSettings.lagDetector = 3
    else
        if type(self.currentSettings.lagDetector) ~= "number" then
            self.currentSettings.lagDetector = 0
        end
        self.currentSettings.lagDetector = round(self.currentSettings.lagDetector, 3)
    
        self.currentSettings.lagDetector = self.currentSettings.lagDetector + 0.1
        if self.currentSettings.lagDetector > 3 then
            self.currentSettings.lagDetector = false
        end
    end
end

function PermissionTool:client_hostrender()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.hostrender = not self.currentSettings.hostrender
end

function PermissionTool.client_onLuaVmPress(self)
    if not self:client_canChangeSettings() then return end

    --local vms = {"luaInLua", "scrapVM", "advancedExecuter", "dlm", "fullLuaEnv", "hsandbox"}
    --local vms = {"luaInLua", "betterAPI", "dlm", "fullLuaEnv"}
    local vms = {"FiOne_lua", "betterAPI"}
    
    local currentIndex
    for index, value in ipairs(vms) do
        if value == self.currentSettings.vm then
            currentIndex = index
        end
    end
    if currentIndex then
        currentIndex = currentIndex + 1
        if currentIndex > #vms then
            currentIndex = 1
        end
    end
    self.currentSettings.vm = vms[currentIndex or 1]

    self.rebootAll_cl_flag = true
end

function PermissionTool:client_onRendPress()
    if not self:client_canChangeSettings() then return end

    self.currentSettings.rend = self.currentSettings.rend + 5
    if self.currentSettings.rend > 40 then
        self.currentSettings.rend = 5
    end
end

function PermissionTool:client_onOptSPress()
    if not self:client_canChangeSettings() then return end

    if not self.currentSettings.optSpeed then
        self.currentSettings.optSpeed = 0
    end
    self.currentSettings.optSpeed = self.currentSettings.optSpeed + 0.1
    if self.currentSettings.optSpeed > 5 then
        self.currentSettings.optSpeed = false
    else
        self.currentSettings.optSpeed = round(self.currentSettings.optSpeed, 1)
    end
end

local function setSettings(self, settings)
    if not self:client_canChangeSettings() then return end

    self.rebootAll_cl_flag = true
    local oldSettings = sc.restrictions
    sc.setRestrictions(settings)
    self.currentSettings = sc.restrictions
    sc.restrictions = oldSettings

    if self.data and self.data.survival then
        self.currentSettings.acreative = false
    end
end

function PermissionTool:client_onSrvPress()
    setSettings(self, sc.forServerRestrictions)
end

function PermissionTool:client_onUnrestrictedSettingsPress()
    setSettings(self, sc.unrestrictedRestrictions)
end

function PermissionTool:client_onRstPress()
    setSettings(self, sc.defaultRestrictions)
end

function PermissionTool:client_onRaysPress()
    if not self:client_canChangeSettings() then return end

    if self.currentSettings.rays == 0 then
        self.currentSettings.rays = 16
    elseif self.currentSettings.rays == 16 then
        self.currentSettings.rays = 32
    elseif self.currentSettings.rays == 32 then
        self.currentSettings.rays = 64
    elseif self.currentSettings.rays == 64 then
        self.currentSettings.rays = 128
    else
        self.currentSettings.rays = 0
    end
end

function PermissionTool.client_onAdminOnlyButtonPressed(self)
    if not PermissionTool.isHost() then return end -- clients can block theirselves

    if not self:client_cheatAllow() and self.currentSettings.adminOnly then
        sm.gui.chatMessage(noCheatMessage)
        return
    end

    self.currentSettings.adminOnly = not self.currentSettings.adminOnly
end

function PermissionTool:client_onACreativePress()
    if not self:client_canChangeSettings() then return end

    --[[
    if not self.currentSettings.acreative and sm.game.getLimitedInventory() then
        sm.gui.chatMessage("#ff0000you cannot allow the use of creative items in survival")
        return
    end
    ]]

    self.currentSettings.acreative = not self.currentSettings.acreative
end

--[[function PermissionTool.client_onDisplayAtLagsButtonPressed(self)
    if not self:client_canChangeSettings() then return end

    self.currentSettings.displaysAtLagsMode = self.currentSettings.displaysAtLagsMode == "draw" and "skip" or "draw"

    self.gui:setText("DisplaysAtLagsButton", "DisplaysAtLags: " .. (self.currentSettings.displaysAtLagsMode == "draw" and "Draw" or "Skip"))
end]]

function PermissionTool.client_onApplyButtonPressed(self)
    self.network:sendToServer("server_onNewSettings", {self.currentSettings, self.tempSettings})
    self.gui:close()


    if self.rebootAll_cl_flag then
        self.rebootAll_cl_flag = nil
        self.network:sendToServer("sv_rebootAll")
    end
end

----------------- tool support

function PermissionTool:client_onEquippedUpdate(primaryState, secondaryState)
    if self.tool and not self.tool:isLocal() then return end
    
    if primaryState == sm.tool.interactState.start then
        self:client_onInteract(nil, true)
    end

    return true, true
end