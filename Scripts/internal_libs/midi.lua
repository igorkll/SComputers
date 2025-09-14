local function parseMIDI(f)
    local bit32 = bit

    local function parseVarInt(s, bits) -- parses multiple bytes as an integer
        if not s then
            error("error parsing file")
        end
        bits = bits or 8
        local mask = bit32.rshift(0xFF, 8 - bits)
        local num = 0
        for i = 1, s:len() do
            sc.yield()
            num = num + bit32.lshift(bit32.band(s:byte(i), mask), (s:len() - i) * bits)
        end
        return num
    end

    local function readChunkInfo() -- reads chunk header info
        local id = f:read(4)
        if not id then
            return
        end
        return id, parseVarInt(f:read(4))
    end

    -- Read the file header and with if file information.
    local id, size = readChunkInfo()
    --print(id, size)
    if id ~= "MThd" or size ~= 6 then
        --print("error parsing header (" .. id .. "/" .. size .. ")")
        return
    end

    local format = parseVarInt(f:read(2))
    local tracks = parseVarInt(f:read(2))
    local delta = parseVarInt(f:read(2))

    if format < 0 or format > 2 then
        --print("unknown format")
        return
    end

    local formatName = ({"single", "synchronous", "asynchronous"})[format + 1]
    --print(string.format("Found %d %s tracks.", tracks, formatName))

    if format == 2 then
        --print("Sorry, asynchronous tracks are not supported.")
        return
    end

    -- Figure out our time system and prepare accordingly.
    local time = {division = bit32.band(0x8000, delta) == 0 and "tpb" or "fps"}
    if time.division == "tpb" then
        time.tpb = bit32.band(0x7FFF, delta)
        time.mspb = 500000
        function time.tick()
            return time.mspb / time.tpb
        end
        --print(string.format("Time division is in %d ticks per beat.", time.tpb))
    else
        time.fps = bit32.band(0x7F00, delta)
        time.tpf = bit32.band(0x00FF, delta)
        function time.tick()
            return 1000000 / (time.fps * time.tpf)
        end
        --print(string.format("Time division is in %d frames per second with %d ticks per frame.", time.fps, time.tpf))
    end

    -- Parse all track chunks.
    local totalOffset = 0
    local totalLength = 0
    local tracks = {}
    local interations = 0
    while true do
        sc.yield()

        local id, size = readChunkInfo()
        if not id or id == "" then
            break
        end

        if id == "MTrk" then
            local track = {}
            local cursor = 0
            local start, offset = f:seek(), 0
            local inSysEx = false
            local running = 0

            local function read(n)
                n = n or 1
                if n > 0 then
                    offset = offset + n
                    return f:read(n)
                end
            end
            local function readVariableLength()
                local total = ""
                for i = 1, math.huge do
                    sc.yield()
                    local part = read()
                    total = total .. part
                    if bit32.band(0x80, part:byte(1)) == 0 then
                        return parseVarInt(total, 7)
                    end
                end
            end
            local function parseVoiceMessage(event)
                local channel = bit32.band(0xF, event)
                local note = parseVarInt(read())
                local velocity = parseVarInt(read())
                return channel, note, velocity
            end

            while offset < size do
                sc.yield()
                
                cursor = cursor + readVariableLength()
                totalLength = math.max(totalLength, cursor)
                local test = parseVarInt(read())
                if inSysEx and test ~= 0xF7 then
                    --error("corrupt file: could not find continuation of divided sysex event")
                end
                local event
                if bit32.band(test, 0x80) == 0 then
                    --if running == 0 then
                    --    error("corrupt file: invalid running status")
                    --end
                    --if not f.bufferRead then f.bufferRead = "" end
                    --f.bufferRead = string.char(test) .. f.bufferRead
                    --offset = offset - 1
                    event = running
                else
                    event = test
                    if test < 0xF0 then
                        running = test
                    end
                end
                local status = bit32.band(0xF0, event)

                if status == 0x80 then -- Note off.
                    local channel, note, velocity = parseVoiceMessage(event)
                    track[cursor] = {false, channel, note, velocity}

                elseif status == 0x90 then -- Note on.
                    local channel, note, velocity = parseVoiceMessage(event)
                    track[cursor] = {true, channel, note, velocity}

                elseif status == 0xA0 then -- Aftertouch / key pressure
                    parseVoiceMessage(event) -- not handled
                elseif status == 0xB0 then -- Controller
                    parseVoiceMessage(event) -- not handled
                elseif status == 0xC0 then -- Program change
                    parseVarInt(read()) -- not handled
                elseif status == 0xD0 then -- Channel pressure
                    parseVarInt(read()) -- not handled
                elseif status == 0xE0 then -- Pitch / modulation wheel
                    parseVarInt(read(2), 7) -- not handled
                elseif event == 0xF0 then -- System exclusive event
                    local length = readVariableLength()
                    if length > 0 then
                        read(length - 1)
                        inSysEx = read(1):byte(1) ~= 0xF7
                    end
                elseif event == 0xF1 then -- MIDI time code quarter frame
                    parseVarInt(read()) -- not handled
                elseif event == 0xF2 then -- Song position pointer
                    parseVarInt(read(2), 7) -- not handled
                elseif event == 0xF3 then -- Song select
                    parseVarInt(read(2), 7) -- not handled
                elseif event == 0xF7 then -- Divided system exclusive event
                    local length = readVariableLength()
                    if length > 0 then
                        read(length - 1)
                        inSysEx = read(1):byte(1) ~= 0xF7
                    else
                        inSysEx = false
                    end
                elseif event >= 0xF8 and event <= 0xFE then -- System real-time event
                    -- not handled
                elseif event == 0xFF then
                    -- Meta message.
                    local metaType = parseVarInt(read())
                    local length = parseVarInt(read())
                    local data = read(length)

                    if metaType == 0x00 then -- Sequence number
                        track.sequence = parseVarInt(data)
                    elseif metaType == 0x01 then -- Text event
                    elseif metaType == 0x02 then -- Copyright notice
                    elseif metaType == 0x03 then -- Sequence / track name
                        track.name = data
                    elseif metaType == 0x04 then -- Instrument name
                        track.instrument = data
                    elseif metaType == 0x05 then -- Lyric text
                    elseif metaType == 0x06 then -- Marker text
                    elseif metaType == 0x07 then -- Cue point
                    elseif metaType == 0x20 then -- Channel prefix assignment
                    elseif metaType == 0x2F then -- End of track
                        track.eot = cursor
                    elseif metaType == 0x51 then -- Tempo setting
                        track[cursor] = parseVarInt(data)
                    elseif metaType == 0x54 then -- SMPTE offset
                    elseif metaType == 0x58 then -- Time signature
                    elseif metaType == 0x59 then -- Key signature
                    elseif metaType == 0x7F then -- Sequencer specific event
                    end
                else
                    --[[
                    f:seek("cur", -9)
                    local area = f:read(16)
                    local dump = ""
                    for i = 1, area:len() do
                        dump = dump .. string.format(" %02X", area:byte(i))
                        if i % 4 == 0 then
                            dump = dump .. "\n"
                        end
                    end
                    error(
                        string.format(
                            "midi file contains unhandled event types:\n0x%X at offset %d/%d\ndump of the surrounding area:\n%s",
                            event,
                            offset,
                            size,
                            dump
                        )
                    )
                    ]]
                end

                cursor = cursor + 1
            end
            local delta = size - offset
            if delta ~= 0 then
                f:seek("cur", delta)
            end
            totalOffset = totalOffset + size

            table.insert(tracks, track)
        else
            --print(string.format("Encountered unknown chunk type %s, skipping.", id))
        end

        interations = interations + 1
        if interations > 1000 then
            break
        end
    end

    return {
        tracks = tracks,
        time = time,
        totalLength = totalLength
    }
