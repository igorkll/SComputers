dofile("$CONTENT_DATA/Scripts/Config.lua")
synthesizer = class()
synthesizer.maxParentCount = 1
synthesizer.maxChildCount = 0
synthesizer.connectionInput = sm.interactable.connectionType.composite
synthesizer.colorNormal = sm.color.new(   0x006e93ff)
synthesizer.colorHighlight = sm.color.new(0x00beffff)
synthesizer.poseWeightCount = 1
synthesizer.componentType = "synthesizer"
synthesizer.minBetterAPI = 44

local _, defaultSamplesList = pcall(sm.json.open, "$CONTENT_DATA/ROM/defaultSamples/list.json")
if type(defaultSamplesList) ~= "table" then
    defaultSamplesList = {}
end
sc.changePrefixesInList(defaultSamplesList)

local maxBeeps = 32
local maxLoops = 32
local maxSamples = 32

local loopsList = {"chapter2_alarm", "elevator_music", "GasEngine - Scrap"}
for i = 1, 5 do
    table.insert(loopsList, "ElectricEngine - Level " .. i)
    table.insert(loopsList, "GasEngine - Level " .. i)
end

local function checkNum(self, num)
    if self.unrestricted then return end
    if num < 1 or num > maxLoops or num % 1 ~= 0 then
        error("invalid cycle number", 3)
    end
end

local function checkSampleNum(self, num)
    if self.unrestricted then return end
    if num < 1 or num > maxSamples or num % 1 ~= 0 then
        error("invalid samples number", 3)
    end
end

--[[
local function formatParams(data)
    local tbl = {}
    tbl.load = data.load
    tbl.rpm = data.rpm
    tbl.gas = data.gas
    if type(tbl.load) ~= "number" then tbl.load = nil end
    if type(tbl.rpm) ~= "number" then tbl.rpm = nil end
    if type(tbl.gas) ~= "number" then tbl.gas = nil end
    return tbl
end
]]

local function tableInsert(tbl, dat)
    for i = 1, math.huge do
        if not tbl[i] then
            tbl[i] = dat
            return i
        end
    end
end

local function soundId()
    return math.random(-2147483648, 2147483647)
end

local function getSettings()
    return {
        samplesDistance = 25,
        spatialEnabled = true,
        localSound = false
    }
end

local function unrestrictedOnly(self)
    if not self.unrestricted then
        error("this method is intended only for unrestricted speaker from the power toys addon", 3)
    end
end

