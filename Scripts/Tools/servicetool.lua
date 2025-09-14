--dofile("$CONTENT_DATA/Scripts/externAddonAPI.lua")
servicetool = class()
servicetool.instance = nil

local noWarnings = true
local noCheatCommand = true
local noSafeCommand = true

local function checkInstance(self)
    servicetool.instance = servicetool.instance or self
    return servicetool.instance ~= self
end

local function loadBackground(self)
    if sc.background then return end
    sc.background = {}

    dofile("$CONTENT_DATA/Scripts/chaff_task.lua")

    for name, task in pairs(sc.background) do
        function task.sendToClients(...)
            self.network:sendToClients("cl_bg_callback", {name = name, ...})
        end
    end
end

local function background_sv(self)
    for name, task in pairs(sc.background) do
        task:server()
    end
end

local function background_cl(self)
    for name, task in pairs(sc.background) do
        task:client()
    end
end

function servicetool:cl_bg_callback(args)
    sc.background[args.name].clientCallback(unpack(args))
end

------------------------------------------------------------------

local newClients = {}
local function updateClients(self)
    local currentClients = {}
    for _, player in ipairs(sm.player.getAllPlayers()) do
        currentClients[player.id] = true
        if not newClients[player.id] then
            self.network:sendToClient(player, "cl_n_onCreate", sc.version)
            newClients[player.id] = true
        end
    end
    for id in pairs(newClients) do
        if not currentClients[id] then
            newClients[id] = nil
        end
    end
end

function servicetool:server_onCreate()
    if checkInstance(self) then
        return
    end

    dofile("$CONTENT_DATA/Scripts/Config.lua")
    loadBackground(self)
    sc.init()
    sc.warningsCheck()
    self.sendRestrictions = true

    if sc.enableByDefault then
        _G.computersAllow = true
        _G.updateToolSettings = true
    end

    self.xengineClearTimeout = 40 * 5

    updateClients(self)
end

function servicetool:server_onFixedUpdate()
    if checkInstance(self) then
        return
    end

    updateClients(self)

    if self._restrictionsUpdated then
        sc.restrictionsUpdated = nil
        self._restrictionsUpdated = nil
    end
    if sc.restrictionsUpdated then
        self._restrictionsUpdated = true
    end

    if self._rebootAll then
        sc.rebootAll = nil
        self._rebootAll = nil
    end
    if sc.rebootAll then
        self._rebootAll = true
    end
    
    if sc.restrictionsUpdated or self.sendRestrictions then
        self.network:sendToClients("cl_restrictions", sc.restrictions)
        self.sendRestrictions = nil
    end

    --local forceSend = sm.game.getCurrentTick() % (40 * 60 * 60) == 0
    --if sc.restrictionsUpdated or (sc.shutdownFlag and sm.game.getCurrentTick() % (5 * 40) == 0) then
        --self:sv_print_vulnerabilities()
    --end

    if sc.shutdownFlag and sm.game.getCurrentTick() % (5 * 40) == 0 then
        self:sv_print_vulnerabilities()
    end
    
    if self.scAllow then
        sc.setRestrictions(sc.originalRestrictions)
        sc.saveRestrictions()

        self.scAllow = nil
    end

    if self.xengineClearTimeout then
        self.xengineClearTimeout = self.xengineClearTimeout - 1
        if self.xengineClearTimeout < 0 then
            sc.xEngineClear()
            self.xengineClearTimeout = nil
        end
    end

    --[[
    if sm.game.getCurrentTick() % 10 == 0 then
        for _, player in ipairs(sm.player.getAllPlayers()) do
            local inv = player:getInventory()

            sm.container.beginTransaction()
            sm.container.collectToSlot(inv, 3, sm.uuid.new("3d37b254-dbaa-4be2-9a0d-ce1e24315c08"), 1)
            sm.container.endTransaction()
        end
    end
    ]]

    background_sv(self)
end