end

--[[

local function noteToFreq(note)
    return math.pow(2, (note - 69) / 12) * 440
end

local function freqToPitch(freq)
    return mapClip(freq, 200, 900, 0, 1)
end

local function freqToNote(frequency)
    return math.min(25.99,math.max(0.01,math.log(frequency / 27.5*((2^(1/12))^(15))) * 1/math.log(2^(1/12))))
end

local function noteToPitch(note)
    return (note-1)/88
end
]]

local function toteToPitch(tote)
    return mapClip(tote, 0, 24, 0, 1)
end

local function convertMidiToNote(self, midiNote)
    local convertedNote = midiNote + self.noteshift
    if (convertedNote < 0 or convertedNote > 24) and self.notealigment == 0 then
        return
    end
    return convertedNote
end

------------------

local midi = {}

------------------player

function midi:load(disk, path)
    self.content = disk.readFile(path)
    self:loadStr(self.content)
end

function midi:loadStr(content)
    self.content = content
end

function midi:setSynthesizers(synthesizers)
    self.synthesizers = synthesizers
end

function midi:start()
    if not self.content then return end
    
    self.state = {stopflag = {}, cbeeps = {}}

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

    self.state.mid = parseMIDI(fakefile)
    self.state.tick = 1
    self.state.cnotes = {}

    for i in ipairs(self.synthesizers) do
        sc.yield()

        self.state.cnotes[i] = {}
        self.state.cbeeps[i] = {}
    end