function synthesizer:server_onCreate()
    self.loopData = {}
    self.flushLoops = true

    if self.data and self.data.unrestricted then
        self.unrestricted = true
    end

    self.sv_settings = getSettings()
    self.updateSettings = true

    local api
    api = {
        -- new sound api
        hornBeep = function(pitch, duration)
            checkArg(1, pitch, "number")
            checkArg(2, duration, "number", "nil")

            if pitch < 0 then pitch = 0 end
            if pitch > 1 then pitch = 1 end

            if duration then
                if duration < 0 then duration = 0 end
                duration = math.floor(duration)
            end

            if not self.newBeeps then self.newBeeps = {} end
            local id = soundId()
            if #self.newBeeps < maxBeeps or self.unrestricted then
                table.insert(self.newBeeps, {0, id, 0, pitch, duration})
            end
            return id
        end,
        ballBeep = function(velocity, duration)
            checkArg(1, velocity, "number")
            checkArg(2, duration, "number", "nil")

            if duration then
                if duration < 0 then duration = 0 end
                duration = math.floor(duration)
            end

            if not self.newBeeps then self.newBeeps = {} end
            local id = soundId()
            if #self.newBeeps < maxBeeps or self.unrestricted then
                table.insert(self.newBeeps, {0, id, 10, velocity, duration})
            end
            return id
        end,
        toteBeep = function(device, note, duration)
            checkArg(1, device, "number")
            checkArg(2, note, "number")
            checkArg(3, duration, "number", "nil")

            if note < 0 then note = 0 end
            if note > 24 then note = 24 end

            if duration then
                if duration < 0 then duration = 0 end
                duration = math.floor(duration)
            end

            if not self.newBeeps then self.newBeeps = {} end
            local id = soundId()
            if #self.newBeeps < maxBeeps or self.unrestricted then
                local pitch
                if device == 10 then
                    pitch = (note + 1) * 2
                else
                    pitch = note / 24
                end
                table.insert(self.newBeeps, {0, id, device, pitch, duration})
            end
            return id
        end,
        sampleBeep = function(sample, volume, speed, pitch, rate, startpos, endpos)
            checkArg(1, sample, "number")
            checkArg(2, volume, "number", "nil")
            checkArg(3, speed, "number", "nil")
            checkArg(4, pitch, "number", "nil")
            checkArg(5, rate, "number", "nil")
            checkArg(6, startpos, "number", "nil")
            checkArg(7, endpos, "number", "nil")

            if not self.newBeeps then self.newBeeps = {} end
            local id = soundId()
            if #self.newBeeps < maxBeeps or self.unrestricted then
                if volume < 0 then volume = 0 end
                if volume > 3 and not self.unrestricted then volume = 3 end
                table.insert(self.newBeeps, {1, id, sample, volume or 1, speed or 1, pitch or 0, rate or 1, startpos or 0, endpos or math.huge})
            end
            return id
        end,
        alarmBeep = function(index)
            checkArg(1, index, "number")

            if not self.newBeeps then self.newBeeps = {} end
            local id = soundId()
            if #self.newBeeps < maxBeeps or self.unrestricted then
                table.insert(self.newBeeps, {2, id, index})
            end
            return id
        end,
        waveBeep = function(wave, volume, freq, duration)
            checkArg(1, wave, "number", "nil")
            checkArg(2, volume, "number", "nil")
            checkArg(3, freq, "number", "nil")
            checkArg(4, duration, "number", "nil")

            if not self.newBeeps then self.newBeeps = {} end
            local id = soundId()
            if #self.newBeeps < maxBeeps or self.unrestricted then
                table.insert(self.newBeeps, {3, id, wave or 0, volume or 1, freq or 1000, duration or math.huge})
            end
            return id
        end,
        stopBeep = function(id)
            checkArg(1, id, "number")

            if not self.newBeepsStop then self.newBeepsStop = {} end
            self.newBeepsStop[id] = true
        end,

        -- sound api
        clear = function ()
            self.beeps = nil
        end,
        flush = function ()
            self.flushFlag = true
        end,
        flushWithStop = function ()
            if not self.beeps then self.beeps = {} end
            self.flushFlag = true
            self.stopOther = true
        end,
        flushWithBind = function()
            if not self.beeps then self.beeps = {} end
            self.flushFlag = true
            self.bindOther = true
        end,
        delBeep = function (index)
            if self.beeps then
                self.beeps[index] = nil
            end
        end,
        addBeep = function (device, pitch, volume, duration)
            checkArg(1, device, "number", "nil")
            checkArg(2, pitch, "number", "nil")
            checkArg(3, volume, "number", "nil")
            checkArg(4, duration, "number", "nil")

            if not self.beeps then self.beeps = {} end
            if #self.beeps < maxBeeps or self.unrestricted then
                return tableInsert(self.beeps, {
                    device,
                    pitch,
                    volume,
                    duration
                })
            end
        end,
        stop = function ()
            self.stopFlag = true
        end,

        -- loop api
        getMaxLoopsCount = function()
            return maxLoops
        end,
        getLoopsWhilelist = function()
            return sc.advDeepcopy(loopsList)
        end,
        startLoop = function(number, loopname, params)
            checkArg(1, number, "number")
            checkArg(2, loopname, "string")
            checkArg(3, params, "table", "nil")
            checkNum(self, number)
            for i, v in ipairs(loopsList) do
                if v == loopname then
                    self.loopData[number] = {loopname, params}
                    self.flushLoops = true
                    return
                end
            end
            error("unknown loop effect", 2)
        end,
        stopLoop = function(number)
            checkArg(1, number, "number")
            checkNum(self, number)
            self.loopData[number] = nil
            self.flushLoops = true
        end,
        stopLoops = function()
            self.loopData = {}
            self.flushLoops = true
        end,
        setLoopParams = function(number, params)
            checkArg(1, number, "number")
            checkArg(2, params, "table")
            checkNum(self, number)
            if not self.loopData[number] then
                error("the loop effect number " .. math.floor(number) .. " is not running", 2)
            end
            self.loopData[number][2] = params
            if not self.flushParams then self.flushParams = {} end
            self.flushParams[number] = params
        end,

        -- sample api
        getMaxSamplesCount = function()
            return maxSamples
        end,
        getDefaultSamplesList = function()
            local list = {}
            for k, v in pairs(defaultSamplesList) do
                table.insert(list, k)
            end
            table.sort(list)
            return list
        end,
        stopSamples = function()
            self.stopAllSamples = true
        end,
        loadSampleFromTTS = function(slot, text)
            checkArg(1, slot, "number")
            checkArg(2, text, "string")
            checkSampleNum(self, slot)
            
            if not self.loadSamples then
                self.loadSamples = {}
            end

            self.loadSamples[slot] = {"tts", sm.game.getCurrentTick(), text}

            if self.samplesParams then
                self.samplesParams[slot] = nil
                self.sendSampleParams = true
            end
        end,
        loadSampleFromURL = function(slot, url)
            checkArg(1, slot, "number")
            checkArg(2, url, "string")
            checkSampleNum(self, slot)
            
            if not self.loadSamples then
                self.loadSamples = {}
            end

            self.loadSamples[slot] = {"url", sm.game.getCurrentTick(), url}

            if self.samplesParams then
                self.samplesParams[slot] = nil
                self.sendSampleParams = true
            end
        end,
        loadSampleFromBlueprint = function(slot, uuid, steamid, filename)
            checkArg(1, slot, "number")
            checkArg(2, uuid, "string")
            checkArg(3, steamid, "string", "nil")
            checkArg(4, filename, "string")

            if not self.loadSamples then
                self.loadSamples = {}
            end

            self.loadSamples[slot] = {"blueprint", sm.game.getCurrentTick(), uuid, steamid, filename}

            if self.samplesParams then
                self.samplesParams[slot] = nil
                self.sendSampleParams = true
            end
        end,
        loadSampleFromSComputers = function(slot, name)
            checkArg(1, slot, "number")
            checkArg(2, name, "string")

            if not self.loadSamples then
                self.loadSamples = {}
            end

            self.loadSamples[slot] = {"file", sm.game.getCurrentTick(), defaultSamplesList[name] or error("there is no sample with this name", 2)}

            if self.samplesParams then
                self.samplesParams[slot] = nil
                self.sendSampleParams = true
            end
        end,
        startSample = function(slot)
            checkArg(1, slot, "number")
            checkSampleNum(self, slot)

            if not self.samplesActions then
                self.samplesActions = {}
            end

            if not self.samplesActions[slot] then
                self.samplesActions[slot] = {}
            end

            table.insert(self.samplesActions[slot], 1)
        end,
        stopSample = function(slot)
            checkArg(1, slot, "number")
            checkSampleNum(self, slot)

            if not self.samplesActions then
                self.samplesActions = {}
            end

            if not self.samplesActions[slot] then
                self.samplesActions[slot] = {}
            end

            table.insert(self.samplesActions[slot], 2)
        end,
        pauseSample = function(slot)
            checkArg(1, slot, "number")
            checkSampleNum(self, slot)

            if not self.samplesActions then
                self.samplesActions = {}
            end

            if not self.samplesActions[slot] then
                self.samplesActions[slot] = {}
            end

            table.insert(self.samplesActions[slot], 3)
        end,
        loopSample = function(slot, state)
            checkArg(1, slot, "number")
            checkArg(2, state, "boolean")
            checkSampleNum(self, slot)

            if not self.samplesActions then
                self.samplesActions = {}
            end

            if not self.samplesActions[slot] then
                self.samplesActions[slot] = {}
            end

            table.insert(self.samplesActions[slot], state and 4 or 5)
        end,
        setSampleVolume = function(slot, volume)
            checkArg(1, slot, "number")
            checkArg(2, volume, "number")
            checkSampleNum(self, slot)

            if not self.samplesParams then
                self.samplesParams = {}
            end

            if not self.samplesParams[slot] then
                self.samplesParams[slot] = {}
            end

            if volume < 0 then volume = 0 end
            if volume > 3 and not self.unrestricted then volume = 3 end
            self.samplesParams[slot].volume = volume
            self.sendSampleParams = true
        end,
        setSampleRate = function(slot, rate)
            checkArg(1, slot, "number")
            checkArg(2, rate, "number")
            checkSampleNum(self, slot)

            if not self.samplesParams then
                self.samplesParams = {}
            end

            if not self.samplesParams[slot] then
                self.samplesParams[slot] = {}
            end

            self.samplesParams[slot].rate = rate
            self.sendSampleParams = true
        end,
        setSamplePitch = function(slot, pitch)
            checkArg(1, slot, "number")
            checkArg(2, pitch, "number")
            checkSampleNum(self, slot)

            if not self.samplesParams then
                self.samplesParams = {}
            end

            if not self.samplesParams[slot] then
                self.samplesParams[slot] = {}
            end

            self.samplesParams[slot].pitch = pitch
            self.sendSampleParams = true
        end,
        setSampleSpeed = function(slot, speed)
            checkArg(1, slot, "number")
            checkArg(2, speed, "number")
            checkSampleNum(self, slot)

            if not self.samplesParams then
                self.samplesParams = {}
            end

            if not self.samplesParams[slot] then
                self.samplesParams[slot] = {}
            end

            self.samplesParams[slot].speed = speed
            self.sendSampleParams = true
        end,


        setSampleDistance = function(distance)
            unrestrictedOnly(self)
            checkArg(1, distance, "number")
            self.sv_settings.samplesDistance = distance
            self.updateSettings = true
        end,
        getSampleDistance = function()
            return self.sv_settings.samplesDistance
        end,

        setSpatialEnabled = function(spatialEnabled)
            unrestrictedOnly(self)
            checkArg(1, spatialEnabled, "boolean")
            self.sv_settings.spatialEnabled = spatialEnabled
            self.updateSettings = true
        end,
        getSpatialEnabled = function()
            return self.sv_settings.spatialEnabled
        end,

        setLocalSound = function(localSound)
            unrestrictedOnly(self)
            checkArg(1, localSound, "boolean")
            self.sv_settings.localSound = localSound
            self.updateSettings = true
        end,
        getLocalSound = function()
            return self.sv_settings.localSound
        end
    }
    api.getLoopsCount = api.getMaxLoopsCount

    sc.synthesizerDatas[self.interactable.id] = api
