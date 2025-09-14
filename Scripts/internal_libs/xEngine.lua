dofile("$CONTENT_DATA/Scripts/RaycastCamera.lua")
local maxBudget = 10000
local staticObjectBudget = 1
local dynamicObjectBudget = 50
local areaSize = 64

local supportedShapes = {
    ["box_1x1x1"] = sm.uuid.new("bb395d17-1b52-43d0-8d7d-3ecc09d46b07"),
    ["box_2x2x2"] = sm.uuid.new("648b1ae8-7c9e-4cb3-b527-935fd543c3f3"),
    ["box_3x3x3"] = sm.uuid.new("3b2fde74-4b3d-4e4e-aec9-e9b87755802f"),
    ["box_4x4x4"] = sm.uuid.new("97fb655e-e0ea-4359-bf7c-61d1327e70b4"),
    ["box_16x16x1"] = sm.uuid.new("3053bc20-bac7-4d69-9559-8664bfa2bbcc"),
    ["box_64x64x1"] = sm.uuid.new("8c4fb2ec-e54b-4a0a-9a5b-ea10a9dc1682"),
    ["box_16x16x4"] = sm.uuid.new("f9a43261-6b19-4beb-9476-3399e7cd9601"),
    ["sphere_1"] = sm.uuid.new("7f15869c-9d69-4f43-946c-3bd822b2820f"),
    ["sphere_2"] = sm.uuid.new("1de75f5c-42d6-45c6-876f-3d557f1b04df"),
    ["sphere_3"] = sm.uuid.new("ca3ba192-e93f-4d84-9865-b09ea4847989"),
    ["sphere_4"] = sm.uuid.new("e957c3d4-68b5-4470-999e-3254839f6539"),
    ["sphere_5"] = sm.uuid.new("c821761a-e812-4d61-bf07-18d4220de3e1"),
    ["sphere_6"] = sm.uuid.new("20f9bc86-5f4f-4d1f-aaf8-d30e526be22c"),
    ["sphere_7"] = sm.uuid.new("0aee86b9-cbf7-45f6-94a0-3b38905a6780"),
    ["sphere_8"] = sm.uuid.new("288b89f2-b0e2-4b92-9e65-0a386e9a2641"),
    ["sphere_9"] = sm.uuid.new("e985b8b5-4372-4f6c-bd40-d68c4692b175"),
    ["sphere_10"] = sm.uuid.new("5351d1bb-4094-4992-a729-1f014f84c9ba"),
    ["sphere_16"] = sm.uuid.new("2a2874ac-046f-440e-891a-fbbca4ec446e"),
    ["cylinder_1x1"] = sm.uuid.new("2b8a00e5-c633-4366-be7e-627a3df8a8b9"),
    ["cylinder_2x1"] = sm.uuid.new("a3c4e935-94cb-40dc-ae93-a3ada4d37f35"),
    ["cylinder_3x1"] = sm.uuid.new("2ec00f80-ba09-4258-ac53-e1c791e57f45"),
    ["cylinder_4x1"] = sm.uuid.new("3bec5538-1983-41be-a656-6389bc723889"),
    ["cylinder_5x1"] = sm.uuid.new("f07a77f6-27fd-44f2-b65b-ed16649203d6"),
    ["cylinder_6x1"] = sm.uuid.new("de400276-b74e-4e5a-8096-632a0110020d"),
    ["cylinder_7x1"] = sm.uuid.new("ce797b59-881b-4612-bac9-8c8f94d78b46"),
    ["cylinder_8x1"] = sm.uuid.new("653983c9-e0ec-4e2e-b662-de5999758582"),
    ["cylinder_9x1"] = sm.uuid.new("7fcc8b1e-b1f7-4a0d-aeab-e604ad0e35c0"),
    ["cylinder_10x1"] = sm.uuid.new("fc70d559-3537-4c40-8bd1-d69587d9826a"),
    ["cylinder_11x1"] = sm.uuid.new("d8be5062-c7ee-4627-a6a0-679360cef4c1"),
    ["cylinder_12x1"] = sm.uuid.new("fb29acb4-a8a3-4283-b43c-e70c900e30b0"),
    ["cylinder_13x1"] = sm.uuid.new("796c258e-863d-4aae-b77c-3b181b376a7a"),
    ["cylinder_14x1"] = sm.uuid.new("1f2eadb3-da28-4797-97ed-c570a35ab7b5"),
    ["cylinder_15x1"] = sm.uuid.new("d8ed36bb-a863-42ee-809c-9526cd521250"),
    ["cylinder_16x1"] = sm.uuid.new("6a6a9e70-9630-4391-a7ad-37c51fb8c013"),
}

