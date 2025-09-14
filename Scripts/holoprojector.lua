dofile("$CONTENT_DATA/Scripts/Config.lua")

local sc_getEffectName = sc.getEffectName
local sm_effect_createEffect = sm.effect.createEffect
local sm_quat_fromEuler = sm.quat.fromEuler
local sm_vec3_new = sm.vec3.new
local type = type
local ipairs = ipairs
local pairs = pairs
local checkArg = checkArg
local unpack = unpack
local sm_exists = sm.exists
local table_insert = table.insert
local sm_color_new = sm.color.new
local sm_uuid_new = sm.uuid.new
local table_remove = table.remove
local math_sin = math.sin
local math_cos = math.cos
local sm_quat_new = sm.quat.new
local math_floor = math.floor

local deepcopy = sc.deepcopy
local tableChecksum = tableChecksum

local emptyEffect = sm_effect_createEffect(sc_getEffectName())
local effect_setParameter = emptyEffect.setParameter
local effect_stop = emptyEffect.stop
local effect_destroy = emptyEffect.destroy
local effect_start = emptyEffect.start
local effect_isDone = emptyEffect.isDone
local effect_setScale = emptyEffect.setScale
local effect_setOffsetPosition = emptyEffect.setOffsetPosition
local effect_setOffsetRotation = emptyEffect.setOffsetRotation
--effect_stop(emptyEffect)
effect_destroy(emptyEffect)

holoprojector = class()
holoprojector.maxParentCount = 1
holoprojector.maxChildCount = 0
holoprojector.connectionInput = sm.interactable.connectionType.composite
holoprojector.colorNormal = sm_color_new(0x58b170ff)
holoprojector.colorHighlight = sm_color_new(0x80ffa2ff)
holoprojector.componentType = "holoprojector"

local blocks = {
    [0] = sm_uuid_new("2f4c970d-c249-4f8d-ac2e-0a89abd2013f"),
    sm_uuid_new("d3db3f52-0a8d-4884-afd6-b4f2ac4365c2"),
    sm_uuid_new("765c61be-7d34-4b11-bb2f-e58cfc1708e6"),
}
local error = error
local tostring = tostring
local huge = math.huge

local function tableInsert(self, dat)
    local tbl = self.voxels
    for i = 1, huge do
        if not tbl[i] then
            tbl[i] = dat
            if i > self.maxVoxelId then
                self.maxVoxelId = i
            end
            return i
        end
    end
end

local function err1(maxvoxeloffset, attempt)
    error("the maximum voxel offset exceeded the limit for this projector: " .. tostring(maxvoxeloffset) .. ". attempt: " .. tostring(attempt), 3)
end

local function err2(maxlocalscale, attempt)
    error("the maximum local scale exceeded the limit for this projector: " .. tostring(maxlocalscale) .. ". attempt: " .. tostring(attempt), 3)
end

local formatColor = sc.formatColor
local defaultColor = sm_color_new("00ff00")

