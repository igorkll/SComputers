--receives packets in the form of a table via a network port
--you can use the antenna by connecting it to the network port

local port = getComponent("port")
port.clear()

function callback_loop()
    local tbl = port.nextTable()
    if tbl then
        logPrint("NEW MESSAGE:")
        for k, v in pairs(tbl) do
            logPrint(k, ": ", v)
        end
    end
end