vnetwork = {}

function vnetwork.init()
    if vnetwork.host then return end

    local hid = math.huge
    for i, player in ipairs(sm.player.getAllPlayers()) do
        if player.id < hid then
            hid = player.id
            vnetwork.host = player
        end
    end
    if not vnetwork.host then
        error("vnetwork problem!!!")
        return
    end

    print("vnetwork.init()")
end

function vnetwork.sendToClient(self, player, method, data)
    --self.network:sendToClient(player, method, data)
    --do return end

    if player.id == vnetwork.host.id then
        self.sendData = data
        self.network:sendToClient(player, method)
    else
        self.network:sendToClient(player, method, data)
    end
end

function vnetwork.sendToClients(self, method, data, maxdist, whitelist)
    for i, player in ipairs(sm.player.getAllPlayers()) do
        if not whitelist or whitelist[player.id] then
            local worldPosition
            if self.shape then
                worldPosition = self.shape.worldPosition
            elseif self.tool then
                worldPosition = self.tool:getOwner().character.worldPosition
            end
            if not worldPosition or not maxdist or mathDist(worldPosition, player.character.worldPosition) <= maxdist then
                vnetwork.sendToClient(self, player, method, data)
            end
        end
    end
end

function vnetwork.sendToServer(self, method, data)
    self.network:sendToServer(method, data)
end