function holoprojector:server_onCreate()
    self.creative = not self.data
    self.data = self.data or {}

    sc.holoDatas[self.interactable.id] = {
        reset = function ()
            self.offsetX = 0
            self.offsetY = 0
            self.offsetZ = 0
            self.rotateX = 0
            self.rotateY = 0
            self.rotateZ = 0
            self.scaleX = 0.25
            self.scaleY = 0.25
            self.scaleZ = 0.25
            self.updateData = true
        end,

        addVoxel = function(x, y, z, color, voxel_type, localScale, localRotation)
            if not self.voxels then self.voxels = {} end
            local maxvoxels = (self.data.maxvoxels or 16384)
            if self.voxelsCount >= maxvoxels then error("voxel limit exceeded (" .. tostring(maxvoxels) .. ")", 2) end
            self.voxelsCount = self.voxelsCount + 1

            local maxvoxeloffset = self.data.maxvoxeloffset
            if maxvoxeloffset then
                if x < -maxvoxeloffset or x > maxvoxeloffset then err1(maxvoxeloffset, x) end
                if y < -maxvoxeloffset or y > maxvoxeloffset then err1(maxvoxeloffset, y) end
                if z < -maxvoxeloffset or z > maxvoxeloffset then err1(maxvoxeloffset, z) end
            end

            local data = {
                x / 4,
                y / 4,
                z / 4,
                formatColor(color, defaultColor, true),
                voxel_type or 0
            }

            local maxlocalscale = self.data.maxlocalscale or huge
            if localScale then
                local x, y, z = localScale.x, localScale.y, localScale.z
                if x <= 0 or x > maxlocalscale then err2(maxlocalscale, x) end
                if y <= 0 or y > maxlocalscale then err2(maxlocalscale, y) end
                if z <= 0 or z > maxlocalscale then err2(maxlocalscale, z) end
            end

            if localScale then
                data[6] = localScale.x
                data[7] = localScale.y
                data[8] = localScale.z
            end

			if localRotation then
				data[9] = localRotation.x
                data[10] = localRotation.y
                data[11] = localRotation.z
			end

            return tableInsert(self, data)
        end,
        delVoxel = function (voxelId)
            if self.voxels and self.voxels[voxelId] then
                self.voxels[voxelId] = nil
                self.voxelsCount = self.voxelsCount - 1
            else
                error("incorrect voxel ID", 2)
            end
        end,
        clear = function ()
            self.voxelsCount = 0
            self.voxels = nil
            self.maxVoxelId = 0
            --self.clearFlag = true
        end,
        flush = function ()
            self.flushFlag = true
        end,



        setOffset = function (x, y, z)
            checkArg(1, x, "number")
            checkArg(2, y, "number")
            checkArg(3, z, "number")

            local maxoffset = self.data.maxoffset or math.huge
            local function err(attempt)
                error("the maximum offset exceeded the limit for this projector: " .. tostring(maxoffset) .. ". attempt: " .. tostring(attempt), 3)
            end
            if x < -maxoffset or x > maxoffset then err(x) end
            if y < -maxoffset or y > maxoffset then err(y) end
            if z < -maxoffset or z > maxoffset then err(z) end

            if x ~= self.offsetX or y ~= self.offsetY or z ~= self.offsetZ then
                self.offsetX = x / 4
                self.offsetY = y / 4
                self.offsetZ = z / 4
                self.updateData = true
            end
        end,
        getOffset = function ()
            return self.offsetX, self.offsetY, self.offsetZ
        end,

        setRotation = function (x, y, z)
            checkArg(1, x, "number")
            checkArg(2, y, "number")
            checkArg(3, z, "number")
            
            if x ~= self.rotateX or y ~= self.rotateY or z ~= self.rotateZ then
                self.rotateX = x
                self.rotateY = y
                self.rotateZ = z
                self.updateData = true
            end
        end,
        getRotation = function ()
            return self.rotateX, self.rotateY, self.rotateZ
        end,

        setScale = function (x, y, z)
            checkArg(1, x, "number")
            checkArg(2, y, "number")
            checkArg(3, z, "number")

            local maxscale = self.data.maxscale or math.huge
            local function err(attempt)
                error("the maximum scale exceeded the limit for this projector: " .. tostring(maxscale) .. ". attempt: " .. tostring(attempt), 3)
            end
            if x <= 0 or x > maxscale then err(x) end
            if y <= 0 or y > maxscale then err(y) end
            if z <= 0 or z > maxscale then err(z) end
            
            if x ~= self.scaleX or y ~= self.scaleY or z ~= self.scaleZ then
                self.scaleX = x
                self.scaleY = y
                self.scaleZ = z
                self.updateData = true
            end
        end,
        getScale = function ()
            return self.scaleX, self.scaleY, self.scaleZ
        end
    }

    self.voxelsCount = 0
    sc.holoDatas[self.interactable.id].reset()
    sc.holoDatas[self.interactable.id].clear()

    if sc.creativeCheck(self, self.creative) then return end
end