end

function midi:stop()
    self.state = nil
    for _, synthesizer in ipairs(self.synthesizers) do
        sc.yield()

        synthesizer.stop()
    end
end

function midi:isPlaying()
    return not not self.state
end

function midi:setDefaultInstrument(id)
    self.instrument = id
end

function midi:setVolume(num)
    self.volume = num
end

function midi:setNoteShift(noteshift)
    self.noteshift = noteshift
end

function midi:setNoteAligment(notealigment)
    self.notealigment = notealigment
end

function midi:setSpeed(speed)
    self.speed = speed
end

function midi:_flush()
    if not self.state.flushflag then return end

    for synthesizerId in pairs(self.state.stopflag) do
        sc.yield()
        local synthesizer = self.synthesizers[synthesizerId]
        self.state.cbeeps[synthesizerId] = {}
        synthesizer.stop()
    end

    for _, synthesizer in ipairs(self.synthesizers) do
        sc.yield()
        synthesizer.clear()
    end
    
    for synthesizerId, notes in pairs(self.state.cnotes) do
        sc.yield()
        for note, data in pairs(notes) do
            sc.yield()
            local synthesizer = self.synthesizers[synthesizerId]
            local note = toteToPitch(note)
            local volume = self.volume
            local instrumentTable = self.instrumentTable
            local instrument = self.instrument
            if instrumentTable then
                local trackname = data.trackname
                if trackname then
                    trackname = trackname:lower()
                    local idx = self.instrumentTable[trackname]
                    if idx then
                        instrument = idx
                    else
                        for key, value in pairs(self.instrumentTable) do
                            sc.yield()
                            if trackname:find(key:lower()) then
                                if type(value) == "table" then
                                    instrument = value[1]
                                    volume = volume * (value[2] or 1)
                                else
                                    instrument = value
                                end
                                break
                            end
                        end
                    end
                end
            end

            local finded
            for _, tbl in ipairs(self.state.cbeeps[synthesizerId]) do
                sc.yield()
                if tbl[1] == instrument and tbl[2] == note and tbl[3] == volume then
                    finded = true
                    break
                end
            end

            if not finded then
                table.insert(self.state.cbeeps[synthesizerId], {instrument, note, volume})
                self.synthesizers[synthesizerId].addBeep(instrument, note, volume)
                synthesizer.flush() --does not lead to unnecessary shipments, just puts a flag
            end
        end
    end

    self.state.flushflag = nil
    self.state.stopflag = {}