end

function synthesizer:server_onDestroy()
    sc.synthesizerDatas[self.interactable.id] = nil
end

function synthesizer:server_onFixedUpdate()
    if self.updateSettings then
        self.network:sendToClients("cl_updateSettings", self.sv_settings)
        self.updateSettings = nil
    end

    if self.stopFlag then
        self.network:sendToClients("cl_stop")
        self.stopFlag = nil
    end
    
    if self.flushFlag then
        if self.beeps then
            self.beeps.stopOther = self.stopOther
            self.beeps.bindOther = self.bindOther
            self.network:sendToClients("cl_upload", self.beeps)
        end

        self.flushFlag = nil
        self.stopOther = nil
        self.bindOther = nil
    end

    if self.flushLoops then
        self:sv_flushLoops()
        self.flushLoops = nil
    end

    if self.flushParams then
        self.network:sendToClients("cl_flushParams", self.flushParams)
        self.flushParams = nil
    end

    if self.loadSamples then
        self.network:sendToClients("cl_loadSamples", self.loadSamples)
        self.loadSamples = nil
    end

    if self.sendSampleParams then
        self.network:sendToClients("cl_samplesParams", self.samplesParams)
        self.sendSampleParams = nil
    end

    if self.samplesActions then
        self.network:sendToClients("cl_samplesActions", self.samplesActions)
        self.samplesActions = nil
    end

    if self.newBeeps then
        if self.newBeepsStop then
            for i = #self.newBeeps, 1, -1 do
                local newBeep = self.newBeeps[i]
                local id = newBeep[2]
                if self.newBeepsStop[id] then
                    table.remove(self.newBeeps, i)
                    self.newBeepsStop[id] = nil
                end
            end
        end

        self.network:sendToClients("cl_newBeeps", self.newBeeps)
        self.newBeeps = nil
    end

    if self.newBeepsStop then
        for _ in pairs(self.newBeepsStop) do --i only send it if the table is not empty
            self.network:sendToClients("cl_newBeepsStop", self.newBeepsStop)
            break
        end
        self.newBeepsStop = nil
    end

    if self.stopAllSamples then
        self.network:sendToClients("cl_stopAllSamples")
        self.stopAllSamples = nil
    end
