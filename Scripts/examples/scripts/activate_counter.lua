local function getActivateNum()
    local n = tonumber(getData()) or 0
    n = n + 1
    setData(tostring(n))
    return n
end

local d = getDisplays()[1]

d.clear()
d.drawText(1, 1, tostring(getActivateNum()), "ff0000")
d.forceFlush()

function callback_loop()
    if _endtick then
        d.clear()
        d.forceFlush()
    end
end

callback_loop()