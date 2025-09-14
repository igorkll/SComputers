--composite writer(input) - writes a number/boolean to the computer register, while the values are always represented as a number
--composite reader(output) - outputs the value of the computer register to the logic-block/number-logic-block

clearregs() --clears all registers

local flag = false
local _trigger = false
function callback_loop()
    local number = getreg("num") --getting a number from writer
    if number then
        setreg("out", number + 1) --number output on reader
    else
        setreg("out", -1)
    end

    local trigger = getreg("trigger") == 1
    if trigger and not _trigger then
        flag = not flag
    end
    _trigger = trigger
    setreg("flag", flag)
end