function servicetool:sv_print_vulnerabilities()
    local vulnerabilities = {}

    if not noWarnings then
        if not sc.restrictions.adminOnly then
            table.insert(vulnerabilities, "any player can change the configuration of the mod(adminOnly: false)")
        end
        if sc.restrictions.allowChat then
            table.insert(vulnerabilities, "computers can output messages to chat(printON)")
        end
        if sc.restrictions.scriptMode ~= "safe" then
            table.insert(vulnerabilities, "computers can control the game(unsafe mode)")
        end
        if sc.restrictions.disCompCheck then
            table.insert(vulnerabilities, "component connectivity check is disabled")
        end
        if sc.restrictions.disableCallLimit then
            table.insert(vulnerabilities, "call limits are disabled, this allows you to burden some SComputers mechanics")
        end
    end

    if sc.shutdownFlag then
        vulnerabilities.shutdown = true
    end
    
    self.network:sendToClients("cl_print_vulnerabilities", vulnerabilities)
end

function servicetool:sv_createGui()
    self.network:sendToClients("cl_createGui")
end

function servicetool:sv_dataRequest()
    self.sendRestrictions = true
end

function servicetool:sv_dataRequest2()
    self.network:sendToClients("cl_onDataResponse", {sc.treesPainted})
end

function servicetool:sv_cheat(data)
    self.network:sendToClient(data.player, "cl_cheat")
end

function servicetool:sv_safe(data)
    local isHost = data.player == vnetwork.host
    if not sc.restrictions.adminOnly or isHost then
        if not noCheatCommand then
            self.network:sendToClients("cl_disToggleCheat")
        end
        if isHost then -- clients can block theirselves
            sc.restrictions.adminOnly = true
        end
        sc.restrictions.allowChat = false
        sc.restrictions.scriptMode = "safe"
        sc.restrictions.disCompCheck = false
        sc.restrictions.disableCallLimit = false

        sc.saveRestrictions()
        sc.rebootAll = true
        self.network:sendToClient(data.player, "cl_safe")
    else
        self.network:sendToClient(data.player, "cl_noPermission")
    end
end

function servicetool:sv_version(data)
    self.network:sendToClient(data.player, "cl_version")
end

------------------------------------------------------------------

function servicetool:cl_previewToChat()
    sm.gui.chatMessage("#ffad30Thank you for using SComputers :)#ffffff")
    --sm.gui.chatMessage("#f03c02be sure to read the documentation#ffffff: https://scrapmechanictools.com/modapis/SComputers/Info")
    sm.gui.chatMessage("#ff3030>> be sure to read the documentation:\n#ffffffhttps://igorkll.github.io/SComputers")
    sm.gui.chatMessage("#309eff>> SComputers discord server:\n#ffffffhttps://discord.gg/uJrsmUjaMG")
    if not better then
        sm.gui.chatMessage("#f2ea05>> to improve the performance of the displays, it is recommended to install this:\n#ffffffhttps://igorkll.github.io/betterAPI")
    end
    --sm.gui.chatMessage("current documentation is \"temporary\"") permanent link for the invitation: 
    --sm.gui.chatMessage("because the scrapmechanictool site has closed")
end

function servicetool:cl_n_onCreate(version)
    if checkInstance(self) then
        return
    end
    self.clientToolInited = true
    
    dofile("$CONTENT_DATA/Scripts/Config.lua")
    loadBackground(self)

    if sc.isSplashEnabled() then
        self:cl_createGui()
        if not sm.isHost then
            self:cl_previewToChat()
        end
    else
        self:cl_allow()
    end
    
    self.network:sendToServer("sv_dataRequest")
    self.timeout = 40

    if noCheatCommand then
        _G.allowToggleCheat = true
    end

    if version ~= sc.version then
        sm.gui.chatMessage("#ff0000DIFFERENT VERSIONS OF SComputers ON THE CLIENT AND SERVER SIDE!!!")
        sm.gui.chatMessage("#ff8800RE-SUBSCRIBE TO THE MOD: #ffffffhttps://steamcommunity.com/sharedfiles/filedetails/?id=2949350596")
    end
end

function servicetool:cl_onDataResponse(data)
    for _, dat in pairs(data[1]) do
        if sm.exists(dat[1]) then
            dat[1]:setColor(dat[2])
        end
    end
end

