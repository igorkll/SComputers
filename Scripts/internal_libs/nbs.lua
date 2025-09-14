local defaultNoteShift = -39
local defaultInstrument = 4

local function parseNBS(handle)
    local function readInteger(handle)
        local buffer = handle:read(4)

        -- We dont deal with garbage
        if buffer == nil or #buffer < 4 then
            return nil
        end

        local bytes = {}
        bytes[1] = string.byte(buffer, 1)
        bytes[2] = string.byte(buffer, 2)
        bytes[3] = string.byte(buffer, 3)
        bytes[4] = string.byte(buffer, 4)

        local num = bytes[1] + bit.lshift(bytes[2], 8) + bit.lshift(bytes[3], 16) + bit.lshift(bytes[4], 24)
        return num
    end

    local function readShort(handle)
        local buffer = handle:read(2)

        if buffer == nil or #buffer < 2 then
            return nil
        end

        local bytes = {}
        bytes[1] = string.byte(buffer, 1)
        bytes[2] = string.byte(buffer, 2)

        local num = bytes[1] + bit.lshift(bytes[2], 8)
        return num
    end

    local function readByte(handle)
        local buffer = handle:read(1)

        if buffer == nil then
            return nil
        end

        return string.byte(buffer, 1)
    end

    local function readString(handle)
        local length = readInteger(handle)
        local txt = handle:read(length)
        return txt
    end

    local div = 1

    local song = {}
    song["length"] = readShort(handle)
    local newFormat = song["length"] == 0
    if newFormat then
        song["version"] = readByte(handle)
        song["vic"] = readByte(handle)
        song["song_length"] = readShort(handle)
        song["layer_count"] = readShort(handle)
        song["name"] = readString(handle)
        song["author"] = readString(handle)
        song["ogauthor"] = readString(handle)
        song["desc"] = readString(handle)
        song["tempo"] = readShort(handle)

        for i=1,3 do readByte(handle) end
        for i=1,5 do readInteger(handle) end
        readString(handle)
        for i=1,3 do readByte(handle) end

        div = 256
    else
        song["height"] = readShort(handle)
        song["name"] = readString(handle)
        song["author"] = readString(handle)
        song["ogauthor"] = readString(handle)
        song["desc"] = readString(handle)
        song["tempo"] = readShort(handle)
    
        for i=1,3 do readByte(handle) end
        for i=1,5 do readInteger(handle) end
        readString(handle)
    end

    local frame = math.floor(1000 / (song["tempo"] / 100))
    local sleep = frame / 1000

    local ticks = {}
    local currenttick = -1

    while true do
        local step = readShort(handle)
        if step == 0 then
            break
        end

        currenttick = currenttick + step
        local currenttickIndex = math.floor(currenttick / div)
        ticks[currenttickIndex] = {}

        local lpos = 1
        if newFormat then
            while true do
                local jump = readShort(handle)
                if jump == 0 then
                    break
                end

                readByte(handle)
                local inst = readByte(handle)
                local note = readByte(handle)
                readByte(handle)
                readShort(handle)

                ticks[currenttickIndex][lpos] = {}
                ticks[currenttickIndex][lpos]["inst"] = inst
                ticks[currenttickIndex][lpos]["note"] = note
                lpos = lpos + 1

                sc.yield()
            end
        else
            while true do
                local jump = readShort(handle)
                if jump == 0 then
                    break
                end

                local inst = readByte(handle)
                local note = readByte(handle)

                ticks[currenttickIndex][lpos] = {}
                ticks[currenttickIndex][lpos]["inst"] = inst
                ticks[currenttickIndex][lpos]["note"] = note
                lpos = lpos + 1

                sc.yield()
            end
        end

        sc.yield()
    end

    return song, ticks, math.floor(currenttick / div), 1 / (sleep * 40)
end

local function toteToPitch(tote)
    return mapClip(tote, 0, 24, 0, 1)
end

local function midiToFrequency(midiNote)
    local A4 = 440
    return A4 * 2^((midiNote - 69) / 12)
end

local function convertMidiToNote(self, midiNote)
    local convertedNote = midiNote + self.noteshift
    if (convertedNote < 0 or convertedNote > 24) and self.notealigment == 0 then
        return
    end
    return convertedNote
end

------------------

local nbs = {}

------------------player

function nbs:load(disk, path)
    self.content = disk.readFile(path)
    self:loadStr(self.content)
end

function nbs:loadStr(content)
    self.content = content
end

function nbs:setSynthesizers(synthesizers)
    self.synthesizers = synthesizers
    self.useNewApi = true
    for _, synthesizer in ipairs(synthesizers) do
        if not synthesizer.toteBeep then
            self.useNewApi = false
            break
        end
    end
end

function nbs:start()
    if not self.content then return end

    local pos = 1
    local fakefile
    fakefile = {
        read = function (_, n)
            local str = self.content:sub(pos, pos + (n - 1))
            pos = pos + n
            return str
        end, seek = function (_, mode, n)
            if not mode then
                return pos - 1
            end

            if mode == "cur" then
                pos = pos + n
            elseif mode == "set" then
                pos = n + 1
            end
        end
    }

    self.state = {}
    self.state.metadata, self.state.track, self.state.length, self.state.speed = parseNBS(fakefile)
    self.state.tick = 0
