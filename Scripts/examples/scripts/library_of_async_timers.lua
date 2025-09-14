-- methods for the timer
-- timer:delete() - deletes the timer
-- timer:isTriggered() - returns the value true when the timer is triggered and resets the trigger flag
-- timer:setEnabled(enable:boolean) - activates or deactivates the timer but does not reset it
-- timer:reset() - resets the timer, sets the value to 0. for oneshot timers, by default, the value is equal to the period so that it does not start working without resetting
-- timer:setValue(value:number) - sets the current timer value
-- timer:setPeriod(value:number) - sets the timer period from 1 to as many as you like in ticks. a value of 1 will trigger the timer every tick and a value of 2 will trigger every two ticks, 40 will trigger every second
-- timer:setAutoReset(autoreset:boolean) - sets whether the timer will reset itself

local timerhost = require("timer").createHost()

local oneshotTimer = timerhost:createTimer(40, false) --you can add a callback to the oneshot timer in the same way as on a regular one

local autoTimer1 = timerhost:createTimer(40 * 5, true, function (timer)
    print("timer 1. period: " .. timer.period .. " ticks")
    oneshotTimer:reset()
end)

local autoTimer2 = timerhost:createTimer(40 * 3, true, function (timer)
    print("timer 2. period: " .. timer.period .. " ticks")
end)

timerhost:setEnabledAll(true)

function callback_loop()
    timerhost:tick()

    if oneshotTimer:isTriggered() then --allows you to find out from the code that the timer has been triggered
        print("the oneshot timer has triggered!")
    end
end