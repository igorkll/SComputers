dofile("$CONTENT_DATA/Scripts/Config.lua")
cameraControl = class()
cameraControl.maxParentCount = 1
cameraControl.maxChildCount = 1
cameraControl.connectionInput = sm.interactable.connectionType.power
cameraControl.connectionOutput = sm.interactable.connectionType.composite
cameraControl.colorNormal = sm.color.new("#1bae07")
cameraControl.colorHighlight = sm.color.new("#27e30e")
cameraControl.componentType = "cameraControl"
cameraControl.nearbyMaxDistance = 16

local function rotateVector3D(vector, radiansX, radiansY, radiansZ)
    -- Матрица поворота вокруг оси X
    local rotationX = {
        {1, 0, 0},
        {0, math.cos(radiansX), -math.sin(radiansX)},
        {0, math.sin(radiansX), math.cos(radiansX)}
    }

    -- Матрица поворота вокруг оси Y
    local rotationY = {
        {math.cos(radiansY), 0, math.sin(radiansY)},
        {0, 1, 0},
        {-math.sin(radiansY), 0, math.cos(radiansY)}
    }

    -- Матрица поворота вокруг оси Z
    local rotationZ = {
        {math.cos(radiansZ), -math.sin(radiansZ), 0},
        {math.sin(radiansZ), math.cos(radiansZ), 0},
        {0, 0, 1}
    }

    -- Функция для умножения матрицы на вектор
    local function multiplyMatrixVector(matrix, vector)
        return sm.vec3.new(
            matrix[1][1] * vector.x + matrix[1][2] * vector.y + matrix[1][3] * vector.z,
            matrix[2][1] * vector.x + matrix[2][2] * vector.y + matrix[2][3] * vector.z,
            matrix[3][1] * vector.x + matrix[3][2] * vector.y + matrix[3][3] * vector.z
        )
    end

    -- Применяем повороты
    local rotatedVector = multiplyMatrixVector(rotationX, vector)
    rotatedVector = multiplyMatrixVector(rotationY, rotatedVector)
    rotatedVector = multiplyMatrixVector(rotationZ, rotatedVector)

    return rotatedVector
end

function cameraControl:server_onCreate()
    self.interactable.publicData = {
        sc_component = {
            type = cameraControl.componentType,
            api = {
                getDirection = function(nearby)
                    return self:sv_getCameraInfoValue(nearby, "direction")
                end,
                --[[
                getLocalDirection = function(nearby)
                    local rotation = toEuler(self.shape.worldRotation)
                    local newX = math.rad(90) - rotation.x
                    print(rotation, math.deg(newX))

                    local direction = self:sv_getCameraInfoValue(nearby, "direction")
                    if not direction then return end
                    return rotateVector3D(direction, -rotation.x, -rotation.y, -rotation.z)
                end,
                ]]
                getPosition = function(nearby)
                    return self:sv_getCameraInfoValue(nearby, "position")
                end,
                getRotation = function(nearby)
                    return self:sv_getCameraInfoValue(nearby, "rotation")
                end,
                getFov = function(nearby)
                    return self:sv_getCameraInfoValue(nearby, "fov")
                end,
                getUp = function(nearby)
                    return self:sv_getCameraInfoValue(nearby, "up")
                end,
                getRight = function(nearby)
                    return self:sv_getCameraInfoValue(nearby, "right")
                end,
                getCameraDistance = function(nearby)
                    local position = self:sv_getCameraInfoValue(nearby, "position")
                    if position then
                        return mathDist(self.shape.worldPosition, position)
                    end
                end,
                getPlayerDistance = function(nearby)
                    local playerPosition = self:sv_getCameraInfoValue(nearby, "playerPosition")
                    if playerPosition then
                        return mathDist(self.shape.worldPosition, playerPosition)
                    end
                end,
                getPlayerCameraDistance = function(nearby)
                    local info = self:sv_getCameraInfoValue(nearby)
                    if info then
                        return mathDist(info.position, info.playerPosition)
                    end
                end
            }
        }
    }

    self.cameraInfo = {}
end

function cameraControl:sv_getCameraInfoValue(nearby, key)
    local info
    local oldDist
    for _, cameraInfo in pairs(self.cameraInfo) do
        if nearby then
            if not cameraInfo.seated then --if you use the "nearby" flag, you will not be able to receive values from the player who is sitting in the seat
                local dist = mathDist(self.shape.worldPosition, cameraInfo.playerPosition)
                if dist <= cameraControl.nearbyMaxDistance and (not info or dist < oldDist) then
                    info = cameraInfo
                    oldDist = dist
                end
            end
        elseif cameraInfo.seated then
            info = cameraInfo
            break
        end
    end
    if info then
        if key then
            return info[key]
        end
        return info
    end
end

function cameraControl:server_onFixedUpdate()
    local parent = self.interactable:getSingleParent()
    if parent then
        self.seated = parent:isActive()
    end

    if self.seated ~= self.old_active then
        self.old_active = self.seated
        self.network:sendToClients("cl_setActive", self.old_active)
    end

    local IDs = {}
    for _, player in ipairs(sm.player.getAllPlayers()) do
        IDs[player.id] = true
    end
    for id in pairs(self.cameraInfo) do
        if not IDs[id] then
            self.cameraInfo[id] = nil
        end
    end
end

function cameraControl:sv_dataRequest()
    self.old_active = nil
end

function cameraControl:sv_updateCameraInfo(cameraInfo)
    self.cameraInfo[cameraInfo.playerId] = cameraInfo
end

function cameraControl:client_onCreate()
    self.network:sendToServer("sv_dataRequest")
end

function cameraControl:client_onFixedUpdate()
    local seated = false
    for k, v in pairs(self.interactable:getParents()) do
        if v:isActive() then
            seated = true
        end
    end
    
    local player = sm.localPlayer.getPlayer()
    local cameraInfo = {
        direction = sm.camera.getDirection(),
        position = sm.camera.getPosition(),
        rotation = sm.camera.getRotation(),
        fov = sm.camera.getFov(),
        up = sm.camera.getUp(),
        right = sm.camera.getRight(),
        seated = seated,
        playerPosition = player.character.worldPosition,
        playerId = player.id
    }

    self.network:sendToServer("sv_updateCameraInfo", cameraInfo)
end

function cameraControl:cl_setActive(active)
    self.interactable:setUvFrameIndex(active and 6 or 0)
end