end

function midi:tick()
    if not self.state then return end

    for _ = 0, sc.getSkippedTicks() do
        for i = 1, math.floor((((1000000 / self.state.mid.time.tick()) / 40) * self.speed) + 0.5) do
            sc.yield()
            for trackid, track in ipairs(self.state.mid.tracks) do
                --print(track.name)
                sc.yield()
                local event = track[self.state.tick]
                if event then
                    if type(event) == "number" then
                        self.state.mid.time.mspb = event
                    elseif type(event) == "table" then
                        local state, channel, note, velocity = unpack(event)

                        trackid = trackid - 1
                        trackid = trackid % #self.synthesizers
                        local synthesizerId = trackid + 1

                        note = convertMidiToNote(self, note)
                        if note then
                            if state then
                                local old_synthesizerId = synthesizerId

                                local activeCount = 0
                                for note in pairs(self.state.cnotes[synthesizerId]) do
                                    sc.yield()
                                    activeCount = activeCount + 1
                                end
                                if activeCount > 0 then
                                    for id in ipairs(self.synthesizers) do
                                        sc.yield()
                                        local activeCount2 = 0
                                        for note in pairs(self.state.cnotes[id]) do
                                            sc.yield()
                                            activeCount2 = activeCount2 + 1
                                        end
                                        if activeCount2 == 0 then
                                            synthesizerId = id
                                            break
                                        end
                                    end
                                end

                                if old_synthesizerId ~= synthesizerId then
                                    if not self.state.swapTable then self.state.swapTable = {} end
                                    table.insert(self.state.swapTable, {note, old_synthesizerId, synthesizerId})
                                end
                                self.state.cnotes[synthesizerId][note] = {trackname = track.name, instrument = track.instrument}
                            else
                                local swaps = {}
                                if self.state.swapTable then   
                                    for i = #self.state.swapTable, 1, -1 do
                                        sc.yield()
                                        local tbl = self.state.swapTable[i]
                                        if tbl and tbl[1] == note and tbl[2] == synthesizerId then
                                            table.insert(swaps, tbl[3])
                                            self.state.swapTable[i] = nil
                                        end
                                    end
                                end

                                if #swaps > 0 then
                                    for _, swap in ipairs(swaps) do
                                        sc.yield()
                                        self.state.cnotes[swap][note] = nil
                                        self.state.stopflag[swap] = true
                                    end
                                else
                                    self.state.cnotes[synthesizerId][note] = nil
                                    self.state.stopflag[synthesizerId] = true
                                end
                            end

                            self.state.flushflag = true
                        end
                    end
                end
            end

            self.state.tick = self.state.tick + 1
            if self.state.tick > self.state.mid.totalLength then
                for _, synthesizer in ipairs(self.synthesizers) do
                    sc.yield()
                    synthesizer.stop()
                end
                self.state = nil
                return
            end
        end
    end

    self:_flush()
end

function sc_reglib_midi()
local midilib = {}

function midilib.create()
    return {
        synthesizers = {},
        instrument = 4,
        volume = 0.1,
        noteshift = -50,
        notealigment = 1,
        speed = 1,
        _flush = midi._flush,
        instrumentTable = {
            square = {8, 1},
            guitar = {9, 1},
            piano = 4,
            synth = 3,
            bass = 5,
            drum = 2
        },

        load = midi.load,
        loadStr = midi.loadStr,
        setSynthesizers = midi.setSynthesizers,
        tick = midi.tick,
        start = midi.start,
        stop = midi.stop,
        isPlaying = midi.isPlaying,
        setDefaultInstrument = midi.setDefaultInstrument,
        setVolume = midi.setVolume,
        setNoteShift = midi.setNoteShift,
        setNoteAligment = midi.setNoteAligment, --OOPS
        setNoteAlignment = midi.setNoteAligment, --FIX
        setSpeed = midi.setSpeed
    }
end

return midilib
end