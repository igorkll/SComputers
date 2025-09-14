dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/syntax.lua")

ScriptableComputer = class()

ScriptableComputer.maxParentCount = -1
ScriptableComputer.maxChildCount = -1
ScriptableComputer.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.logic + sm.interactable.connectionType.power
ScriptableComputer.connectionOutput = sm.interactable.connectionType.composite + sm.interactable.connectionType.logic + sm.interactable.connectionType.power
ScriptableComputer.colorNormal = sm.color.new(0x1a8e15ff)
ScriptableComputer.colorHighlight = sm.color.new(0x23eb1aff)

ScriptableComputer.UV_NON_ACTIVE = 0
ScriptableComputer.UV_ACTIVE_OFFSET = 6
ScriptableComputer.UV_HAS_ERROR = 10
ScriptableComputer.UV_HAS_DISABLED = 9

ScriptableComputer.maxcodesize = sc.maxcodelen
ScriptableComputer.maxPromptsize = 16 * 1024
ScriptableComputer.maxEncryptMessageSize = 16 * 1024
ScriptableComputer.max_patience = 4
ScriptableComputer.shortTraceback = 4 --сокрашения traceback на определенное количетсво линий
ScriptableComputer.longOperationMsg = "too long without yielding"
ScriptableComputer.oftenLongOperationMsg = "too long without yielding"
ScriptableComputer.lagMsg = "too long without yielding"
ScriptableComputer.maxCodeSizeStr = "the maximum code size is 64KB"

ScriptableComputer.ledUuid = sm.uuid.new("94c8b309-b6fb-40f8-90bb-b5c3ac28bacd")
ScriptableComputer.encryptCode_warn = "code encryption is enabled on the computer, the code cannot be changed"
ScriptableComputer.stub = "--this computer was saved using SComputers (fork of ScriptableComputer) download: https://steamcommunity.com/sharedfiles/filedetails/?id=2949350596\nif not a then for _,v in ipairs(getDisplays())do v.clear('0A3EE2')v.drawText(1,1,'need','EEEEEE')v.drawText(1,8,'SComputers!','EEEEEE')v.flush()end a=1 end print(\"this computer was saved using SComputers (fork of ScriptableComputer)\\n#0088ffdownload:#ffffff https://steamcommunity.com/sharedfiles/filedetails/?id=2949350596\")"
ScriptableComputer.notsavedButton = "notsaved"
ScriptableComputer.onStartCpuTime = (1 / 40) * 160
ScriptableComputer.yieldName = "__internal_yield_2f78dcac_8f2b_4785_99e1_a3bbb1ac0410"
ScriptableComputer.architectureNotSupportedEncrypt = "the architecture does not support code encryption"

