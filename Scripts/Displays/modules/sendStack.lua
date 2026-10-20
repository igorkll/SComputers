function displays_sendStack(self, method, stack, force, forceForce)
    if #sm.player.getAllPlayers() > 1 then
        stack.flush = true
        stack.force = force
        stack.forceForce = forceForce
        if not pcall(self.network.sendToClients, self.network, method, stack) then
            stack.flush = nil

            local mul = 0.8
            local index = 1
            local stackSize = #stack
            local count = math.min(stackSize, self.tryPacket or defaultTrySend)
            local cycles = 0
            local lastIndex
            local datapack
            local dataPackI
            while true do
                lastIndex = index + (count - 1)
                datapack = {}
                dataPackI = 1
                for i = index, math.min(lastIndex, stackSize) do
                    datapack[dataPackI] = stack[i]
                    dataPackI = dataPackI + 1
                end
                datapack.force = force

                index = index + count
                if lastIndex >= #stack then
                    datapack.flush = true
                    if pcall(self.network.sendToClients, self.network, method, datapack) then
                        self.tryPacket = count
                        break
                    else
                        datapack.flush = nil
                        index = index - count
                        count = math.floor(count * mul)
                    end
                elseif not pcall(self.network.sendToClients, self.network, method, datapack) then
                    index = index - count
                    count = math.floor(count * mul)
                end

                cycles = cycles + 1
                if cycles > 100 then
                    print("try send: ", pcall(self.network.sendToClients, self.network, method, stack))
                    error("cycles to many 100")
                    break
                end
            end
        end
    else
        stack.force = force
        self["sendedData_" .. method] = stack
        self.network:sendToClients(method)
    end
end