function servicetool:client_onFixedUpdate(dt)
    if not self.clientToolInited or checkInstance(self) then
        return
    end

    if better and better.isAvailable() then
        local key1 = better.keyboard.isKey(better.keyboard.keys.ctrl_l)
        local key2 = better.keyboard.isKey(better.keyboard.keys.s)
        _g_saveBind = key1 and key2
    end

    sc.deltaTimeTps = dt

    local computerExists = sc.computersCount > 0
    if computerExists and ((computerExists and not self.old_computerExists) or sm.game.getCurrentTick() % (60 * 40 * 5) == 0) then
        self:cl_print_vulnerabilities({}, true)
    end
    self.old_computerExists = computerExists

    if self.gui and not self.gui:isActive() then
        self.gui:open()
    end

    if self.timeout then
        if self.timeout <= 0 then
            self.network:sendToServer("sv_dataRequest2")
            self.timeout = nil
        else
            self.timeout = self.timeout - 1
        end
    end

    --[[
    if _G.tcCache and sm.game.getCurrentTick() % (40 * 16) == 0 then
        local size = 0
        --[[
        local types = {}
        for dat in pairs(_G.tcCache) do
            size = size + 1
            local t = type(dat)
            if not types[t] then types[t] = 0 end
            types[t] = types[t] + 1
        end
        ] ]
        for dat in pairs(_G.tcCache) do
            size = size + 1
            if size > 1024 * 4 then
                print("clearing tableChecksum cache...")
                print("current size", size)
                --[[
                print("types:")
                for t, count in pairs(types) do
                    print(tostring(t) .. "-" .. tostring(count))
                end
                ] ]
    
                for key in pairs(_G.tcCache) do
                    _G.tcCache[key] = nil
                    if size < 256 then
                        break
                    end
                end
                
                break
            end
        end
    end
    ]]

    if better then
        better.tick()
    end

    background_cl(self)

    --updateExternAPI()
end

function servicetool:cl_disToggleCheat()
    _G.allowToggleCheat = false
end

function servicetool:cl_print_vulnerabilities(vulnerabilities, regularFlag)
    local oldVulnerabilitiesCount
    if not regularFlag then
        if not noWarnings then
            if _G.allowToggleCheat then
                table.insert(vulnerabilities, "you can activate cheats (which may lead to accidental activation)")
            end
        end

        oldVulnerabilitiesCount = #vulnerabilities
        for _, warning in ipairs(warnings) do
            table.insert(vulnerabilities, warning)
        end
    end

    for _, warning in ipairs(regularWarnings) do
        table.insert(vulnerabilities, warning)
    end

    if #vulnerabilities > 0 then
        sm.gui.chatMessage("#ff0000warnings from the SComputers:#ffffff")
        for index, value in ipairs(vulnerabilities) do
            sm.gui.chatMessage(tostring(index) .. ". " .. value)
        end

        if oldVulnerabilitiesCount and not noSafeCommand and oldVulnerabilitiesCount > 0 then
            sm.gui.chatMessage("#ffff00the host can enter /sv_scomputers_safe to automatically bring security back to normal#ffffff")
        end
    end

    if vulnerabilities.shutdown then
        sc.shutdown()
    end
end

local function scomputersUI(self)
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/allow.layout", false)
    self.gui:setButtonCallback("yes", "cl_allow")
    --self.gui:setButtonCallback("sc", "cl_scAllow")
    self.gui:setButtonCallback("no", "cl_notAllow")
end

function servicetool:cl_createGui()
    if not sm.isHost then return end
    --[[ fuck the human autopilot
    self.gui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout", false)
    self.gui:setText("Title", "SComputers")
    self.gui:setText("Message", "Allow computers to work in this gaming session?\nIf you have a computer that breaks the game, turn off the computers and put it away.\nTo open this menu, type the command: /computers")
    self.gui:setButtonCallback("Yes", "cl_allow")
    self.gui:setButtonCallback("No", "cl_notAllow")
    ]]
    scomputersUI(self)
end

function servicetool:cl_scAllow()
    self.gui:close()
    self.gui:destroy()

    self.gui = sm.gui.createGuiFromLayout("$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout", false)
    self.gui:setText("Title", "SComputers")
    self.gui:setText("Message", "do you really want to apply this preset settings?")
    self.gui:setButtonCallback("Yes", "cl_scAllow2")
    self.gui:setButtonCallback("No", "cl_notAllow2")
