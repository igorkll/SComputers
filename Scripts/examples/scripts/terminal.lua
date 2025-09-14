local lineChar = string.char(13)
local bellChar = string.char(7)

local terminal = getComponent("terminal")
terminal.read()
terminal.clear()
terminal.write("#ffff00terminal demo code" .. lineChar)

function callback_loop()
    local text = terminal.read()
    if text then
        if text == "/beep" then
            terminal.write(string.char(7))
        elseif text == "/clear" then
            terminal.clear()
        end
        terminal.write("#00ff00> " .. text .. bellChar .. lineChar)
    end

    if _endtick then
        terminal.clear()
    end
end