end

function synthesizer:sv_flushLoops(_, caller)
    if caller then
        self.network:sendToClient(caller, "cl_flushLoops", self.loopData)
        if self.samplesParams then
            self.network:sendToClient(caller, "cl_samplesParams", self.samplesParams)
        end
    else
        self.network:sendToClients("cl_flushLoops", self.loopData)
        if self.samplesParams then
            self.network:sendToClients("cl_samplesParams", self.samplesParams)
        end
    end
end

function synthesizer:sv_dataRequest()
    self.updateSettings = true
    self:sv_flushLoops()
end




function synthesizer:client_onCreate()
    if self.data and self.data.unrestricted then
        self.unrestricted = true
    end

    self.cl_settings = getSettings()
    self.effects = {}
    self.effectsCache = {}
    self.currentLoops = {}
    self.oldEffectsName = {}
    self.loadedSamples = {}
    self._loadedSamples = {}
    self.runnedSamplesInfo = {}
    self.runnedSamplesData = {}
    self.loopSamplesData = {}
    self.paramsSamplesData = {}
    self.newBeepsEffects = {}
    self.destroyDelay = {}
    if better and better.audio.createFromFile then
        self.defaultWaves = {
            better.audio.createFromFile(defaultSamplesList.wave_sine),
            better.audio.createFromFile(defaultSamplesList.wave_square),
            better.audio.createFromFile(defaultSamplesList.wave_sawtooth),
            better.audio.createFromFile(defaultSamplesList.wave_triangle)
        }
    else
        self.defaultWaves = {}
    end
    --self.network:sendToServer("sv_flushLoops")
    self.network:sendToServer("sv_dataRequest")
