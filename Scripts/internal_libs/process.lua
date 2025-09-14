local function tableRemoveValue(tbl, value)
    for i = 1, #tbl do
        if tbl[i] == value then
            table.remove(tbl, i)
            break
        end
    end
end

local function clearTable(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

function sc_reglib_process(self, baseComputerEnv)
local enlua = sc.lib_require("enlua")

----------------------------- process

local processClass = {}

function processClass:load(chunk, chunkname, mode, ...)
    self.args = {...}
    self.chunk = chunk
    self.chunkname = chunkname
    self.mode = mode
    return true
end

function processClass:enluaLoad(bytecode, ...)
    self.args = {...}
    self.bytecode = bytecode
    return true
end

function processClass:isStopped()
    return not not (self.stopped or self.processEnd)
end

function processClass:getError()
    return self.error
end

function processClass:destroy()
    self:stop()
    tableRemoveValue(self.host.processList, self)
end

function processClass:getEnv()
    return self.env
end

function processClass:getTick()
    return self.tick
end

function processClass:getUptime()
    return self.uptime
end

local function makeCreateEnvHook(env, createEnv) --makes the environments that were created through this environment also be created through a custom function
    checkArg(1, env, "table")
    checkArg(2, createEnv, "function")
    
    local _require = env.require
    local localProcessLib
    function env.require(name)
        if name == "process" then
            if localProcessLib then
                return localProcessLib
            end

            --i make this function recursive so that if a process creates a process, and that process in turn creates a process again, createEnv is called up the chain and the final process creates an ENV with all modifications of the parent processes.
            local localCreateEnv
            localCreateEnv = function()
                return makeCreateEnvHook(assert(createEnv()), localCreateEnv)
            end

            localProcessLib = sc.advDeepcopy(_require("process"))
            localProcessLib.createEnv = localCreateEnv
            return localProcessLib
        end

        local ok, result = pcall(_require, name)
        if ok then
            return result
        else
            error(result, 2)
        end
    end

    return env
end

function processClass:reboot()
    self.env = makeCreateEnvHook(assert(self.createEnv()), self.createEnv)
    self.stopped = false
    self.processEnd = false
    self.rebootFlag = false
    self.tick = 0
    self.uptime = 0
    self.skippedTicks = 0
    self.error = nil
    self.code = nil
    self.oldUptime = baseComputerEnv.getUptime()

    function self.env.getTick()
        return self.tick
    end

    function self.env.getUptime()
        return self.uptime
    end

    function self.env.getSkippedTicks()
        return self.skippedTicks
    end

    function self.env.reboot()
        self.rebootFlag = true
    end
end

function processClass:stop()
    self.stopped = true
    self:_tick()
end

function processClass:_tick()
    if self.rebootFlag then
        self:reboot()
        self.rebootFlag = false
    end

    if not self.code then
        if self.bytecode then
            local code, err = enlua.load(self.bytecode, self.env)
            if not code then
                self.processEnd = true
                self.error = err
                return
            end
            
            self.code = code
        else
            local code, err = baseComputerEnv.load(self.chunk, self.chunkname, self.mode, self.env)
            if not code then
                self.processEnd = true
                self.error = err
                return
            end
            
            self.code = code
        end
    end
    
    if not self.code or self.processEnd then
        return
    end

    local realUptime = baseComputerEnv.getUptime()
    self.skippedTicks = (realUptime - self.oldUptime) - 1
    if self.skippedTicks < 0 then self.skippedTicks = 0 end

    if self.stopped then
        self.env._endtick = true
        self.processEnd = true
    end

    local function exec(onStartCall)
        local func, args
        if onStartCall then
            func = self.env.onStart
        else
            if self.env._endtick and self.env._enableCallbacks and self.env.onStop then
                func = self.env.onStop
            elseif self.env._enableCallbacks then
                func = self.env.onTick or function() end
                pcall(function()
                    args = {baseComputerEnv.getDeltaTimeTps() * (self.skippedTicks + 1)}
                end)
            elseif self.env.callback_loop then
                func = self.env.callback_loop
            else
                func = self.code
                args = self.args
            end
        end

        local okay, err
        if args then
            okay, err = pcall(func, unpack(args))
        else
            okay, err = pcall(func)
        end
        if not okay then
            self.processEnd = true
            self.error = err
            local errFunc, detectReboot
            if self.env._enableCallbacks then
                detectReboot = true
                errFunc = self.env.onError
            else
                errFunc = self.env.callback_error
            end
            if errFunc then
                local okay, err = pcall(errFunc, err)
                if not okay then
                    sm.log.error("error in the error handler in process", err)
                elseif err and detectReboot then
                    self.rebootFlag = true
                end
            end
            return true
        end
    end

    local onStartExists = not not self.env.onStart
    local failed = exec()
    if not failed and not onStartExists and self.env._enableCallbacks and self.env.onStart then
        exec(true)
    end

    self.tick = self.tick + 1
    self.uptime = self.uptime + self.skippedTicks + 1
    self.oldUptime = realUptime

    if self.rebootFlag then
        self:reboot()
        self.rebootFlag = false
    end
end

----------------------------- processhost

local processhostClass = {}

function processhostClass:create(createEnv)
    checkArg(1, createEnv, "function")
    
    local process = sc.setmetatable({
        host = self,
        createEnv = createEnv
    }, processClass)

    process:reboot()

    table.insert(self.processList, process)
    return process
end

function processhostClass:tick()
    for _, process in ipairs(self.processList) do
        process:_tick()
    end
end

function processhostClass:stop()
    for _, process in ipairs(self.processList) do
        process:stop()
    end
end

function processhostClass:destroy()
    for _, process in ipairs(self.processList) do
        process:stop()
    end
    self.processList = {}
end

function processhostClass:list()
    return self.processList
end

----------------------------- main

local processLibrary = {}

function processLibrary.createHost()
    return sc.setmetatable({processList = {}}, processhostClass)
end

function processLibrary.createEnv()
    return sc.lastComputer:sv_createEnv(true)
end

return processLibrary
end