end

function nbs:stop()
    self.state = nil
    for _, synthesizer in ipairs(self.synthesizers) do
        sc.yield()

        synthesizer.stop()
    end
end

function nbs:isPlaying()
    return not not self.state
end

function nbs:setDefaultInstrument(id)
    self.instrument = id
end

function nbs:setVolume(num)
    self.volume = num
end

function nbs:setNoteShift(noteshift)
    self.noteshift = noteshift
end

function nbs:setNoteAlignment(notealigment)
    self.notealigment = notealigment
end

function nbs:setSpeed(speed)
    self.speed = speed
end

local function instrumentToSamplePosition(synthesizer, id)
    return synthesizer.getMaxSamplesCount() - id
end

local defaultInstrumentsVolume = {
    [0] = 2
}

function nbs:configNoteblockSamples(instrumentsVolume, customInstruments)
    instrumentsVolume = instrumentsVolume or defaultInstrumentsVolume
    self:setNoteShift(-45)
    self:setNoteDuration(0, true, true)
    self:setDefaultInstrument(self.synthesizers[1] and instrumentToSamplePosition(self.synthesizers[1], 0) or 0)
    for _, synthesizer in ipairs(self.synthesizers) do
        for id = 0, 15 do
            synthesizer.loadSampleFromSComputers(instrumentToSamplePosition(synthesizer, id), "mc_noteblock_" .. id)
        end
    end
    self:setAltBeep(function(nbsPlayer, synthesizer, instrument, note, fullnote, duration, volume_duplication)
        if not synthesizer then return end
        local sampleIndex = customInstruments and customInstruments[instrument]
        if sampleIndex == true then return end
        if not sampleIndex and instrument >= 0 and instrument <= 15 then
            sampleIndex = instrumentToSamplePosition(synthesizer, instrument)
        end
        if not sampleIndex then
            sampleIndex = nbsPlayer.instrument
        end
        return synthesizer.sampleBeep(sampleIndex, nbsPlayer.volume * (instrumentsVolume[instrument] or 1), math.pow(2, (fullnote + nbsPlayer.noteshift) / 12.0))
    end)
end

local defaultWaveInstruments = {
    [0] = {{0, 1}, {3, 0.6}},
    [5] = {{0, 1}, {1, 0.6}},
    [6] = {{0, 1}, {2, 0.6}},
    [7] = {{3, 1}, {2, 0.6}},
}

function nbs:configWaveSamples(customInstruments)
    self:setNoteShift(24)
    self:setNoteDuration(5, false, false)
    self:setDefaultInstrument(0)
    self:setAltBeep(function(nbsPlayer, synthesizer, instrument, note, fullnote, duration, volume_duplication)
        if not synthesizer then return end
        local waves = customInstruments and customInstruments[instrument] or defaultWaveInstruments[instrument] or defaultWaveInstruments[0]
        if waves == true then return end
        local startedWaves = {}
        for _, wave in ipairs(waves) do
            table.insert(startedWaves, synthesizer.waveBeep(wave[1], nbsPlayer.volume * (wave[2] or 1), (wave[4] or 0) + midiToFrequency(fullnote + nbsPlayer.noteshift + (wave[3] or 0)), duration))
        end
        return startedWaves
    end)
end

function nbs:configDefault()
    self:setNoteShift(defaultNoteShift)
    self:setNoteDuration(0, false, false)
    self:setDefaultInstrument(defaultInstrument)
    self:setAltBeep(nil)
end

