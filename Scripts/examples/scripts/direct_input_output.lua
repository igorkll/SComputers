--use "always on" for this example

out(false)

local flag = false
local state = false
local _state = false
function callback_loop()
    local state = input()
    if state and not _state then
        flag = not flag
        out(flag)
    end
    _state = state
end