local function isSupportedShape(uuid)
    for _, luuid in pairs(supportedShapes) do
        if luuid == uuid then
            return true
        end
    end
    return false
end

local function supportedShapeCheck(uuid)
    if not isSupportedShape(uuid) then
        error("shape is not supported", 3)
    end
end

local function isValidPos(pos)
    if pos.z < 0 then
        return false
    elseif pos.z > 64 then
        return false
    end
    if pos.x < -64 then
        return false
    elseif pos.x > 64 then
        return false
    end
    if pos.y < -64 then
        return false
    elseif pos.y > 64 then
        return false
    end
    return true
end

local function checkPos(pos)
    if pos.z < 0 then
        error("the Z position cannot be less than 0", 3)
    elseif pos.z > 64 then
        error("Z cannot be greater than 64", 3)
    end
    if pos.x < -64 then
        error("X cannot be less than -64", 3)
    elseif pos.x > 64 then
        error("X cannot be greater than 64", 3)
    end
    if pos.y < -64 then
        error("Y cannot be less than -64", 3)
    elseif pos.y > 64 then
        error("Y cannot be greater than 64", 3)
    end
    return pos
end

function sc_reglib_xEngine(self)
    local realself = self.realself
    local hiddenDatas = {}
    local function getHiddenData(self, force)
		if hiddenDatas[self] == nil then
	        hiddenDatas[self] = {}
		end
        if not force and hiddenDatas[self] == true then
            error("this 3D engine has been destroyed", 3)
        end
        return hiddenDatas[self]
    end

    --------------------------

    local engineCameraClass = {}

    function engineCameraClass:setPosition(position)
        checkArg(1, position, "Vec3")
        local hiddenData = getHiddenData(self)
        self.shape.worldPosition = hiddenData.parentHiddenData.position + checkPos(position)
        if self.shape.worldPosition ~= hiddenData.worldPosition then
            hiddenData.mt.raysCache = {}
            hiddenData.worldPosition = self.shape.worldPosition
        end
    end

    function engineCameraClass:setRotation(rotation)
        checkArg(1, rotation, "Quat")
        local hiddenData = getHiddenData(self)
        self.shape.worldRotation = rotation
        if self.shape.worldRotation ~= hiddenData.worldRotation then
            hiddenData.mt.raysCache = {}
            hiddenData.worldRotation = rotation
        end
    end

    function engineCameraClass:getPosition()
        local hiddenData = getHiddenData(self)
        return hiddenData.parentHiddenData.position - self.shape.worldPosition
    end

    function engineCameraClass:getRotation()
        return self.shape.worldRotation
    end

    function engineCameraClass:getDirection()
        return self.shape.worldRotation * sm.vec3.new(0, 0, 1)
    end

    function engineCameraClass:destroy()
        local hiddenData = getHiddenData(self)
        
    end

    --------------------------

    local engineShapeClass = {}

    function engineShapeClass:isStatic()
        local hiddenData = getHiddenData(self)
        return hiddenData.shape.body:isStatic()
    end

    function engineShapeClass:isDynamic()
        local hiddenData = getHiddenData(self)
        return hiddenData.shape.body:isDynamic()
    end

    function engineShapeClass:setColor(color)
        local hiddenData = getHiddenData(self)
        hiddenData.shape:setColor(sc.formatColor(color))
    end

    function engineShapeClass:getColor()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getColor())
    end

    function engineShapeClass:getPosition()
        local hiddenData = getHiddenData(self)
        return hiddenData.shape.worldPosition - hiddenData.parentHiddenData.position
    end

    function engineShapeClass:getRotation()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape.worldRotation)
    end

    function engineShapeClass:getVelocity()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getVelocity())
    end

    function engineShapeClass:getXAxis()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getXAxis())
    end

    function engineShapeClass:getYAxis()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getYAxis())
    end

    function engineShapeClass:getZAxis()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getZAxis())
    end

    function engineShapeClass:getUp()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getUp())
    end

    function engineShapeClass:getRight()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getRight())
    end

    function engineShapeClass:getAt()
        local hiddenData = getHiddenData(self)
        return sc.advDeepcopy(hiddenData.shape:getAt())
    end

    function engineShapeClass:destroy()
        local hiddenData = getHiddenData(self)
		local engineHiddenData = hiddenData.parentHiddenData
        engineHiddenData.budget = engineHiddenData.budget + hiddenData.budget
        for i, shape in ipairs(hiddenData.parentHiddenData.shapes) do
            if shape.id == hiddenData.shape.id then
                shape:destroyShape()
				hiddenDatas[engineHiddenData.shapesUserObjects[i]] = nil
                table.remove(engineHiddenData.shapes, i)
                table.remove(engineHiddenData.shapesObjects, i)
                table.remove(engineHiddenData.shapesUserObjects, i)
                break
            end
        end
    end

    function engineShapeClass:exists()
        return not not getHiddenData(self)
    end

    function engineShapeClass:getMass()
        local hiddenData = getHiddenData(self)
        return hiddenData.shape.mass
    end

    function engineShapeClass:applyImpulse(impulse, worldSpace, offset)
        checkArg(1, impulse, "Vec3")
        local hiddenData = getHiddenData(self)
        sm.physics.applyImpulse(hiddenData.shape, impulse, worldSpace, offset)
    end

    function engineShapeClass:applyTorque(torque, worldSpace)
        checkArg(1, torque, "Vec3")
        local hiddenData = getHiddenData(self)
        sm.physics.applyTorque(hiddenData.shape, torque, worldSpace)
    end

    --------------------------

    local engine = {}

    function engine:getMaxBudget()
        return maxBudget
    end

    function engine:getBudget()
        local hiddenData = getHiddenData(self)
        return hiddenData.budget
    end

    function engine:getAreaSize()
        return areaSize
    end

	function engine:getStaticObjectBudget()
		return staticObjectBudget
	end

	function engine:getDynamicObjectBudget()
		return dynamicObjectBudget
	end

    function engine:addShape(uuid, position, rotation, dynamic)
        checkArg(1, uuid, "Uuid")
        checkArg(2, position, "Vec3")
        checkArg(3, rotation, "Quat")
        checkArg(4, dynamic, "boolean")
        supportedShapeCheck(uuid)

        local hiddenData = getHiddenData(self)

        local budget
        if dynamic then
            budget = dynamicObjectBudget
        else
            budget = staticObjectBudget
        end

        if hiddenData.budget - budget < 0 then
            error("there is not enough budget to create an object", 2)
        end

		if isValidPos(hiddenData.position) then
			error("invalid spawn position of the object", 2)
		end

        hiddenData.budget = hiddenData.budget - budget
        if hiddenData.oldSpawnPosition and mathDist(hiddenData.oldSpawnPosition, position) < 0.2 then
            error("creating objects too close in 1 tick", 2)
        end
        hiddenData.oldSpawnPosition = position

        local engineShape = sc.setmetatable({}, engineShapeClass)
        local shapeHiddenData = getHiddenData(engineShape)
        shapeHiddenData.shape = sm.shape.createPart(uuid, hiddenData.position + checkPos(position), rotation, dynamic, true)
        shapeHiddenData.shapes = {}
        shapeHiddenData.parentHiddenData = hiddenData
        shapeHiddenData.budget = budget
		shapeHiddenData.dynamic = dynamic
		shapeHiddenData.engineShape = engineShape
        
        table.insert(hiddenData.shapes, shapeHiddenData.shape)
        table.insert(hiddenData.shapesObjects, shapeHiddenData)
        table.insert(hiddenData.shapesUserObjects, engineShape)
        return engineShape
    end

    function engine:addCamera()
        local engineCamera = sc.setmetatable({}, engineCameraClass)
        engineCamera.shape = {
            worldPosition = sm.vec3.new(0, 0, 0),
            worldRotation = sm.quat.fromEuler(sm.vec3.new(0, 0, 0))
        }
        local mt = sc.mt_hook({__index = RaycastCamera})
        mt.shape = engineCamera.shape
        RaycastCamera.server_onCreate(mt)
        engineCamera.api = mt.camApi

        local shapeHiddenData = getHiddenData(engineCamera)
        shapeHiddenData.parentHiddenData = getHiddenData(self)
        shapeHiddenData.mt = mt

        return engineCamera
    end

    function engine:destroy()
        local hiddenData = getHiddenData(self, true)
        if hiddenDatas[self] ~= true then
            realself.xEngine_instanceLimit = realself.xEngine_instanceLimit + 1
            for _, shape in ipairs(hiddenData.shapes) do
                if sm.exists(shape) then
                    shape:destroyShape()
                end
            end
            hiddenDatas[self] = true
        end
    end

    function engine:tick()
        local hiddenData = getHiddenData(self)
        local ctick = sm.game.getCurrentTick()
        if ctick == hiddenData.oldTick then
            error("engine:tick() cannot be called more than once per tick", 2)
        end
        hiddenData.oldTick = ctick
        hiddenData.oldSpawnPosition = nil

        local skippedTicks = 0
        if sc.lastComputer and sc.lastComputer.env then
            local ok, result = pcall(sc.lastComputer.env.getSkippedTicks)
            if ok and type(skippedTicks) == "number" then
                skippedTicks = result
            end
        end
        local skippedMul = math.floor(skippedTicks) + 1

        for i = #hiddenData.shapesObjects, 1, -1 do
            local shapeObject = hiddenData.shapesObjects[i]
            if shapeObject.dynamic and not isValidPos(shapeObject.shape.worldPosition - hiddenData.position) then
				hiddenData.budget = hiddenData.budget + shapeObject.budget
				shapeObject.shape:destroyShape()
				hiddenDatas[shapeObject.engineShape] = false
				table.remove(hiddenData.shapes, i)
				table.remove(hiddenData.shapesObjects, i)
				table.remove(hiddenData.shapesUserObjects, i)
            end
        end

		if hiddenData.gravity ~= 1 then
			for _, shapeObject in ipairs(hiddenData.shapesObjects) do
				if shapeObject.dynamic then
					local cof = 0.26455
					local val = cof - (hiddenData.gravity * cof)
					sm.physics.applyImpulse(shapeObject.shape, sm.vec3.new(0, 0, skippedMul * val * shapeObject.shape.mass), true)
				end
			end
		end
    end

    function engine:setGravity(gravity)
        if gravity < -3 then gravity = -3 end
        if gravity > 3 then gravity = 3 end
        local hiddenData = getHiddenData(self)
        hiddenData.gravity = gravity
    end

    function engine:getGravity(gravity)
        local hiddenData = getHiddenData(self)
        return hiddenData.gravity
    end

    function engine:list()
        local objects = {}
        local hiddenData = getHiddenData(self)
        for _, object in ipairs(hiddenData.shapesUserObjects) do
            table.insert(objects, object)
        end
        return objects
    end

    function engine:raycast(startPos, endPos)
        local hiddenData = getHiddenData(self)
        local distance = mathDist(startPos, endPos)
        local successful, raydata = sm.physics.raycast(hiddenData.position + startPos, hiddenData.position + endPos)
        if successful then
            local shape = raydata:getShape()
            if isSupportedShape(shape.uuid) then
                for i, lshape in ipairs(hiddenData.shapes) do
                    if lshape.id == shape.id then
                        return {
							object = hiddenData.shapesUserObjects[i],
							distance = raydata.fraction * distance,
							fraction = raydata.fraction,
							pointWorld = raydata.pointWorld - hiddenData.position,
							normalWorld = raydata.normalWorld
						}
                    end
                end
            end
        end
        return nil
    end

    --------------------------

    local xEngine = {
        shapes = sc.advDeepcopy(supportedShapes)
    }

    function xEngine.create()
        if realself.xEngine_instanceLimit <= 0 then
            error("you cannot create more than two engines at the same time", 2)
        end
        realself.xEngine_instanceLimit = realself.xEngine_instanceLimit - 1

        local engineObj = sc.setmetatable({}, engine)
        local hiddenData = getHiddenData(engineObj)
        hiddenData.shapes = {}
        hiddenData.shapesObjects = {}
        hiddenData.shapesUserObjects = {}
        hiddenData.position = sm.vec3.new(math.random(-2000, 2000), math.random(-2000, 2000), 5000)
        hiddenData.budget = maxBudget
        hiddenData.gravity = 1

        table.insert(self.xEnginesDestroy, function ()
            engineObj:destroy()
        end)

        return engineObj
    end

    return xEngine 
end

function xEngine_clear()
    for _, body in ipairs(sm.body.getAllBodies()) do
        for _, shape in ipairs(body:getShapes()) do
            if isSupportedShape(shape.uuid) then
                shape:destroyShape()
            end
        end
    end
end