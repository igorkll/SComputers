local timerhost = require("timer").createHost()

timerhost:createTimer(40 * 3, true, function (timer)
    log("WHITE COLOR!")
end)

timerhost:createTimer(40 * 1, true, function (timer)
    log("#ff0000RED COLOR!")
end)

timerhost:setEnabledAll(true)

function callback_loop()
    timerhost:tick()
end