end

function synthesizer:cl_updateSettings(settings)
    self.cl_settings = settings
end

function synthesizer:cl_newBeepsStop(newBeepsStop)
    for i = #self.newBeepsEffects, 1, -1 do
        local effectData = self.newBeepsEffects[i]
        if not newBeepsStop or newBeepsStop[effectData.id] then
            if effectData.type == 0 then
                effectData.effect:stop()
                effectData.effect:destroy()
                table.remove(self.newBeepsEffects, i)
            elseif effectData.type == 1 then
                effectData.audio:destroy()
                table.remove(self.newBeepsEffects, i)
            end
        end
    end
end

function synthesizer:createEffect(name)
    local obj
    if self.cl_settings.localSound then
        obj = sm.localPlayer.getPlayer().character
    else
        obj = self.interactable
    end
    return sm.effect.createEffect(name, obj)
end

function synthesizer:cl_newBeeps(newBeeps)
    for _, newBeep in ipairs(newBeeps) do
        if #self.newBeepsEffects >= maxBeeps then
            break
        end

        local effectData = {}
        local effectValid = false
        if newBeep[1] == 0 then
            effectData.type = 0
            effectData.timer = newBeep[5] or math.huge
            effectData.id = newBeep[2]

            if newBeep[3] == 0 then
                effectData.effect = self:createEffect("Horn - Honk")
            else
                effectData.effect = self:createEffect(sc.getSoundEffectName("tote" .. newBeep[3]))
            end

            effectData.effect:setParameter(newBeep[3] == 10 and "velocity_max_50" or "pitch", newBeep[4])
            effectData.effect:start()

            effectValid = true
        elseif newBeep[1] == 1 then
            effectData.type = 1
            effectData.id = newBeep[2]
            effectData.deadline = newBeep[9]

            local baseAudio = self.loadedSamples[newBeep[3]]
            if baseAudio and better and better.audio.fork then
                effectData.audio = baseAudio:fork()
                if effectData.audio then
                    effectData.audio:setVolume(newBeep[4])
                    effectData.audio:setPitch(newBeep[6])
                    effectData.audio:setSpeed(newBeep[5])
                    effectData.audio:setRate(newBeep[7])
                    if newBeep[8] ~= 0 then
                        effectData.audio:setPosition(newBeep[8])
                    end
                    self:cl_updateSpatialSound(effectData.audio)
                    effectData.audio:start()
                    effectValid = true
                end
            end
        elseif newBeep[1] == 2 then
            effectData.type = 0
            effectData.timer = math.huge
            effectData.id = newBeep[2]
            effectData.effect = self:createEffect("chapter2_alarm")
            effectData.effect:setParameter("alarm", newBeep[3])
            effectData.effect:start()
            effectValid = true
        elseif newBeep[1] == 3 then
            effectData.type = 1
            effectData.id = newBeep[2]
            effectData.timer = newBeep[6]
            effectData.volume = newBeep[4]

            local baseAudio = self.defaultWaves[newBeep[3] + 1]
            if baseAudio and better and better.audio.fork then
                effectData.audio = baseAudio:fork()
                if effectData.audio then
                    effectData.audio:setSpeed(newBeep[5] / 1000)
                    effectData.audio:setLoop(true)
                    self:cl_updateSpatialSound(effectData.audio)
                    effectData.audio:start()
                    effectValid = true
                end
            end
        end

        if effectValid then
            table.insert(self.newBeepsEffects, effectData)
        end
    end
