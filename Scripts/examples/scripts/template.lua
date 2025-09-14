--the code written here is executed only 1 time when the computer is turned on

function onStart()
    --the code written here is executed after the code written outside the function
end

function onTick(dt)
    --the code written here will be executed every tick when the computer is turned on
    --dt in this case is the deltatime of TPS multiplied by the number of skipped ticks by the computer + 1
end

function onStop()
    --it is executed when you turn off the computer
end

function onError(err)
    --called if an error occurred in your code during execution
    --even though you have received an error, it will still cause your computer to crash
    --errors in the error handler can only be seen in the game console if you run it with the (-dev) flag

    --return true --return true if you want to restart the computer
end

_enableCallbacks = true