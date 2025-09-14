--this code sends the table over the network port
--you can use it to send it through the antenna, if you connect the network port to the antenna

local port = getComponent("port")

function callback_loop()
    port.sendTable({
        uptime = getUptime(),
        message = "hello"
    })
end