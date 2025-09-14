function sc_reglib_timer()
local timer = {}

function timer:setAutoReset(autoReset)
    checkArg(1, autoReset, "boolean")
    self.autoReset = autoReset
end

function timer:setPeriod(period)
    checkArg(1, period, "number")
    self.period = period
    self:reset()
end

function timer:setValue(value)
    checkArg(1, value, "number")
    if value < 0 then value = 0 end
    if value > self.period then value = self.period end
    self.value = value
end

function timer:reset()
    self.value = 0
end

function timer:force()
    self.value = self.period - 1
end

function timer:setEnabled(enable)
    checkArg(1, enable, "boolean")
    self.enable = enable
end

function timer:isTriggered()
    local flag = self.triggered
    self.triggered = false
    return flag
end

function timer:delete()
    for i, v in ipairs(self.host.timers) do
        if v == self then
            table.remove(self.host.timers, i)
            break
        end
    end
end

------------------------------------------------

local timerhost = {}

function timerhost:createTimer(period, autoReset, callback)
    checkArg(1, period, "number")
    checkArg(2, autoReset, "boolean")
    checkArg(3, callback, "function", "nil")

    local obj = {
        autoReset = autoReset,
        callback = callback,

        triggered = false,
        enable = false,
        value = 0,
        host = self
    }

    sc.addStuff(obj, timer)
    obj:setPeriod(period)
    if not autoReset then --oneshot timers have a maximum value by default and are waiting for a reset
        obj.value = period
    end
    table.insert(self.timers, obj)
    return obj
end

function timerhost:callLater(time, callback)
    checkArg(1, time, "number")
    checkArg(2, callback, "function")

	local timer = self:createTimer(time, false, callback)
	timer:setEnabled(true)
	timer:reset()
    return timer
end

function timerhost:task(period, callback)
    checkArg(1, period, "number")
    checkArg(2, callback, "function")

	local timer = self:createTimer(period, true, callback)
	timer:setEnabled(true)
    return timer
end

function timerhost:tick()
    for i, timer in ipairs(self.timers) do
        if timer.enable then
            if timer.value < timer.period then
                local skippedTicks = 0
                if sc.lastComputer and sc.lastComputer.env then
                    local ok, result = pcall(sc.lastComputer.env.getSkippedTicks)
                    if ok and type(skippedTicks) == "number" then
                        skippedTicks = result
                    end
                end
                timer.value = timer.value + 1 + math.floor(skippedTicks)
                if timer.value > timer.period then
                    timer.value = timer.period
                end
                if timer.value == timer.period then
                    timer.triggered = true
                    if timer.callback then
                        timer:callback()
                    end
                    if timer.autoReset then
                        timer.value = 0
                    end
                end
            end
        end
    end
end

function timerhost:setEnabledAll(enable)
    checkArg(1, enable, "boolean")
    for i, timer in ipairs(self.timers) do
        timer:setEnabled(enable)
    end
end

------------------------------------------------

local timer = {}

function timer.createHost()
    local host = {
        timers = {}
    }

    return sc.addStuff(host, timerhost)
end

return timer
end