end

function synthesizer:cl_loadSamples(loadSamples)
    if not better or better.version < synthesizer.minBetterAPI then
        return
    end
    
    for slot, loadAction in pairs(loadSamples) do
        if self._loadedSamples[slot] ~= loadAction[2] then
            self._loadedSamples[slot] = nil

            if self.loadedSamples[slot] then
                self.loadedSamples[slot]:destroy()
                self.loadedSamples[slot] = nil
            end

            self.paramsSamplesData[slot] = {}
            self.runnedSamplesInfo[slot] = nil
            self.runnedSamplesData[slot] = nil
            self.loopSamplesData[slot] = nil

            local ok, audioOrErr = false, nil
            if loadAction[1] == "url" then
                ok, audioOrErr = pcall(better.audio.createFromUrl, loadAction[3])
                if not ok then
                    print("error in better.audio.createFromFile (load from url): ", audioOrErr)
                end
            elseif loadAction[1] == "tts" then
                ok = true
                audioOrErr = better.tts.textToSpeech(loadAction[3])
            elseif loadAction[1] == "blueprint" then
                ok, audioOrErr = pcall(better.registrationBlueprint, loadAction[3], loadAction[4])
                if ok then
                    ok, audioOrErr = pcall(better.audio.createFromFile, "$CONTENT_" .. loadAction[3] .. "/" .. loadAction[5])
                    if not ok then
                        print("error in better.audio.createFromFile (load from blueprint): ", audioOrErr)
                    end
                else
                    print("error in better.registrationBlueprint: ", audioOrErr)
                end
            elseif loadAction[1] == "file" then
                ok, audioOrErr = pcall(better.audio.createFromFile, loadAction[3])
            end

            if ok then
                audioOrErr:update()
                self.loadedSamples[slot] = audioOrErr
                self._loadedSamples[slot] = loadAction[2]
            end
        end
    end
end

function synthesizer:cl_updateSpatialSound(audio)
    local dir
    if self.cl_settings.spatialEnabled then
        dir = sm.camera.getDirection()
    end
    audio:updateSpatialSound(sm.camera.getPosition(), {{self.shape.worldPosition, self.cl_settings.samplesDistance}}, dir)
end

function synthesizer:cl_applySampleParameters(slot)
    if self.runnedSamplesData[slot] then
        local params = self.paramsSamplesData[slot]
        local audio = self.loadedSamples[slot]
        audio:setVolume(params.volume or 1)
        if better.audio.setSpeed then
            audio:setSpeed(params.speed or 1)
        end
        if better.audio.setRate then
            audio:setRate(params.rate or 1)
        end
        if better.audio.setPitch then
            audio:setPitch(params.pitch or 0)
        end
        self:cl_updateSpatialSound(audio)
        audio:update()
    end
end