local sendToClients = vnetwork.sendToClients
function holoprojector:server_onFixedUpdate()
    if sc.creativeCheck(self, self.creative) then return end
	if sc.needScreenSend() then self.allow_update = true end

    if self.allow_update and (self.updateData or self.flushFlag) then
        self.allow_update = nil

        if self.updateData then
            self.network:sendToClients("cl_updateData", {
                scaleX = self.scaleX,
                scaleY = self.scaleY,
                scaleZ = self.scaleZ,

                rotateX = self.rotateX,
                rotateY = self.rotateY,
                rotateZ = self.rotateZ,

                offsetX = self.offsetX,
                offsetY = self.offsetY,
                offsetZ = self.offsetZ,
            })
            sc.addLagScore(0.1)
            self.updateData = nil
        end

        if self.flushFlag then
            if self.voxels then
                local currentChecksum = tableChecksum(self.voxels)
                if currentChecksum ~= self.old_currentChecksum then
                    self.old_currentChecksum = currentChecksum

                    --[[
                    for i = self.voxelsCount, 1, -1 do
                        if not self.voxels[i] then
                            table.remove(self.voxels, i)
                        end
                    end
                    ]]
                    --if self.clearFlag then
                    --    self.voxels.clear = true
                    --end
                    sc.addLagScore(self.maxVoxelId / 100)
                    self.voxels.len = self.maxVoxelId
                    if pcall(sendToClients, self, "cl_upload", self.voxels) then
                    --    self.clearFlag = nil
                    else
                        local index = 1
                        local count = 1024

                        local datapack
                        while true do
                            --datapack = {unpack(self.voxels, index, index + (count - 1))}
                            datapack = {unpack(self.voxels, index, index + (count - 1))}
                            --if self.clearFlag then
                            --    datapack.clear = true
                            --end

                            index = index + count
                            if datapack[#datapack] == self.voxels[#self.voxels] then
                                datapack.endPack = true
                                if pcall(sendToClients, self, "cl_upload", datapack) then
                                    --self.clearFlag = nil
                                    break
                                else
                                    index = index - count
                                    count = math_floor((count / 2) + 0.5)
                                end
                            elseif pcall(sendToClients, self, "cl_upload", datapack) then
                                --self.clearFlag = nil
                            else
                                index = index - count
                                count = math_floor((count / 2) + 0.5)
                            end
                        end
                    end
                end
            else
                --self.network:sendToClients("cl_upload", {clear = self.clearFlag})
                self.network:sendToClients("cl_upload", {})
                --self.clearFlag = nil
                self.old_currentChecksum = nil
            end

            --self.voxels = nil
            self.flushFlag = nil
        end
    end
end

function holoprojector:server_onDestroy()
    sc.holoDatas[self.interactable.id] = nil
end

-----------------------------------------------------------

function holoprojector:client_onCreate()
    self.effects = {}
    self.effectsI = 1
    self:cl_recreateBuffer()
end

function holoprojector:cl_recreateBuffer()
    if self.bufeffects then
        for _, buf in ipairs(self.bufeffects) do
            for _, edata in ipairs(buf) do
                if sm_exists(edata) then
                    effect_destroy(edata)
                end
            end
        end
    end
    
    self.bufeffects = {}
end

local fromEuler = fromEuler
local function cl_doEffect(self, edata)
    local effect, data = edata[1], edata[2]

    local self_drawData = self.drawData
    --local rotate = holoprojector_doQuat(1, 0, 0, self_drawData.rotateX) * holoprojector_doQuat(0, 1, 0, self_drawData.rotateY) * holoprojector_doQuat(0, 0, 1, self_drawData.rotateZ)
    local rotate = fromEuler(self.drawData.rotateX, self.drawData.rotateY, self.drawData.rotateZ)
    local scale = sm_vec3_new(self_drawData.scaleX, self_drawData.scaleY, self_drawData.scaleZ)

    local addScale = sm_vec3_new(data[6] or 1, data[7] or 1, data[8] or 1)
    effect_setScale(effect, scale * addScale)
    --effect_setOffsetPosition(effect, ((rotate * data.position) + sm_vec3_new(self_drawData.offsetX, self_drawData.offsetY, self_drawData.offsetZ)) * (scale * 4))
	if data[9] then
	    effect_setOffsetRotation(effect, rotate * fromEuler(data[9], data[10], data[11]))
	else
		effect_setOffsetRotation(effect, rotate)
	end

    return ((rotate * sm_vec3_new(data[1], data[2], data[3])) + sm_vec3_new(self_drawData.offsetX, self_drawData.offsetY, self_drawData.offsetZ)) * (scale * 4)
end

function holoprojector:client_onDestroy()
    for _, edata in ipairs(self.effects) do
        if sm_exists(edata[1]) then
            effect_destroy(edata[1])
        end
    end
    self:cl_recreateBuffer()
end

function holoprojector:cl_updateData(data)
    self.drawData = data
    
    for _, edata in ipairs(self.effects) do
        if sm_exists(edata[1]) then
            local newpos = cl_doEffect(self, edata)
            effect_setOffsetPosition(edata[1], newpos)
        end
    end
end

local function bufeffects(self, voxel_type)
	if type(voxel_type) == "Uuid" then
		voxel_type = tostring(voxel_type)
	end
	if not self.bufeffects[voxel_type] then
		self.bufeffects[voxel_type] = {}
	end
	return self.bufeffects[voxel_type]
end

local hideOffset = sm_vec3_new(10000000, 10000000, 10000000)
local sc_getEffectName = sc.getEffectName
function holoprojector:cl_upload(datas)
    datas = datas or self.sendData
    local gotos = {}

    for _, edata in ipairs(self.effects) do
        if sm_exists(edata[1]) then
            gotos[edata[1]] = hideOffset
            table_insert(bufeffects(self, edata[2][5]), edata[1])
        end
    end
    self.effects = {}
    self.effectsI = 1

    if datas.len then
        for i = 1, datas.len do
            local data = datas[i]
            if data then
				local uuidType = type(data[5])
				local uuidIsNumber = uuidType == "number"
                if uuidIsNumber and not blocks[data[5]] then data[5] = 1 end

                local effect
				local buf = bufeffects(self, data[5])
                if #buf > 0 then
                    effect = table_remove(buf)
                else
                    effect = sm_effect_createEffect(sc_getEffectName(), self.interactable)
					if uuidIsNumber then
	                    effect_setParameter(effect, "uuid", blocks[data[5]])
					elseif uuidType == "Uuid" then
						effect_setParameter(effect, "uuid", data[5])
					elseif uuidType == "string" then
						effect_setParameter(effect, "uuid", sm_uuid_new(data[5]))
					end
                    effect_start(effect)
                end
                
                effect_setParameter(effect, "color", data[4])
        
                local ldata = {effect, data}
                gotos[effect] = cl_doEffect(self, ldata)
                self.effects[self.effectsI] = ldata
                self.effectsI = self.effectsI + 1
            end
        end
    end

    for key, value in pairs(gotos) do
        effect_setOffsetPosition(key, value)
    end
end