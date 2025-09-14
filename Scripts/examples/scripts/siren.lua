synthesizers = getComponents("synthesizer")

function calls(...)
    local args = {...}
    for i, cmp in ipairs(synthesizers) do
        cmp[args[1] ] (unpack(args, 2))
    end
end

calls("stop")

tick = 1
function callback_loop()
    if _endtick then
        calls("stop")
    else
        currentBeep = tick % 40 > 20

        if currentBeep ~= oldBeep then
            calls("stop")
            calls("clear")
            if currentBeep then
                calls("addBeep", 3, 0.5, 1, 40)
            else
                calls("addBeep", 3, 1, 1, 40)
            end
            calls("flush")
        end
        oldBeep = currentBeep
    end
    tick = tick + 1
end