function synthesizer:cl_samplesActions(samplesActions)
    for slot, actions in pairs(samplesActions) do
        local audio = self.loadedSamples[slot]
        if audio then
            for _, action in ipairs(actions) do
                if action == 1 then
                    self.runnedSamplesInfo[slot] = 80
                    self.runnedSamplesData[slot] = true
                    self:cl_applySampleParameters(slot)
                    audio:start()
                elseif action == 2 then
                    audio:stop()
                    self.runnedSamplesInfo[slot] = nil
                    self.runnedSamplesData[slot] = false
                elseif action == 3 then
                    audio:pause()
                    self.runnedSamplesInfo[slot] = nil
                    self.runnedSamplesData[slot] = false
                elseif action == 4 then
                    audio:setLoop(true)
                    self.loopSamplesData[slot] = true
                elseif action == 5 then
                    audio:setLoop(false)
                    self.loopSamplesData[slot] = false
                end
            end
        end
    end
end

function synthesizer:cl_samplesParams(samplesParams)
    for slot, params in pairs(samplesParams) do
        for k, v in pairs(params) do
            if not self.paramsSamplesData[slot] then
                self.paramsSamplesData[slot] = {}
            end
            self.paramsSamplesData[slot][k] = v 
        end
    end
end

function synthesizer:cl_stopAllSamples()
    for slot = 1, maxSamples do
        local audio = self.loadedSamples[slot]
        if audio then
            audio:stop()
            self.runnedSamplesInfo[slot] = nil
            self.runnedSamplesData[slot] = false
        end
    end
end

function synthesizer:client_onDestroy()
    for _, data in ipairs(self.effects) do
        for i, v in ipairs(data.effects) do
            v:stop()
            v:destroy()
        end
    end

    self:cl_newBeepsStop()

    for _, effect in pairs(self.currentLoops) do
        effect:destroy()
    end

    for _, audio in pairs(self.loadedSamples) do
        audio:destroy()
    end
end

function synthesizer:cl_flushParams(data)
    for i, ldat in pairs(data) do
        if self.currentLoops[i] then
            for k, v in pairs(ldat) do
                self.currentLoops[i]:setParameter(k, v)
            end
        end
    end
end

function synthesizer:cl_flushLoops(data)
    local alt = {}
    for i, effect in pairs(self.currentLoops) do
        if not data[i] or self.oldEffectsName[i] ~= data[i][1] then
            effect:destroy()
            self.currentLoops[i] = nil
            self.oldEffectsName[i] = nil
        else
            alt[i] = effect
        end
    end

    for i, ldat in pairs(data) do
        local effect = alt[i] or self:createEffect(ldat[1])
        for k, v in pairs(ldat[2] or {}) do
            effect:setParameter(k, v)
        end
        if effect:isDone() then
            effect:setAutoPlay(true)
            effect:start()
        end
        self.currentLoops[i] = effect
        self.oldEffectsName[i] = ldat[1]
    end
end