end

function servicetool:cl_scAllow2()
    self.scAllow = true
    self:cl_allow()
end

function servicetool:cl_notAllow2()
    self.gui:close()
    self.gui:destroy()

    scomputersUI(self)
end

function servicetool:cl_allow()
    print("SComputers ALLOWED")

    if not self.vul_printed then
        self.network:sendToServer("sv_print_vulnerabilities")
        self.vul_printed = true
    end
    
    _G.computersAllow = true
    _G.updateToolSettings = true
    if self.gui then
        self.gui:close()
        self.gui:destroy()
        self.gui = nil
    end
    
    self:cl_previewToChat()
end

function servicetool:cl_notAllow()
    print("SComputers NOT-ALLOWED")
    
    if not self.vul_printed then
        self.network:sendToServer("sv_print_vulnerabilities")
        self.vul_printed = true
    end

    _G.computersAllow = nil
    _G.updateToolSettings = true
    if self.gui then
        self.gui:close()
        self.gui:destroy()
        self.gui = nil
    end

    self:cl_previewToChat()
end

function servicetool:client_onUpdate(dt)
    sc.deltaTime = dt
end

function servicetool:cl_restrictions(data)
    if sm.isHost then return end
    sc.restrictions = data
end

function servicetool:cl_noPermission()
    sm.gui.chatMessage("#ff0000you don't have rights to use this command")
end

function servicetool:cl_safe()
    sm.gui.chatMessage("#00ff00SComputers settings are now safe to use")
end

function servicetool:cl_cheat()
    if not _G.allowToggleCheat and sm.game.getLimitedInventory() then
        sm.gui.chatMessage("#ff0000it is impossible to enable cheats in survival")
        return
    end

    _G.allowToggleCheat = not _G.allowToggleCheat
    if _G.allowToggleCheat then
        sm.gui.chatMessage("#ffff00now you can activate cheats")
    else
        sm.gui.chatMessage("#00ff00you can no longer activate cheats")
    end
end

function servicetool:cl_version()
    sm.gui.displayAlertText("version: " .. tostring(sc.version))
end

------------------------------------------------------------------

--[[
for k, v in pairs(servicetool) do
    if type(v) == "function" then
        servicetool[k] = function(self, ...)
            if checkInstance(self) then return end
            return v(self, ...)
        end
    end
end
]]

if not commandsBind then
    local added
    local oldBindCommand = sm.game.bindChatCommand
    local function bindCommandHook(command, params, callback, help)
        oldBindCommand(command, params, callback, help)
        if not added then
            if not sc.noCommands then
                if sm.isHost then
                    oldBindCommand("/computers", {}, "cl_onChatCommand", "opens the SComputers configuration menu")
                end
                if not noCheatCommand then
                    oldBindCommand("/cl_scomputers_cheat", {}, "cl_onChatCommand", "enables/disables cheat-buttons in the \"Creative Permission-tool\"")
                end
                --oldBindCommand("/cl_scomputers_version", {}, "cl_onChatCommand", "show scomputers version")
                if not noSafeCommand then
                    oldBindCommand("/sv_scomputers_safe", {}, "cl_onChatCommand", "returns SComputers parameters to safe")
                end
            end

            added = true
        end
    end
    sm.game.bindChatCommand = bindCommandHook

    --------------------------------------------

    local oldWorldEvent = sm.event.sendToWorld
    local function worldEventHook(world, callback, params)
        if params then
            if params[1] == "/computers" then
                sm.event.sendToTool(servicetool.instance.tool, "sv_createGui")
                return
            elseif params[1] == "/cl_scomputers_cheat" then
                sm.event.sendToTool(servicetool.instance.tool, "sv_cheat", {player = params.player})
                return
            elseif params[1] == "/sv_scomputers_safe" then
                sm.event.sendToTool(servicetool.instance.tool, "sv_safe", {player = params.player})
                return
            elseif params[1] == "/cl_scomputers_version" then
                sm.event.sendToTool(servicetool.instance.tool, "sv_version", {player = params.player})
                return
            end
        end

        oldWorldEvent(world, callback, params)
    end
    sm.event.sendToWorld = worldEventHook

    --------------------------------------------

    commandsBind = true
end