local maxTickPrintLen = 1024 * 4
local function constrainPrint(str)
    return str:sub(#str - (maxTickPrintLen - 1), #str)
end

----------------------- yield -----------------------

function ScriptableComputer:cl_getMaxCpuTime()
    local time = self.localScriptMode.cpulimit or sc.restrictions.cpu
    if time == -1 then
        return math.huge
    end
    return time
end

local os_clock = os.clock
function ScriptableComputer:cl_init_yield()
    self.cl_startTickTime = os_clock()
end

function ScriptableComputer:cl_yield()
    local maxcputime = self:cl_getMaxCpuTime()
    if os_clock() - self.cl_startTickTime > maxcputime then
        error(ScriptableComputer.longOperationMsg, 3)
    end
end


function ScriptableComputer:sv_init_yield()
    self.sv_startTickTime = os_clock()
end

local sv_yield_counter = 0
function ScriptableComputer:sv_yield()
    if sv_yield_counter >= 256 then
        sv_yield_counter = 0
        
        local maxcputime = self:cl_getMaxCpuTime()
        if self.wait and maxcputime < ScriptableComputer.onStartCpuTime then
            maxcputime = ScriptableComputer.onStartCpuTime
        end
        local execTime = os_clock() - self.sv_startTickTime
        if execTime > maxcputime then
            if self.longExecution >= 2 then
                if self.sv_patience <= 0 then
                    self.crashstate.hasException = true
                    self.crashstate.exceptionMsg = ScriptableComputer.oftenLongOperationMsg
                    self.storageData.noSoftwareReboot = true
                    self:sv_formatException()
                    error(ScriptableComputer.oftenLongOperationMsg, 3)
                else
                    self.sv_startTickTime = os_clock() --if an error occurs in the application program of the operating system, the OS should be able to handle the error
                    self.sv_patience = self.sv_patience - 1
                    error(ScriptableComputer.longOperationMsg, 3)
                end
            else
                self.longExecution = self.longExecution + 1 --sometimes it is allowed to do "long execution" in order to have time to load the program resources
                self.sv_startTickTime = os_clock()
            end
        end
    else
        sv_yield_counter = sv_yield_counter + 1
    end
end

----------------------- SERVER -----------------------

function ScriptableComputer:loadScript()
    self.scriptFunc = nil

    if not self.env then
        self.crashstate.exceptionMsg = "env is missing"
        self.crashstate.hasException = true
        self:sv_formatException()
        return
    end

    if not self.storageData.script then
        self.crashstate.exceptionMsg = "script string is missing"
        self.crashstate.hasException = true
        self:sv_formatException()
        return
    end

    --local text = self.storageData.script:gsub("%[NL%]", "\n")
    local code, err
    local chunkName = "=" .. (self.computerTag or "code")
    if self.storageData.encryptedCode then
        if self.architecture then
            if self.architecture.loadEncrypted then
                code, err = self.architecture.loadEncrypted(self, self.storageData.encryptedCode, chunkName, self.env)
            else
                code, err = nil, "the architecture does not support loading encrypted code"
            end
        else
            code, err = encryptVM.load(self, self.storageData.encryptedCode, self.env)
        end
    else
        if self.architecture then
            if self.architecture.load then
                code, err = self.architecture.load(self, self.storageData.script, chunkName, self.env)
            else
                code, err = nil, "the architecture does not support code loading"
            end
        else
            code, err = safe_load_code(self, self.storageData.script, chunkName, "t", self.env)
        end
    end
    if code then
        self.scriptFunc = code
        self.crashstate.exceptionMsg = nil
        self.crashstate.hasException = false
    else
        self.scriptFunc = nil
        self.crashstate.exceptionMsg = err
        self.crashstate.hasException = true
    end
    self:sv_formatException()
end

function ScriptableComputer:forceUpdateWriters()
    for k, v in pairs(self.interactable:getParents(sm.interactable.connectionType.composite)) do
        local writer = sc.writersRefs[v:getId()] 
        if writer then
            writer:server_updateComputerRegisterValue()
        end
    end
end

function ScriptableComputer:forceUpdateReaders()
    for k, v in pairs(self.interactable:getChildren(sm.interactable.connectionType.composite)) do
        local reader = sc.readersRefs[v:getId()] 
        if reader then
            reader:sv_update()
        end
    end
end

function ScriptableComputer:updateSharedData()
    if self.interactable then
        sc.computersDatas[self.interactable:getId()] = self.publicTable
        self:forceUpdateWriters()
    end
end

function SCArchitecture_reg(name, tbl)
    sc.architectures[name] = nil
    tbl.name = tbl.name or name
    SCArchitecture = tbl
end

local function loadArchitecture(self, key)
    if self.data and self.data.architectureName then
        self[key] = sc.architectures[self.data.architectureName]
        if not self[key] and self.data.architecturePath then
            dofile(self.data.architecturePath)
            sc.architectures[self.data.architectureName] = sc.architectures[self.data.architectureName] or SCArchitecture
            self[key] = sc.architectures[self.data.architectureName]
            SCArchitecture = nil
        end
        if not self[key] then
            self.failed = true
            error("failed to load architecture")
        end
    end
    --self[key] = {}
end


function ScriptableComputer:server_onCreate(constData)
    ------init

    self.realself = self
    loadArchitecture(self, "architecture")
    if self.architecture then
        self.sv_examples = loadExamples(self.architecture.examplesPath, self.architecture.name)
    else
        self.sv_examples = loadExamples()
    end

    sc.computersCount = sc.computersCount + 1

    sc.init()
    sc.xEngineClear()

    self.computerTag = "computer_" .. tostring(math.floor(self.shape and self.shape.id or self.tool.id))

    ------ram

    self.usedRam = 0

    ------cdata
    self.defaultData = self.data or {}
    if constData then
        self.cdata = constData
    else
        self.cdata = self.data or {}
    end

    if not self.cdata.ram then --not implemented yet
        self.cdata.ram = 4 * 1024 * 1024 --4MB
    end

    ------data
    local data = self.storage:load()
    if data then
        self.storageData = data
        self.storageData.crashstate = nil

        if not self.storageData.gsubFix then
            self.storageData.script = self.storageData.script:gsub("%[NL%]", "\n")
            self.storageData.gsubFix = true
        end

        if self.storageData.stub then
            local _, bs64 = unpack(strSplit(string, self.storageData.script, "\n--"))
            self.storageData.script = bs64
        else
            self.storageData.stub = true
        end

        if self.storageData.codeInBase64 then
            self.storageData.script = base64.decode(self.storageData.script)
        else
            self.storageData.codeInBase64 = true
        end
    else
        self.storageData = {
            script = self.sv_examples.load(self.architecture and self.architecture.defaultExample or "template") or "",
            gsubFix = true,
            codeInBase64 = true,
            stub = true
        }

        if self.cdata.unsafe then
            self.storageData.invisible = true
        end
    end
    
    ------env settings

    self.envSettings = {vcomponents = {}}
    if self.cdata and self.cdata.fsSize then
        if self.storageData.fsData then
            self.fs = FileSystem.deserialize(self.storageData.fsData)
        else
            self.fs = FileSystem.new(math.floor(self.cdata.fsSize))
        end
        self.envSettings.vcomponents.disk = {FileSystem.createSelfData(self)}
    end
    
    if self.fs then
        fsmanager_init(self)
    end

    ------init

    self.crashstate = {}
    self.hostonly = not not self.cdata.unsafe

    self.sv_patience = ScriptableComputer.max_patience
    self.lagScore = 0
    self.skipped = 0
    self.uptime = 0
    self.computerTick = 0
    self.wait = 40 * 5 --5 секунды после спавна компа максимальное время выполнения кода будет 160 для того чтобы пролаг от спавна не крашнул комп
    self.longExecution = 0
    self.xEnginesDestroy = {}
    self.currentOutputActive = false
    self.currentOutputPower = 0

    self:sv_reset()
    self:sv_reboot()

    self.old_sum = tableChecksum(self.storageData, "fsData")
end

local newline = string.byte("\n")
local tab = string.byte("\t")
function ScriptableComputer:sv_formatException()
    for k, v in pairs(self.crashstate) do
        if k ~= "hasException" and k ~= "exceptionMsg" then
            self.crashstate[k] = nil
        end
    end

    self.crashstate.hasException = not not self.crashstate.hasException
    if self.crashstate.hasException then
        local str = tostring(self.crashstate.exceptionMsg or "Unknown error"):sub(1, 1024)
        local newstr = {}
        for i = 1, #str do
            local b = str:byte(i)
            if (b >= 32 and b <= 126) or b == newline then
                table.insert(newstr, string.char(b))
            elseif b == tab then
                table.insert(newstr, "   ")
            end
        end
        self.crashstate.exceptionMsg = table.concat(newstr)
        if #self.crashstate.exceptionMsg == 0 then
            self.crashstate.exceptionMsg = "Unknown error"
        end
    else
        self.crashstate.exceptionMsg = nil
    end

    self:sv_updateException()
end

function ScriptableComputer:sv_free()
    self.freeFlag = self.freeFlag or 2
end

function ScriptableComputer:sv_realFree()
    for _, destroy in ipairs(self.xEnginesDestroy) do
        destroy()
    end
    self.xEnginesDestroy = {}
end

function ScriptableComputer:server_onDestroy()
    if self.failed then
        return
    end

    sc.computersCount = sc.computersCount - 1

    self:sv_disableComponentApi()
    self:sv_realFree()

    if self.interactable then
        sc.computersDatas[self.interactable:getId()] = nil
    end
end

function ScriptableComputer:server_onFixedUpdate()
    if self.failed then
        return
    end

    self.interactable:setActive(self.currentOutputActive)
    self.interactable:setPower(self.currentOutputPower)

    self:sv_createLocalScriptMode()

    local connectedComponents = {}
    for _, interactable in ipairs(self.interactable:getParents()) do
        connectedComponents[interactable.id] = true
    end
    for _, interactable in ipairs(self.interactable:getChildren()) do
        connectedComponents[interactable.id] = true
    end
    for interactableId in pairs(self.componentCache) do
        if not connectedComponents[interactableId] then
            self.componentCache[interactableId] = nil
        end
    end

    local ctick = sm.game.getCurrentTick()
    if sc.needScreenSend() then
        if self.printMsg then
            self.network:sendToClients("cl_chatMessage", constrainPrint(table.concat(self.printMsg, "#ffffff\n")))
            self.printMsg = nil
        end

        if self.alertMsg then
            self.network:sendToClients("cl_alertMessage", constrainPrint(table.concat(self.alertMsg, "#ffffff\n")))
            self.alertMsg = nil
        end

        if self.logMsg then
            self.network:sendToClients("cl_logMessage", constrainPrint(table.concat(self.logMsg, "#ffffff\n")))
            self.logMsg = nil
        end
    end

    if ctick % (3 * 40) == 0 then
        self.sv_patience = ScriptableComputer.max_patience
        self.longExecution = 0
    end
    
    if self.freeFlag then
        self.freeFlag = self.freeFlag - 1
        if self.freeFlag < 0 then
            self:sv_realFree()
            self.freeFlag = nil
        end
    end

    if self.new_code then
        self:sv_updateScript(self.new_code, nil, true)
        self.new_code = nil
    end

    if self.new_ecode then
        self:sv_setEncryptedCode(self.new_ecode, self.new_ecode_msg)
        self.new_ecode = nil
        self.new_ecode_msg = nil
    end

    if self.encrypt_flag then
        self:sv_local_encryptCode(true, self.encrypt_msg)
        self.encrypt_flag = nil
        self.encrypt_msg = nil
    end

    if self.reboot_flag or self.software_reboot_flag or sc.rebootAll then
        self:sv_reboot(self.reboot_flag or self.software_reboot_flag, not self.reboot_flag)
        self.reboot_flag = nil
        self.software_reboot_flag = nil
    end

    local sendTable = self:sv_genTable()
    local sendSum = tableChecksum(sendTable)
    if sendSum ~= self.old_sendSum then
        --self.network:sendToClients("cl_getParam", sendTable)
        self:sv_onDataRequired()
        self.old_sendSum = sendSum
    end
    
    if #self.clientInvokes > 0 then
        for _, data in ipairs(self.clientInvokes) do
            if data.player then
                local player
                if type(data.player) == "string" then
                    for _, lplayer in ipairs(sm.player.getAllPlayers()) do
                        if lplayer.name == data.player then
                            player = lplayer
                            break
                        end
                    end
                else
                    player = data.player
                end

                if player then
                    self.network:sendToClient(player, "cl_invokeScript", data)
                end
            else
                self.network:sendToClients("cl_invokeScript", data)
            end
        end
        self.clientInvokes = {}
    end

    if self.interactable then
        self.old_publicData = self.interactable.publicData
        if self.customcomponent_flag then
            self:sv_disableComponentApi(true)
            if self.customcomponent_name and self.customcomponent_api then
                self.interactable.publicData = {
                    sc_component = {
                        type = self.customcomponent_name,
                        api = self.customcomponent_api
                    }
                }
            end
            self.customcomponent_flag = nil
        end
    end

    local activeNow = not not (self.storageData.alwaysOn or self.storageData.active_button or self.external_active)
    if self.interactable and not activeNow then
        for k, inter in pairs(self.interactable:getParents(sm.interactable.connectionType.logic)) do
            if inter:isActive() then
                activeNow = true
                break
            end
        end
    end

    --------------------------------------------------------power control

    if self.wait then
        self.lagScore = 0
        self.wait = self.wait - 1
        if self.wait <= 0 then
            self.wait = nil
        end
    end
    
    if not self.crashstate.hasException and not self.freeFlag then
        if not activeNow and self.isActive then
            self:sv_execute(true) --последняя итерация после отключения входа, чтобы отлавить выключения
            self:sv_disableComponentApi()
            self.uptime = 0
            self.computerTick = 0
        end
        
        if activeNow and not self.isActive then
            self:sv_reboot()
        end

        if activeNow then
            local dropFreq = 0
            if sc.restrictions.adrop then
                if sc.deltaTime >= (1 / 15) then
                    dropFreq = 8
                elseif sc.deltaTime >= (1 / 25) then
                    dropFreq = 4
                elseif sc.deltaTime >= (1 / 30) then
                    dropFreq = 2
                end
            end
            dropFreq = dropFreq + math.floor(self.lagScore / 10)
            if self.lagScore >= 50 then
                dropFreq = dropFreq * 2
            end
            if dropFreq == 1 then dropFreq = 2 end
            if dropFreq == 0 or self.cdata.unsafe or ctick % dropFreq == 0 then
                self:sv_execute()
                self.skipped = 0
            else
                self.skipped = self.skipped + 1
            end
            self.uptime = self.uptime + 1
        end
    end
    if activeNow ~= self.isActive then
        self.network:sendToClients("cl_setActive", activeNow)
    end
    self.isActive = activeNow

    self:sv_formatException()
    if self.crashstate.hasException ~= self.oldhasException or
    self.crashstate.exceptionMsg ~= self.oldexceptionMsg then
        self.oldhasException = self.crashstate.hasException
        self.oldexceptionMsg = self.crashstate.exceptionMsg
        self:sv_sendException()
    end

    --------------------------------------------------------data control

    if sc.needSaveData() then
        if self.changed then
            self.storageData.fsData = self.fs:serialize()
            self.changed = nil
    
            self.saveContent = true
        end

        local sum = tableChecksum(self.storageData, "fsData")
        if self.saveContent or self.old_sum ~= sum then
            local newtbl = sc.deepcopy(self.storageData)
            newtbl.script = ScriptableComputer.stub .. "\n--" .. base64.encode(newtbl.script)
            self.storage:save(newtbl)

            self.saveContent = nil
            self.old_sum = sum
        end
    end

    --------------------------------------------------------lagScore control

    if self.lagScore > 0 then
        self.lagScore = self.lagScore - 1
        if self.lagScore < 0 then
            self.lagScore = 0
        end
    end
end

function ScriptableComputer:sv_createLocalScriptMode()
    self.localScriptMode = {
        scriptMode = sc.restrictions.scriptMode,
        allowChat = sc.restrictions.allowChat
    }

    if self.cdata.unsafe then
        self.localScriptMode.scriptMode = "unsafe"
        self.localScriptMode.allowChat  = true
    end

    if self.cdata.cpulimit then
        self.localScriptMode.cpulimit = self.cdata.cpulimit
    end
end

function ScriptableComputer:sv_genTable()
    local tbl = {
        restrictions = sc.restrictions,
        script = self.storageData.script,
        __lock = self.storageData.__lock,
        alwaysOn = self.storageData.alwaysOn,
        invisible = self.storageData.invisible,
        fs = not not self.fs,
        scriptMode = self.localScriptMode.scriptMode,
        vm = sc.restrictions.vm,
        allowChat = self.localScriptMode.allowChat,
        hasException = self.crashstate.hasException,
        computersAllow = _G.computersAllow,
        localScriptMode = self.localScriptMode,
        hostonly = self.hostonly,
        dislogs = self.storageData.dislogs,
        encryptCode = self.storageData.encryptCode
    }

    if self.storageData.__lock then
        tbl.script = nil
    end

    return tbl
end

function ScriptableComputer:sv_n_reboot()
    self:sv_reboot(true)
end

function ScriptableComputer:sv_disableComponentApi(notRemoveFlags)
    if not self.interactable then return end
    if not notRemoveFlags then
        self.customcomponent_flag = nil
        self.customcomponent_name = nil
        self.customcomponent_api = nil
    end

    if self.old_publicData and self.old_publicData.sc_component and self.old_publicData.sc_component.api then
        for key, value in pairs(self.old_publicData.sc_component.api) do
            self.old_publicData.sc_component.api[key] = nil
        end
        self.old_publicData.sc_component.api[-1] = true
        self.old_publicData.sc_component.api = nil
        self.old_publicData.sc_component.name = nil
        self.old_publicData.sc_component = nil
        if sm.exists(self.interactable) then
            self.interactable.publicData = {}
        end
    end
end

function ScriptableComputer:sv_updateException()
    for k, v in pairs(self.publicTable.public.crashstate) do
        self.publicTable.public.crashstate[k] = nil
    end
    for k, v in pairs(self.crashstate) do
        self.publicTable.public.crashstate[k] = v
    end
end

function ScriptableComputer:sv_createEnv(fromProcessLibrary, isolation)
    local env
    if self.localScriptMode.scriptMode == "unsafe" then
        env = createUnsafeEnv(self, self.envSettings, fromProcessLibrary, isolation)
    else
        env = createSafeEnv(self, self.envSettings, fromProcessLibrary, isolation)
    end

    if self.localScriptMode.scriptMode == "safe_with_open" then
        env.sm.json.open = sm.json.open
    end

    return env
end

function ScriptableComputer:sv_reset()
    self:sv_createLocalScriptMode()
    self.clientInvokes = {}
    self.componentCache = {}
    self.luastate = {}
    self.libcache = {}
    self.registers = {}
    self.uptime = 0
    self.xEngine_instanceLimit = 2
    self.computerTick = 0
    self.env = self:sv_createEnv()
    self.publicTable = {
        public = {
            registers = self.registers,
            env = self.env,
            crashstate = {}
        },
        self = self
    }
    self.storageData.noSoftwareReboot = nil
    self.th = nil
    self.sleepTime = nil
    self:sv_updateException()
    self:updateSharedData()
end

function ScriptableComputer:sv_reboot(force, not_execute)
    local fromException = self.crashstate.hasException
    if force and self.crashstate.hasException then
        self.crashstate.hasException = nil
        self.crashstate.exceptionMsg = nil
        self:sv_sendException()
    end

    if self.crashstate.hasException then
        return
    end

    self.crashstate.hasException = nil
    self.crashstate.exceptionMsg = nil
    self.oldhasException = nil
    self.oldexceptionMsg = nil
    self:sv_updateException()

    if self.isActive and not not_execute and not fromException then
        self:sv_execute(true) --последняя итерация после отключения входа, чтобы отлавить выключения
    end

    ----------------------------

    self:sv_reset()
    self:loadScript()
    self:sv_disableComponentApi()
    self.network:sendToClients("cl_clear")
    self:sv_formatException()

    self.printMsg = nil
    self.alertMsg = nil
    self.logMsg = nil
    self.rebootId = tostring(sm.uuid.new())
end

local function drawSmile(display, x, y, sizeX, sizeY)
    local strokeSize = math.floor(sizeX / 16)
    if strokeSize <= 1 then
        strokeSize = 1
    end
    display.fillRect(x, y, sizeX, sizeY, 0x000000)
    display.drawRect(x, y, sizeX, sizeY, 0xffffff, strokeSize)

    x = x + (strokeSize * 2)
    y = y + (strokeSize * 2)
    sizeX = sizeX - (strokeSize * 4)
    sizeY = sizeY - (strokeSize * 4)

    local pointSizeX, pointSizeY = math.floor(sizeX / 6), math.floor(sizeY / 6)
    local function drawPoint(lx, ly)
        display.fillRect(x + (lx * pointSizeX), y + (ly * pointSizeY), pointSizeX, pointSizeY, 0x00ff00)
    end

    drawPoint(0, 0)
    drawPoint(0, 1)
    drawPoint(5, 0)
    drawPoint(5, 1)
    drawPoint(2, 3)
    drawPoint(3, 3)
    drawPoint(1, 4)
    drawPoint(4, 4)
end

local function printException(self)
    local msg = self.crashstate.exceptionMsg

    local graphic = scomputers.require(self, "graphic")
    local fonts = scomputers.require(self, "fonts")
    for _, display in ipairs(sc.getComponents(self, "display", self.envSettings)) do
        local rotation = display.getRotation()
        display.reset()
        display.setRotation(rotation)
        display.clear(0x2f4d95)
        local fontScaleX, fontScaleY = display.getFontScale()
        local width, height = display.getSize()

        if width >= 128 then
            local oldTextSpacing = display.getTextSpacing()
            local smileSize = height / 8
            local objOffset = math.max(height / 60, 1)

            -- draw smile and title
            drawSmile(display, objOffset, objOffset, smileSize, smileSize)

            display.setFont(fonts.lgc_5x5)
            local origFontSizeX = display.getFontWidth()
            local title = "CRASH!"
            local posX = objOffset + smileSize + objOffset
            display.setFontSize(smileSize, smileSize)
            display.setTextSpacing(math.max(1, math.floor(smileSize / origFontSizeX)))
            display.drawText(posX, objOffset, title)

            -- draw border line
            local borderSizeY = math.max(1, math.ceil(height / 120))
            local textPadding = width / 32
            local textSizeX = width - (textPadding * 2)
            display.fillRect(textPadding, smileSize + (objOffset * 2), textSizeX, borderSizeY, 0xffffff)

            -- draw error text
            if width >= 640 then
                display.setFont(fonts.arial_72)
                display.setFontScale(1, 1)
                local fontScale = width / display.getFontWidth() / 35
                display.setFontScale(fontScale, fontScale)
                display.setTextSpacing(0)
            else 
                display.setFont(nil)
                display.setFontScale(1, 1)
                display.setTextSpacing(1)
            end

            graphic.textBox(display, textPadding, borderSizeY + smileSize + (objOffset * 3), textSizeX, height - (textPadding * 2),
                makeErrorColor(msg),
                0xffffff,
                false,
                false,
                display.getFontHeight() / 5,
                true,
                canvasAPI.utf8,
                true
            )
            
            display.setFont(nil)
            display.setTextSpacing(oldTextSpacing)
            display.setFontScale(fontScaleX, fontScaleY)
        else
            local textPadding = 1
            if width == 64 then
                textPadding = 2
            end
            drawSmile(display, textPadding, textPadding, width - (textPadding * 2), height - (textPadding * 2))
        end

        display.flush()
    end

    for _, terminal in ipairs(sc.getComponents(self, "terminal", self.envSettings)) do
        terminal.write("--------------------------------------- computer crashed with error ----------------------------------------\n")
        terminal.write(makeErrorColor(formatBeforeGui(msg)))
        terminal.write("\n-----------------------------------------------------------------------------------------------------------------------\n")
    end
end

function ScriptableComputer:sv_printException()
    if self.crashstate.hasException and self.env and not self.env._disableBsod then
        local ok, err = pcall(printException, self)
        if not ok then
            sm.log.error("failed to print error: ", err)
        end
    end
end

function ScriptableComputer:sv_sendException()
    self:sv_formatException()
    if self.crashstate.hasException then
        self:sv_free()
        self:sv_disableComponentApi()
        sm.log.error("computer crashed", self.crashstate.exceptionMsg)
        self.network:sendToClients("cl_onComputerException", {self.crashstate.exceptionMsg, self.computerTag})
    else
        self.network:sendToClients("cl_onComputerException")
    end
    self:sv_printException()
end

function ScriptableComputer:sv_execute(endtick, onStartCall)
    if self.scriptFunc and _G.computersAllow then
        local onStartExists = false
        if self.env and self.env.onStart then
            onStartExists = true
        end

        if self.sleepTime then
            self.sleepTime = self.sleepTime - 1
            if self.sleepTime <= 0 then
                self.sleepTime = nil
            else
                return
            end
        end

        tweaks()
        self:forceUpdateWriters()
        sc.lastComputer = self
        local startExecTime = os.clock()

        if not self.env then
            self.crashstate.hasException = true
            self.crashstate.exceptionMsg = "Unknown error"
            self:sv_formatException()
            sc.lastComputer = nil
            unTweaks()
            return
        end

        if endtick then
            self.env._endtick = true
            self:sv_free()
        end

        --if sc.restrictions.vm == "luaInLua" then
        --    ll_Interpreter:reset()
        --end
        
        local func, arg
        if onStartCall then
            func = self.env.onStart
        else
            if self.env._endtick and self.env._enableCallbacks and self.env.onStop then
                func = self.env.onStop
            elseif self.env._enableCallbacks then
                func = self.env.onTick or function() end
                pcall(function()
                    arg = self.env.getDeltaTimeTps() * (self.env.getSkippedTicks() + 1)
                end)
            elseif self.env.callback_loop then
                func = self.env.callback_loop
            else
                func = self.scriptFunc
            end
        end
        
        --[[
        local coroutine = sc.getApi("coroutine")
    if coroutine and coroutine.fixed then]]
        
        self:sv_init_yield()
        local ran, err
        if sc.coroutineFixed() then
            local coroutine = sc.getApi("coroutine")
            if not self.th or func ~= self.oldFunc or coroutine.status(self.th) == "dead" then
                if type(func) == "table" then
                    self.th = coroutine.create(func[3])
                else
                    self.th = coroutine.create(func)
                end
                self.oldFunc = func
            end
            ran, err = coroutine.resume(self.th)
            if ran then
                local t = type(err)
                if t == "number" then
                    err = math.floor(err + 0.5)
                    if err < 1 then err = 1 end
                    self.sleepTime = err
                end
            end
        elseif not self.architecture or not self.architecture.withoutTrackback then
            ran, err = smartCall(self.scriptFunc, func, arg)
        else
            ran, err = pcall(func, arg)
        end
        do
            local lok, lerr = pcall(function(self) self:sv_yield() end, self) --кастыль с лямбдой НУЖЕН для правильного разположения ошибки
            if not lok and not err then
                self.crashstate.hasException = true
                self.crashstate.exceptionMsg = lerr
                self:sv_formatException()
            end
        end

        if self.crashstate.hasException then
            sc.lastComputer = nil
            self:forceUpdateReaders()
            unTweaks()
            return
        end

        if ran and self.lagScore > 100 then
            self.lagScore = 0
            self.crashstate.hasException = true
            self.crashstate.exceptionMsg = ScriptableComputer.lagMsg
            self.storageData.noSoftwareReboot = true
            self:sv_formatException()
        end
        
        if not ran then
            if sc.restrictions.vm == "luaInLua" then
                err = ll_shorterr(err)
            end

            self.crashstate.hasException = true
            self.crashstate.exceptionMsg = err
            self:sv_formatException()
            
            local errFunc, detectReboot
            if self.env._enableCallbacks then
                detectReboot = true
                errFunc = self.env.onError
            else
                errFunc = self.env.callback_error
            end
            if errFunc then
                self:sv_init_yield()
                local ran, err = smartCall(self.scriptFunc, errFunc, err)
                if not ran then
                    sm.log.error("error in the error handler", err)
                elseif err and detectReboot and not self.storageData.noSoftwareReboot then
                    self.software_reboot_flag = true
                end
            end
        end

        sc.addLagScore((os.clock() - startExecTime) * sc.clockLagMul)
        sc.lastComputer = nil
        self:forceUpdateReaders()
        unTweaks()

        if not self.crashstate.hasException and not onStartExists and self.env and self.env._enableCallbacks and self.env.onStart then
            self:sv_execute(false, true)
        end

        if not onStartCall then
            self.computerTick = self.computerTick + 1
        end
    end
end

function ScriptableComputer:sv_updateData(data)
    if self.storageData.__lock then
        return
    end

    data.restrictions = nil
    data.fs = nil
    data.scriptMode = nil
    data.vm = nil
    data.allowChat = nil
    data.hasException = nil
    data.computersAllow = nil
    data.localScriptMode = nil
    data.hostonly = nil
    data.encryptCode = nil

    for key, value in pairs(data) do --чтобы не перетереть ключи которых нет на клиенте(по этому тут цикл а не просто присвоения)
        self.storageData[key] = value
    end
end

function ScriptableComputer:sv_local_encryptCode(state, message)
    if state then
        local ok, result
        if self.architecture then
            if self.architecture.encrypt then
                ok, result = self.architecture.encrypt(self, self.storageData.script)
            else
                ok, result = false, ScriptableComputer.architectureNotSupportedEncrypt
            end
        else
            ok, result = pcall(encryptVM.compile, self, self.storageData.script)
        end
        if ok then
            if message then
                message = message:sub(1, ScriptableComputer.maxEncryptMessageSize)
            end
            if message == "" then message = nil end
            message = "THIS CODE WAS ENCRYPTED" .. (message and ("\n" .. message) or "")
            message = message:sub(1, ScriptableComputer.maxcodesize)
            self.storageData.encryptedCode = result
            self.storageData.encryptCode = true
            self.network:sendToClients("cl_getParam", self:sv_genTable())
            self:sv_updateScript(message, nil, true)
        else
            self.network:sendToClients("cl_internal_alertMessage", "failed to encrypt code: " .. tostring(result or "unknown error"))
        end
    else
        self.storageData.encryptedCode = nil
        self.storageData.encryptCode = false
        self.network:sendToClients("cl_getParam", self:sv_genTable())
        self:sv_updateScript("", nil, true)
    end
    self:sv_updateTmpdata()
end

function ScriptableComputer:sv_setEncryptedCode(ecode, message)
    if message then
        message = message:sub(1, ScriptableComputer.maxEncryptMessageSize)
    end
    if message == "" then message = nil end
    message = "THIS CODE WAS ENCRYPTED" .. (message and ("\n" .. message) or "")
    message = message:sub(1, ScriptableComputer.maxcodesize)
    self.storageData.encryptedCode = ecode
    self.storageData.encryptCode = true
    self.network:sendToClients("cl_getParam", self:sv_genTable())
    self:sv_updateScript(message, nil, true)
    self:sv_updateTmpdata()
end

function ScriptableComputer:sv_encryptCode(data)
    self:sv_local_encryptCode(data[1], data[2])
    self:sv_reboot(true)
end

------------network
function ScriptableComputer:sv_updateScript(data, caller, notReboot)
    if caller and (self.storageData.__lock or self:needBlockCall(caller)) then
        return
    end

    if not data or #data > ScriptableComputer.maxcodesize then
        if caller then
            self.network:sendToClient(caller, "cl_internal_alertMessage", ScriptableComputer.maxCodeSizeStr)
        end
        return false
    end

    self.storageData.script = data
    if not notReboot then
        self:sv_reboot(true)
    end

    for _, player in ipairs(sm.player.getAllPlayers()) do
        if not caller or player ~= caller then
            if not self.storageData.__lock then
                self.network:sendToClient(player, "cl_updateScript", self.storageData.script)
            else
                self.network:sendToClient(player, "cl_updateScript")
            end
        end
    end

    return true
end


function ScriptableComputer:sv_updateTmpdata(player)
    local cltmp = {}
    if self.storageData.encryptCode then
        cltmp.encryptVM_version = encryptVM.version(self, self.storageData.encryptedCode)
    end

    if player then
        self.network:sendToClient(player, "cl_updateTmpdata", cltmp)
    else
        self.network:sendToClients("cl_updateTmpdata", cltmp)
    end
end

function ScriptableComputer:sv_onDataRequired(_, client)
    local players
    if client then
        players = {client}
    else
        players = sm.player.getAllPlayers()
    end
    
    for index, lclient in ipairs(players) do
        if not self:needBlockCall(lclient) then
            if client then
                if not self.storageData.__lock then
                    self.network:sendToClient(lclient, "cl_updateScript", self.storageData.script)
                else
                    self.network:sendToClient(lclient, "cl_updateScript")
                end
            end

            self.network:sendToClient(lclient, "cl_getParam", self:sv_genTable())
            self.network:sendToClient(lclient, "cl_setActive", self.isActive)
            self:sv_updateTmpdata(lclient)
        end

        if self.cdata.arduino then
            self.network:sendToClient(lclient, "cl_createEffect")
        end
    end
end

function ScriptableComputer:sv_invokeScript(data)
    local script, args = unpack(data)
    
    local code, err = safe_load_code(self, script, "=server_invoke", "t", self.env)
    if not code then
        sm.log.error("server invoke syntax error: " .. (err or "Unknown error"))
        return
    end

    self:sv_init_yield()

    tweaks()
    sc.lastComputer = self
    local ran, err = pcall(code, unpack(args))
    sc.lastComputer = nil
    unTweaks()

    if not ran then
        sm.log.error("server invoke error: " .. (err or "Unknown error"))
    end
end

function ScriptableComputer:needBlockCall(caller)
    if self.hostonly and caller.id ~= vnetwork.host.id then
        return true
    end
end

----------------------- CLIENT -----------------------

function ScriptableComputer:client_onCreate()
    self.defaultData = self.data or {}
    
    loadArchitecture(self, "cl_architecture")
    if self.cl_architecture then
        self.cl_examples = loadExamples(self.cl_architecture.examplesPath, self.cl_architecture.name)
    else
        self.cl_examples = loadExamples()
    end

    self.network:sendToServer("sv_onDataRequired")
    self.last_script = ""
    self.exampleSearch = ""
    self.consoleLog = {}
    self.consoleLog_afterTraceback = {}
    self.serverInvokes = {}
    self.cltmp = {}
    sc.allComputers[self] = true
    if self.interactable then
        sc.allComputersIds[self.interactable.id] = true
    end

    self.encryptCode_toggle_func = function (message)
        self.network:sendToServer("sv_encryptCode", {not self.cStorageData.encryptCode, message})
    end
end

function ScriptableComputer:client_onFixedUpdate(dt)
    sc.deltaTimeTps = dt

    if not self.cStorageData then return end

    if self.textEditor then
        if sm.game.getCurrentTick() % 10 == 0 then
            self.newText = self.newText or self.last_script
            local newText = self.textEditor()
            if newText ~= self.newText then
                self.last_script = newText
                self.newText = newText
                self:cl_rawSetText(newText)
                self:cl_onSaveScript()
            elseif self.last_script ~= newText then
                self.textEditor(true)
                self.textEditor = nil
            end
        end
    else
        self.newText = nil
    end

    if #self.serverInvokes > 0 then
        for _, data in ipairs(self.serverInvokes) do
            self.network:sendToServer("sv_invokeScript", data)
        end
        self.serverInvokes = {}
    end

    if self.saveAcceptGui then
        if sm.exists(self.saveAcceptGui) then
            if not self.saveAcceptGui:isActive() then
                self.saveAcceptGui:open()
            end
        else
            self.saveAcceptGui = nil
        end
    end

    if self.acceptCheckDelay then
        self.acceptCheckDelay = self.acceptCheckDelay - 1
        if self.acceptCheckDelay <= 0 then
            self.acceptCheckDelay = nil
        end
    end
    if self.guiOpened and not self.gui:isActive() and not self.acceptCheckDelay then
        self.guiOpened = nil
        local script = self.cStorageData.script or self.old_script
        if script ~= self.last_script then
            self:cl_saveAccept()
        end
    end

    if self.gui and self.gui:isActive() then
        if _g_saveBind and not self.saveBindState then
            self:cl_onSaveScript()
        end
        self.saveBindState = _g_saveBind
    else
        self.saveBindState = nil
    end

    if self.aiGen then
        local str, ok = self.aiGen()
        if str then
            self:cl_setText(str)
            if not self.gui:isActive() then
                self:cl_onSaveScript()
            end
            if ok then
                self:cl_internal_alertMessage("code generation is complete!")
            else
                self:cl_internal_alertMessage("something went wrong...")
            end
            self.aiGen = nil
        end
    end

    if not sm.isHost and self.cStorageData.hostonly and self.interact then
        self:cl_internal_alertMessage("#ff0000only the host can open unsafe-computer")
        self.interact = nil
        self.flag1 = nil
        self.flag2 = nil
    end

    if self.interactable then
        local uvpos
        local isActive = self.interactable:isActive()
        if isActive then
            uvpos = ScriptableComputer.UV_NON_ACTIVE + ScriptableComputer.UV_ACTIVE_OFFSET
        else
            uvpos = ScriptableComputer.UV_NON_ACTIVE
        end

        if self.cStorageData.hasException or not self.cStorageData.computersAllow then
            local uv = ScriptableComputer.UV_HAS_ERROR
            if not self.cStorageData.computersAllow then
                uv = ScriptableComputer.UV_HAS_DISABLED
            end

            local blk = (sm.game.getCurrentTick() % 60 >= 30)
            self.interactable:setUvFrameIndex(blk and uv or uvpos)
            if self.led_eff then
                self.led_eff:setParameter("color", sm.color.new(1, 0, 0))
                if blk then
                    if not self.led_eff:isPlaying() then
                        self.led_eff:start()
                    end
                else
                    self.led_eff:stop()
                end
            end
        else
            self.interactable:setUvFrameIndex(uvpos)
            if self.led_eff then
                self.led_eff:setParameter("color", sm.color.new(0, 1, 0))
                if isActive then
                    if not self.led_eff:isPlaying() then
                        self.led_eff:start()
                    end
                else
                    self.led_eff:stop()
                end
            end
        end

        if self.pwr_eff then
            if self.clIsActive then
                if not self.pwr_eff:isPlaying() then
                    self.pwr_eff:start()
                end
            else
                self.pwr_eff:stop()
            end
        end
    end


    if self.gui and self.tmpData then
        if not self.gui:isActive() and self.tmpDataUpdated then
            self.cStorageData.__lock = self.tmpData.__lock

            self.network:sendToServer("sv_updateData", self.cStorageData)
            self.tmpDataUpdated = nil
        end

        if sc.restrictions then
            local localTag = ""
            if self.cStorageData.encryptCode or sc.restrictions.scriptMode ~= self.cStorageData.scriptMode or (not sc.restrictions.allowChat) ~= (not self.cStorageData.allowChat) then
                local vmname = self.cStorageData.encryptCode and ("encryptVM_" .. (self.cltmp.encryptVM_version or "unknown")) or self.cStorageData.vm
                localTag = localTag .. "   (Local Script Mode: " .. vmname .. "-" .. self.cStorageData.scriptMode .. "-" .. (self.cStorageData.allowChat and "printON" or "printOFF") .. ")"
            end
            self.gui:setText("scrMode", "Script Mode: " .. self.cStorageData.vm .. "-" .. sc.restrictions.scriptMode .. "-" .. (sc.restrictions.allowChat and "printON" or "printOFF") .. localTag)
        end
        
        self.gui:setButtonState("alwaysOn", self.cStorageData.alwaysOn)
        self.gui:setButtonState("editLock", self.tmpData.__lock)
        self.gui:setButtonState("invisible", self.cStorageData.invisible)
        self.gui:setButtonState("dislogs", self.cStorageData.dislogs)
        self.gui:setButtonState("encryptCode", self.cStorageData.encryptCode)

        --self.gui:setButtonState("notsaved", self.cStorageData.script ~= string.gsub(self.last_code, "\n", "%[NL%]"))
        local script = self.cStorageData.script or self.old_script
        self.notSaved = script ~= self.last_script
        self.gui:setButtonState(ScriptableComputer.notsavedButton, self.notSaved)
    end

    if self.interact and not self.flag1 and not self.flag2 then
        self.interact = nil

        self:cl_createGUI()
        --self.gui:setText("lastMessage", "")

        if not self.cStorageData.computersAllow then
            self:cl_internal_alertMessage("computers are disabled in this game session")
        end

        if self.cStorageData.__lock then
            self:cl_internal_alertMessage("this computer is locked")
            return
        end

        self:cl_rawSetText(self.last_script)
        self:cl_guiOpen()
    end

    if self.openTimer then
        self.openTimer = self.openTimer - 1
        if self.openTimer <= 0 then
            self:cl_rawSetText(self.last_script)
            self:cl_guiOpen()
            self.openTimer = nil
        end
    end
end

function ScriptableComputer:cl_updateTmpdata(data)
    self.cltmp = data
end

function ScriptableComputer:client_onUpdate(dt)
    sc.deltaTime = dt
end

function ScriptableComputer.client_onDestroy(self)
    if self.gui then
        self.gui:destroy()
    end
    if self.textEditor then
        self.textEditor(true)
    end
    sc.allComputers[self] = nil
    if self.interactable then
        sc.allComputersIds[self.interactable.id] = nil
    end
end

function ScriptableComputer.client_onInteract(self, _, state)
    if state then
        self.lastFontScale = self.lastFontScale or localStorage.current.fontScale
        if self.lastFontScale ~= localStorage.current.fontScale then
            self:cl_recreateGui()
        end
        self.lastFontScale = localStorage.current.fontScale

        self:cl_createGUI()
        --[[
        if not self.updateExamplesFlag then
            updateExamples(self)
            self.updateExamplesFlag = true
        end
        ]]
        self.network:sendToServer("sv_onDataRequired", sm.localPlayer.getPlayer())

        self.tmpData = {}
        for key, value in pairs(self.cStorageData) do
            self.tmpData[key] = value
        end

        self.flag1 = true
        self.flag2 = true
        self.interact = true
    end
end

function ScriptableComputer:cl_createEffect()
    if not self.pwr_eff then
        self.pwr_eff = sm.effect.createEffect(sc.getEffectName(), self.interactable)
        self.led_eff = sm.effect.createEffect(sc.getEffectName(), self.interactable)

        self.pwr_eff:setParameter("color", sm.color.new(1, 0, 0))

        self.pwr_eff:setParameter("uuid", ScriptableComputer.ledUuid)
        self.led_eff:setParameter("uuid", ScriptableComputer.ledUuid)

        self.pwr_eff:setScale(sm.vec3.new(0.03, 0.02, 0.01))
        self.led_eff:setScale(sm.vec3.new(0.03, 0.02, 0.01))

        self.pwr_eff:setOffsetPosition(sm.vec3.new(0.27, 0.095, -0.11))
        self.led_eff:setOffsetPosition(sm.vec3.new(-0.03, 0.15, -0.11))
    end
end

function ScriptableComputer:cl_setActive(isActive)
    self.clIsActive = isActive
end

------------gui
function ScriptableComputer:cl_createGUI()
    if self.gui then return end

    local path = "$CONTENT_DATA/Gui/Layouts/ComputerMenu"
    if localStorage.current.fontScale == 0 then
        path = path .. "_verySmallFont"
    elseif localStorage.current.fontScale == 1 then
        path = path .. "_smallFont"
    elseif localStorage.current.fontScale == 3 then
        path = path .. "_bigFont"
    end
    
    self.gui = sm.gui.createGuiFromLayout(path .. ".layout", false)
    self.gui:setButtonCallback("ScriptSave", "cl_onSaveScript")
    self.gui:setButtonCallback("CloseGui", "cl_closeGui")
    self.gui:setTextChangedCallback("ScriptData", "cl_onScriptDataChanged")
    self.gui:setTextChangedCallback("search", "cl_onSearchChanged")
    self.gui:setButtonCallback("openStorage", "cl_openStorage")
    self:cl_consoleUpdate()

    self.gui:setButtonCallback("alwaysOn", "cl_onCheckbox")
    self.gui:setButtonCallback("editLock", "cl_onCheckbox")
    self.gui:setButtonCallback("invisible", "cl_onCheckbox")
    self.gui:setButtonCallback("dislogs", "cl_onCheckbox")
    self.gui:setButtonCallback("encryptCode", "cl_onCheckbox")
    
    self.gui:setButtonCallback("reboot", "cl_reboot")
    self.gui:setButtonCallback("formatCode", "cl_formatCode")

    self.gui:setButtonCallback("externEditor", "cl_externEditor")
    --self.gui:setButtonCallback("externEditor", "cl_ai")
    self.gui:setButtonCallback("ai", "cl_ai")

    self.gui:setButtonCallback("palette", "cl_palette")
    self.gui:setButtonCallback("fontScale", "cl_fontScale")

    self.gui:setVisible("ai", false)
    --self.gui:setVisible("externEditor", false)

    self.gui:setButtonCallback("exmpload", "cl_onExample")
    self.gui:setTextChangedCallback("exmpnum", "cl_onExample")

    self:cl_updateExamplesList()

    if self.cl_architecture then
        self.gui:setText("Title", self.cl_architecture.computerTitle or "computer")
    else
        self.gui:setText("Title", "lua computer")
    end
end

function ScriptableComputer:cl_palette()
    localStorage.current.palette = (localStorage.current.palette + 1) % localStorage.paletteCount
    localStorage.save()
    self:cl_rawSetText(self.last_script)
end

function ScriptableComputer:cl_recreateGui()
    if self.gui then
        self:cl_closeGui()
        self.gui:destroy()
        self.gui = nil
    end
    self:cl_createGUI()
    self.gui:setText("search", self.exampleSearch)
    self.gui:setText("exmpnum", self.lastExampleStr or "")
    --updateExamples(self, self.exampleSearch)
    self.gui:setVisible("openStorage", not not self.cStorageData.fs)
    self:cl_rawSetText(self.last_script)
    self:cl_guiOpen()
end

function ScriptableComputer:cl_guiOpen()
    self.guiOpened = true
    if self.cStorageData and self.cStorageData.fs then
        self.gui:setVisible("openStorage", true)
    else
        self.gui:setVisible("openStorage", false)
    end
    self.gui:open()
end

function ScriptableComputer:cl_updateExamplesList()
    self.gui:setText("exmplist", self.cl_examples.getList(self.exampleSearch))
end

function ScriptableComputer:cl_onSearchChanged(_, text)
    self.exampleSearch = text
    self:cl_updateExamplesList()
    --updateExamples(self, self.exampleSearch)
end

function ScriptableComputer:cl_fontScale()
    localStorage.current.fontScale = (localStorage.current.fontScale + 1) % localStorage.fontScaleCount
    localStorage.save()
    self:cl_recreateGui()
    self.acceptCheckDelay = 4
end

function ScriptableComputer:cl_openStorage()
    if self.cStorageData.__lock then
        self:cl_internal_alertMessage("this computer is locked")
        return
    end

    if not self.cStorageData.fs then
        self:cl_internal_alertMessage("this computer is not contain internal storage")
        return
    end

    self:cl_closeGui()
    fsmanager_init(self)
    fsmanager_open(self)
end

function ScriptableComputer:cl_reboot()
    self.network:sendToServer("sv_n_reboot")
end

function ScriptableComputer:cl_formatCode()
    if not self.cl_architecture then
        self.last_script = syntax_format(self.last_script)
        self:cl_rawSetText(self.last_script)
    elseif self.cl_architecture.formatCode then
        self.last_script = self.cl_architecture.formatCode(self, self.last_script)
        self:cl_rawSetText(self.last_script)
    else
        self:cl_internal_alertMessage("the architecture does not support code formatting")
    end
end

function ScriptableComputer:cl_onCheckbox(widgetName)
    if widgetName == "alwaysOn" then
        self.cStorageData.alwaysOn = not self.cStorageData.alwaysOn
        self.network:sendToServer("sv_updateData", self.cStorageData)
    elseif widgetName == "editLock" then
        self.tmpData.__lock = not self.tmpData.__lock
        self.tmpDataUpdated = true
        self.network:sendToServer("sv_updateData", self.cStorageData)
    elseif widgetName == "invisible" then
        self.cStorageData.invisible = not self.cStorageData.invisible
        self.network:sendToServer("sv_updateData", self.cStorageData)
    elseif widgetName == "dislogs" then
        self.cStorageData.dislogs = not self.cStorageData.dislogs
        self.network:sendToServer("sv_updateData", self.cStorageData)
    elseif widgetName == "encryptCode" then
        if self.cStorageData.encryptCode then
            self:cl_accept("are you sure you want to disable code encryption? THE CODE WILL BE ERASED FROM THE COMPUTER!", self.encryptCode_toggle_func)
        elseif not self.cl_architecture or self.cl_architecture.encrypt then
            if self.notSaved then
                self:cl_internal_alertMessage("to encrypt the code, first save or rollback the changes")
            else
                self:cl_messageAccept("are you sure you want to enable code encryption? YOU WON'T BE ABLE TO EXTRACT THE CODE ANYMORE!", self.encryptCode_toggle_func)
            end
        else
            self:cl_internal_alertMessage(ScriptableComputer.architectureNotSupportedEncrypt)
        end
    end
end

function ScriptableComputer.cl_onScriptDataChanged(self, widgetName, data)
    --self.oldtext = data
    local oldLast_script = self.last_script
    self.last_script = formatAfterGui(data)
    if (#self.last_script > #oldLast_script and self.last_script:sub(1, #oldLast_script) == oldLast_script) or
    (#self.last_script < #oldLast_script and oldLast_script:sub(1, #self.last_script) == self.last_script) then
        self:cl_rawSetText(self.last_script)
    end
    self:cl_updateLinesNumbers()
end

function ScriptableComputer:cl_realSave()
    if self.cStorageData.encryptCode then
        self:cl_internal_alertMessage(ScriptableComputer.encryptCode_warn)
        return
    end
    
    if #self.last_script > ScriptableComputer.maxcodesize then
        self:cl_internal_alertMessage(ScriptableComputer.maxCodeSizeStr)
    else
        self.network:sendToServer("sv_updateScript", self.last_script)
    end
end

function ScriptableComputer.cl_onSaveScript(self)
    self:cl_realSave()
end

function ScriptableComputer:cl_closeGui()
    self.gui:close()
end

------------network
function ScriptableComputer:cl_invokeScript(tbl)
    local script, isSafe, args, rebootId = unpack(tbl)
    --script = script:gsub("%[NL%]", "\n")

    local env
    if self.client_env and isSafe == self.client_env_isSafe and rebootId == self.client_env_rebootId then
        env = self.client_env
    else
        env = createClientEnv(self)
        self.client_env = env
        self.client_env_isSafe = isSafe
        self.client_env_rebootId = rebootId
    end
    
    --if self.cStorageData.restrictions.vm == "luaInLua" then
    --    ll_Interpreter:reset()
    --end

    local code, err = safe_load_code(self, script, "=client_invoke", "t", env)
    if not code then
        sm.log.error("client invoke syntax error: " .. (err or "Unknown error"))
        return
    end

    self:cl_init_yield()

    tweaks()
    sc.lastComputer = self
    local ran, err = pcall(code, unpack(args))
    sc.lastComputer = nil
    unTweaks()

    if not ran then
        sm.log.error("client invoke error: " .. (err or "Unknown error"))
    end
end

function ScriptableComputer:cl_clear()
    self.client_env = nil
    self.client_env_isSafe = nil
    self.client_env_rebootId = nil
    self.consoleLog = {}
    self.consoleLog_afterTraceback = {}
    self:cl_consoleUpdate()
end

function ScriptableComputer:cl_onComputerException(data)
    self:cl_createGUI()

    data = data or {}
    local msg, computerTag = data[1], data[2]
    local oldErrorLine = self.errorLine

    self.currentError = nil
    self.errorLine = nil
    if msg then
        self.currentError = msg
        if self.cl_architecture then
            if self.cl_architecture.findErrorLine then
                self.errorLine = self.cl_architecture.findErrorLine(self, msg, computerTag)
            end
        else
            self.errorLine = parseErrorLine(msg, computerTag)
        end
    end
    self:cl_consoleUpdate()

    if oldErrorLine ~= self.errorLine then
        self:cl_rawSetText(self.last_script)
    end
end

function ScriptableComputer:cl_consoleUpdate()
    if not self.gui then
        return
    end
    local err = table.concat(self.consoleLog, "#ffffff\n")
    if self.currentError then
        if #self.consoleLog > 0 then
            err = err .. "\n#ffffff"
        end
        err = err .. makeErrorColor(formatBeforeGui(self.currentError))
    end
    if #self.consoleLog_afterTraceback > 0 then
        err = err .. "\n#ffffff" .. table.concat(self.consoleLog_afterTraceback, "#ffffff\n")
    end
    self.gui:setText("ExceptionData", err)
end

function ScriptableComputer:cl_getParam(data)
    self.flag2 = nil
    self.cStorageData = data
    --self.gui:setVisible("openStorage", not not self.cStorageData.fs)

    if sm.isHost then return end
    self.localScriptMode = data.localScriptMode
end

function ScriptableComputer:cl_updateScript(code)
    self.flag1 = nil

    if code then
        if self.cStorageData then
            self.cStorageData.script = code
        end
        self.last_script = code
        self.old_script = code

        self:cl_createGUI()
        if self.gui:isActive() then
            self:cl_rawSetText(code)
        end
    end
end

function ScriptableComputer:cl_onExample(widgetName, text)
    if widgetName == "exmpnum" then
        self.lastExampleStr = text
        return
    elseif widgetName == "exmpload" then
        local example = self.lastExampleStr and self.cl_examples.load(self.lastExampleStr)
        if example then
            self:cl_setText(example)
        else
            self:cl_internal_alertMessage("failed to load an example")
        end
    end
end

function ScriptableComputer:cl_chatMessage(msg)
    --msg = msg:gsub("%[NL%]", "\n")
    --sm.gui.chatMessage("[SComputers]: " .. msg)
    sm.gui.chatMessage(msg)
end

function ScriptableComputer:cl_alertMessage(msg)
    --msg = msg:gsub("%[NL%]", "\n")
    sm.gui.displayAlertText(msg, 4)
end

function ScriptableComputer:cl_logMessage(msg)
    table.insert(self.consoleLog, msg)
    if #self.consoleLog > 150 then
        table.remove(self.consoleLog, 1)
    end
    self:cl_consoleUpdate()
end

function ScriptableComputer:cl_logMessageAfterTrace(msg)
    if not self.currentError then
        self:cl_logMessage(msg)
        return
    end

    table.insert(self.consoleLog_afterTraceback, msg)
    if #self.consoleLog_afterTraceback > 150 then
        table.remove(self.consoleLog_afterTraceback, 1)
    end
    self:cl_consoleUpdate()
end

function ScriptableComputer:cl_internal_alertMessage(msg)
    --msg = msg:gsub("%[NL%]", "\n")
    self:cl_createGUI()
    --self.gui:setText("lastMessage", msg)
    sm.gui.displayAlertText(msg)
    self:cl_logMessageAfterTrace("#008cd6MESSAGE: " .. msg)
end

function ScriptableComputer:cl_setText(code)
    self.last_script = code
    self:cl_rawSetText(code)
end

local lnChar = string.byte("\n")
function ScriptableComputer:cl_updateLinesNumbers()
    local strs = {}
    local linesCount = #self.last_script > 0 and 1 or 0
    for i = 1, #self.last_script do
        if self.last_script:byte(i) == lnChar then
            linesCount = linesCount + 1
        end
    end
    for i = 1, linesCount do
        if self.errorLine == i then
            table.insert(strs, "#ff0000" .. tostring(i))
        else
            table.insert(strs, "#ffffff" .. tostring(i))
        end
    end
    table.insert(strs, "")
    local str = table.concat(strs, "\n")
    self.gui:setText("linesNumbers", str:sub(1, #str - 1))
end

function ScriptableComputer:cl_rawSetText(code)
    self:cl_updateLinesNumbers()

    if self.cStorageData.encryptCode then
        self.gui:setText("ScriptData", formatBeforeGui(code))
        return
    end
    
    if self.cl_architecture then
        if self.cl_architecture.syntaxHighlight then
            self.gui:setText("ScriptData", self.cl_architecture.syntaxHighlight(self, code, self.errorLine))
        else
            self.gui:setText("ScriptData", formatBeforeGui(code))
        end
    else
        self.gui:setText("ScriptData", syntax_make(formatBeforeGui(code), self.errorLine))
    end
end

function ScriptableComputer:cl_externEditor()
    if self.cStorageData.encryptCode then
        self:cl_internal_alertMessage(ScriptableComputer.encryptCode_warn)
        return
    end

    if self.textEditor then
        self.textEditor(true)
        self.textEditor = nil
    end
    
    if better and better.isAvailable() then
        if not self.cl_architecture or self.cl_architecture.editorExtension == "lua" then
            self.textEditor = better.textEditor_lua(self.last_script)
        else
            self.textEditor = better.textEditor_txt(self.last_script)
        end
    else
        self:cl_internal_alertMessage("for the external editor, you need a betterAPI")
    end
end

function ScriptableComputer:cl_ai()
    if self.cStorageData.encryptCode then
        self:cl_internal_alertMessage(ScriptableComputer.encryptCode_warn)
        return
    end
    
    if self.aiGen then return end
    if ai_codeGen then
        if #self.last_script > ScriptableComputer.maxPromptsize then
            self:cl_internal_alertMessage("the maximum prompt size is 16KB")
        else
            self:cl_internal_alertMessage("please wait...")
            self.aiGen = ai_codeGen(self.last_script)
        end
    else
        self:cl_internal_alertMessage("for the AI code-gen to work, you need a betterAPI")
    end
end

function ScriptableComputer:cl_accept(text, func)
    self.acceptMessage = nil
    if not self.acceptGui then
        self.acceptGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PopUp_YN.layout", false)
        self.acceptGui:setButtonCallback("Yes", "cl_g_accept")
        self.acceptGui:setButtonCallback("No", "cl_g_naccept")
    end
    self.acceptGui:setText("Title", "confirmation action")
    self.acceptGui:setText("Message", text)
    self.acceptGui:open()
    self:cl_closeGui()
    self.acceptFunction = func
end

function ScriptableComputer:cl_messageAccept(text, func)
    self.acceptMessage = ""
    if not self.messageAcceptGui then
        self.messageAcceptGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PopUp_YNM.layout", false)
        self.messageAcceptGui:setTextChangedCallback("UserMessage", "cl_g_message")
        self.messageAcceptGui:setButtonCallback("Yes", "cl_g_message_accept")
        self.messageAcceptGui:setButtonCallback("No", "cl_g_message_naccept")
    end
    self.messageAcceptGui:setText("Title", "confirmation action")
    self.messageAcceptGui:setText("Message", text)
    self.messageAcceptGui:setText("UserMessage", "")
    self.messageAcceptGui:open()
    self:cl_closeGui()
    self.acceptFunction = func
end

function ScriptableComputer:cl_g_message(_, text)
    self.acceptMessage = text
end

function ScriptableComputer:cl_g_message_accept()
    self.acceptFunction(self.acceptMessage)
    self.messageAcceptGui:close()
    self.openTimer = 2
end

function ScriptableComputer:cl_g_message_naccept()
    self.messageAcceptGui:close()
    self.openTimer = 2
end

function ScriptableComputer:cl_g_accept()
    self.acceptFunction()
    self.acceptGui:close()
    self.openTimer = 2
end

function ScriptableComputer:cl_g_naccept()
    self.acceptGui:close()
    self.openTimer = 2
end

function ScriptableComputer:cl_saveAccept()
    if self.cStorageData.encryptCode then
        return
    end
    if not self.saveAcceptGui then
        self.saveAcceptGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/PopUp_YNC.layout", false)
        self.saveAcceptGui:setButtonCallback("Yes", "cl_g_saveAccept_Yes")
        self.saveAcceptGui:setButtonCallback("No", "cl_g_saveAccept_No")
        self.saveAcceptGui:setButtonCallback("Cancel", "cl_g_saveAccept_Cancel")
    end
    self.saveAcceptGui:setText("Title", "save changes?")
    self.saveAcceptGui:setText("Message", "you are trying to close the code editor, but you have unsaved changes")
    self.saveAcceptGui:open()
    self:cl_closeGui()
end

function ScriptableComputer:cl_g_saveAccept_Yes()
    self:cl_realSave()
    self.saveAcceptGui:close()
    self.saveAcceptGui:destroy()
    self.saveAcceptGui = nil
end

function ScriptableComputer:cl_g_saveAccept_No()
    self.saveAcceptGui:close()
    self.saveAcceptGui:destroy()
    self.saveAcceptGui = nil
end

function ScriptableComputer:cl_g_saveAccept_Cancel()
    self.saveAcceptGui:close()
    self.saveAcceptGui:destroy()
    self.saveAcceptGui = nil
    self.openTimer = 2
end