function synthesizer:client_onFixedUpdate()
    if better then
        better.tick()
    end

    local num = (#self.effects > 0 or #self.newBeepsEffects > 0) and 1 or 0
    if num == 0 then
        for _, effect in pairs(self.currentLoops) do
            num = 1
            break
        end
    end

    for k, v in pairs(self.runnedSamplesInfo) do
        num = 1
        self.runnedSamplesInfo[k] = self.runnedSamplesInfo[k] - 1
        if self.runnedSamplesInfo[k] <= 0 then
            self.runnedSamplesInfo[k] = nil
        end
    end

    if num == 0 and better and better.audio and better.audio.getState then
        for _, audio in pairs(self.loadedSamples) do
            local playState = audio:getState()
            if playState == 1 or playState == 3 then
                num = 1
            end
        end
    end

    --[[
    if num == 0 then
        for k, v in pairs(self.loopSamplesData) do
            if v then
                num = 1
                break
            end
        end
    end
    ]]

    local ctick = sm.game.getCurrentTick()
    for audio, deadline in pairs(self.destroyDelay) do
        if ctick > deadline then
            audio:destroy()
            self.destroyDelay[audio]= nil 
        end
    end

    for i = #self.newBeepsEffects, 1, -1 do
        num = 1
        local effectData = self.newBeepsEffects[i]
        if effectData.type == 0 then
            effectData.timer = effectData.timer - 1
            if effectData.timer < 0 or not effectData.effect:isPlaying() then
                effectData.effect:stop()
                effectData.effect:destroy()
                table.remove(self.newBeepsEffects, i)
            end
        elseif effectData.type == 1 then
            local playState = effectData.audio:getState()
            if (effectData.deadline and effectData.audio:getPosition() >= effectData.deadline) or (playState ~= 1 and playState ~= 3) then
                effectData.audio:destroy()
                table.remove(self.newBeepsEffects, i)
            else
                self:cl_updateSpatialSound(effectData.audio)
                if effectData.volume then
                    effectData.audio:setVolume(effectData.volume)
                    effectData.audio:update()
                end
                if effectData.timer then
                    effectData.timer = effectData.timer - 1
                    if effectData.timer < 0 then
                        effectData.audio:setVolume(0)
                        self.destroyDelay[effectData.audio] = ctick + 5
                        table.remove(self.newBeepsEffects, i)
                    end
                end
            end
        end
    end

    if better and better.audio then
        for slot in pairs(self.loadedSamples) do
            self:cl_applySampleParameters(slot)
        end
    end

    for i = #self.effects, 1, -1 do
        local data = self.effects[i]
        if data[4] then
            if data[4] <= 0 then
                for i, v in ipairs(data.effects) do
                    if sm.exists(v) then
                        v:stop()
                        table.insert(self.effectsCache[data[1]], v)
                    end
                end
                table.remove(self.effects, i)
            end
            data[4] = data[4] - 1
        elseif not data.effects[1]:isPlaying() then
            for i, v in ipairs(data.effects) do
                if sm.exists(v) then
                    v:stop()
                    table.insert(self.effectsCache[data[1]], v)
                end
            end
            table.remove(self.effects, i)
        end
    end

    if not self.pose then self.pose = 0 end
    self.pose = self.pose + ((num - self.pose) * 0.3)
    self.interactable:setPoseWeight(0, sm.util.clamp(self.pose, 0.01, 0.7))
end

function synthesizer:cl_stop()
    for _, data in ipairs(self.effects) do
        for i, v in ipairs(data.effects) do
            v:stop()
            table.insert(self.effectsCache[data[1]], v)
        end
    end
    self.effects = {}

    self:cl_newBeepsStop()
end

function synthesizer:cl_upload(datas)
    local stopList = {}

    if datas.stopOther then
        for _, data in ipairs(self.effects) do
            for i, v in ipairs(data.effects) do
                stopList[v.id] = v
                table.insert(self.effectsCache[data[1]], v)
            end
        end
        self.effects = {}
    elseif datas.bindOther then
        for _, data in pairs(datas) do
            if type(data) == "table" then
                for i = #self.effects, 1, -1 do
                    local data2 = self.effects[i]
                    if data2[1] == data[1] then
                        for i, v in ipairs(data2.effects) do
                            stopList[v.id] = v
                            table.insert(self.effectsCache[data2[1]], v)
                        end
                        table.remove(self.effects, i)
                    end
                end
            end
        end
    end

    for _, data in pairs(datas) do
        if type(data) == "table" then
            data[1] = data[1] or 0

            if not self.effectsCache[data[1]] then
                self.effectsCache[data[1]] = {}
            end

            if not data.effects then
                data.effects = {}
            end

            for i = 1, math.floor(sm.util.clamp((data[3] or 0.1) * 10, 0, 10) + 0.5) do
                local effect
                if self.effectsCache[data[1]] and #self.effectsCache[data[1]] > 0 then
                    effect = table.remove(self.effectsCache[data[1]])
                else
                    if data[1] == 0 then
                        effect = self:createEffect("Horn - Honk")
                    else
                        effect = self:createEffect(sc.getSoundEffectName("tote" .. data[1]))
                    end
                end
                
                if effect then
                    effect:setParameter("pitch", data[2] or 0.5)
                    if not effect:isPlaying() then
                        effect:start()
                    end
                    
                    stopList[effect.id] = nil
                    table.insert(data.effects, effect)
                end
            end

            table.insert(self.effects, data)
        end
    end

    for id, effect in pairs(stopList) do
        effect:stop()
    end
end