function nbs:tick()
    if not self.state then return end

    self.currentNotes = {}

    if not self.useNewApi then
        for i = 1, #self.synthesizers do
            sc.yield()
            self.synthesizers[i].clear()
        end
    end

    local unused = 1
    local tick = self.state.track[math.floor(self.state.tick)]
    if tick and (not self.tickMode or tick ~= self._tick) then
        for i = 1, #tick do
            local sourceinstrument = tick[i]["inst"]
            local instrument = self.instrumentTable[sourceinstrument + 1] or self.instrument
            local note = tick[i]["note"]

            local ii = ((i - 1) % #self.synthesizers) + 1
            local synthesizer = self.synthesizers[ii]

            local fullnote = note
            note = convertMidiToNote(self, note)
            if note then
                table.insert(self.currentNotes, {sourceinstrument, tick[i]["note"]})
                local volume = self.volume
                if instrument == 7 then
                    volume = volume + 0.3
                end
                if volume > 1 then volume = 1 end
                if self.useNewApi then
                    local str = instrument .. ":" .. note
                    if not self.currentBeeps[str] or self.tickMode then
                        local sounds = {}
                        local volume_duplication = sm.util.clamp(volume * 10, 0, 10)
                        local duration = self.noteDuration == 0 and (40 * 10) or self.noteDuration
                        if self.altBeep then
                            local newSounds = self:altBeep(synthesizer, sourceinstrument, note, fullnote, duration, volume_duplication)
                            local newSoundsT = type(newSounds)
                            if newSoundsT == "table" then
                                for _, newSound in ipairs(newSounds) do
                                    table.insert(sounds, newSound)
                                end
                            elseif newSoundsT == "number" then
                                table.insert(sounds, newSounds)
                            end
                        elseif synthesizer then
                            for i = 1, volume_duplication do
                                table.insert(sounds, synthesizer.toteBeep(instrument, note, duration))
                            end
                        end
                        self.currentBeeps[str] = {synthesizer, sounds, self.state.tick}
                    else
                        self.currentBeeps[str][3] = self.state.tick
                    end
                elseif synthesizer then
                    synthesizer.addBeep(instrument, toteToPitch(note), volume, self.noteDuration == 0 and (40 * 10) or self.noteDuration)
                end

                local _unused = ii + 1
                if _unused > unused then
                    unused = _unused
                end
            end

            sc.yield()
        end
    end
    self._tick = tick

    if self.useNewApi then
        for str, data in pairs(self.currentBeeps) do
            if data[3] ~= self.state.tick then
                if not self.flushMode then
                    for _, id in ipairs(data[2]) do
                        if type(id) == "function" then
                            id(self)
                        elseif data[1] then
                            data[1].stopBeep(id)
                        end
                    end
                end
                self.currentBeeps[str] = nil
            end
        end
    else
        if self.flushMode then
            for i = unused, #self.synthesizers do
                sc.yield()
                self.synthesizers[i].stop()
            end
        end

        if self.noteDuration == 0 then
            for i = 1, #self.synthesizers do
                sc.yield()
                self.synthesizers[i].flushWithStop()
            end
        elseif self.flushMode then
            for i = 1, #self.synthesizers do
                sc.yield()
                self.synthesizers[i].flush()
            end
        else
            for i = 1, #self.synthesizers do
                sc.yield()
                self.synthesizers[i].flushWithBind()
            end
        end
    end

    self.state.tick = self.state.tick + (self.speed * self.state.speed) + sc.getSkippedTicks()
    if self.state.tick > self.state.length then
        for _, synthesizer in ipairs(self.synthesizers) do
            sc.yield()
            synthesizer.stop()
        end
        self.state = nil
        self.currentBeeps = {}
    end
end

function nbs:getCurrentNotes()
    return self.currentNotes
end

function nbs:setNoteDuration(noteDuration, flushMode, tickMode)
    self.noteDuration = noteDuration or 0
    self.flushMode = not not flushMode
    self.tickMode = not not tickMode
end

function nbs:setAltBeep(altBeep)
    self.altBeep = altBeep
end

--[[
local _mode_square = 4
local _mode_triangle = 8
local _mode_noise = 5
local _mode_sine = 7
]]

function sc_reglib_nbs()
    local nbslib = {}

    function nbslib.create()
        return {
            currentNotes = {},
            synthesizers = {},
            instrument = defaultInstrument,
            volume = 0.1,
            noteshift = defaultNoteShift,
            notealigment = 1,
            speed = 1,
            noteDuration = 0,
            flushMode = false,
            tickMode = false,
            useNewApi = true,
            currentBeeps = {},
            instrumentTable = {
                4, --0 = Piano (Air)
                1, --1 = Double Bass (Wood)
                5, --2 = Bass Drum (Stone)
                8, --3 = Snare Drum (Sand)
                5, --4 = Click (Glass)
                3, --5 = Guitar (Wool)
                7, --6 = Flute (Clay)
                7, --7 = Bell (Block of Gold)
                7, --8 = Chime (Packed Ice)
                1  --9 = Xylophone (Bone Block)
                   --10 = Iron Xylophone (Iron Block)
                   --11 = Cow Bell (Soul Sand)
                   --12 = Didgeridoo (Pumpkin)
                   --13 = Bit (Block of Emerald)
                   --14 = Banjo (Hay)
                   --15 = Pling (Glowstone)
            },

            load = nbs.load,
            loadStr = nbs.loadStr,
            setSynthesizers = nbs.setSynthesizers,
            tick = nbs.tick,
            start = nbs.start,
            stop = nbs.stop,
            isPlaying = nbs.isPlaying,
            setDefaultInstrument = nbs.setDefaultInstrument,
            setVolume = nbs.setVolume,
            setNoteShift = nbs.setNoteShift,
            setNoteAligment = nbs.setNoteAlignment, --OOPS
            setNoteAlignment = nbs.setNoteAlignment, --FIX
            setSpeed = nbs.setSpeed,
            getCurrentNotes = nbs.getCurrentNotes,
            setNoteDuration = nbs.setNoteDuration,
            setAltBeep = nbs.setAltBeep,
            configNoteblockSamples = nbs.configNoteblockSamples,
            configWaveSamples = nbs.configWaveSamples,
            configDefault = nbs.configDefault
        }
    end

    return nbslib
end