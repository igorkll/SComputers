local cameraFov = math.rad(75)
local playerHeight = 1.5
local playerHeightAdditional = 0.3
local playerSpeed = 0.3
local playerGravity = 0.025
local cameraRotationPerTick = 3
local cameraRotationPerDisplay = 90
local armLength = 10
local jumpVelocity = 0.3
local defaultPlayerPosition = sm.vec3.new(0, 0, 1)

-------------------------------------------------

local function orderedFromEuler(order, x, y, z)
	local function doQuat(x, y, z, w)
		w = math.rad(w)
		local sin = math.sin(w / 2)
		return sm.quat.new(sin * x, sin * y, sin * z, math.cos(w / 2))
	end

	local quat
	for i = 1, #order do
		local char = order:sub(i, i)
		local lquat
		if char == "X" then
			lquat = doQuat(1, 0, 0, x)
		elseif char == "Y" then
			lquat = doQuat(0, 1, 0, y)
		elseif char == "Z" then
			lquat = doQuat(0, 0, 1, z)
		end
		if quat then
			quat = quat * lquat
		else
			quat = lquat
		end
	end
	return quat
end

-------------------------------------------------

local xEngine = require("xEngine")
local engine = xEngine.create()

local display = getComponent("display")
local wasd = getComponents("wasd")[1]

display.reset()
display.setClicksAllowed(true)

local renderSettings = {
	lampLighting = false,
	shadows = true,
	smoothingTerrain = false,
	simpleShadows = true,
	sun = true, --is the solar disk being rendered
	fog = true,
	reduceAccuracy = false, --allows you to use fewer display effects in fog and simpleShadows, which increases performance in some cases

	constColor = nil, --allows you to make all objects in one color
	constDayLightValue = 0.5, --you can make a constant time of day
	shadowMultiplier = 0.3,
	sunPercentage = 0.003, --this value is the percentage of the sun from the size of the sky
	simpleShadowMin = 0.3, --the minimum brightness of an object that a simple shadow can give
	simpleShadowMax = 1, --the maximum brightness of an object that a simple shadow can give

	customWaterColor = nil,
	customChemicalColor = nil,
	customOilColor = nil,

	constSkyColor = nil, --by default, it depends on the time of day
	customSunColor = nil, --you can change the color of the sun
	constShapeColor = nil,
	customLiftColor = nil,
	constTerrainColor = nil, --you can make the whole terrain one color, even blue
	constCharacterColor = nil,
	constJointColor = nil,
	constHarvestableColor = nil, --allows all Harvestables to be the same color, instead of their real color
	constAssetsColor = nil, --you can set the constant color of assets so that it is always 1 and is not determined by the material

	customTerrainColor_dirt = nil,
	customTerrainColor_grass = nil,
	customTerrainColor_sand = nil,
	customTerrainColor_stone = nil,
}

defaultPlayerPosition = defaultPlayerPosition + sm.vec3.new(0.5, 0.5, playerHeight)
local cameraPosition = sm.vec3.new(defaultPlayerPosition.x, defaultPlayerPosition.y, defaultPlayerPosition.z)
local cameraRotation = 0
local cameraRotationY = 30

local width = display.getWidth()
local height = display.getHeight()
local aspectRation = width / height

local zeroRotation = sm.quat.fromEuler(sm.vec3.new(0, 0, 0))
local halfVec3 = sm.vec3.new(0.5, 0.5, 0.5)

local function getCameraRotation()
	return orderedFromEuler("YZX", cameraRotationY + 90, 0, cameraRotation + 90)
end

local function getCameraDirection()
	local quat = getCameraRotation()
	return sm.quat.getAt(quat)
end

local function playerCast(side)
	for ix = -1, 1 do
		for iy = -1, 1 do
			local cast
			local lpos = cameraPosition + sm.vec3.new(ix * 0.1, iy * 0.1, 0)
			if side then
				cast = engine:raycast(lpos, lpos + sm.vec3.new(0, 0, playerHeightAdditional))
			else
				cast = engine:raycast(lpos, lpos - sm.vec3.new(0, 0, playerHeight))
			end
			if cast then
				return cast
			end
		end
	end
end

local function cameraRaycast()
	local cast = engine:raycast(cameraPosition, cameraPosition + (getCameraDirection() * armLength))
	if cast then
		local sidesCount = 0
		local function vcheck(val)
			if math.abs(val) > 0.8 then
				sidesCount = sidesCount + 1
			end
		end
		vcheck(cast.normalWorld.x)
		vcheck(cast.normalWorld.y)
		vcheck(cast.normalWorld.z)
		if sidesCount == 1 then
			return cast
		end
	end
end

local function spawnBlock()
	local cast = cameraRaycast()
	if cast then
		local blockPosition = cast.pointWorld - (getCameraDirection() / 2)
		blockPosition.x = math.floor(blockPosition.x)
		blockPosition.y = math.floor(blockPosition.y)
		blockPosition.z = math.floor(blockPosition.z)

		local function raycastCheck(x, y, z)
			return engine:raycast(blockPosition + halfVec3, blockPosition + halfVec3 + sm.vec3.new(x, y, z))
		end

		local raylenght = 1.2
		if raycastCheck(raylenght, 0, 0) or raycastCheck(-raylenght, 0, 0) or raycastCheck(0, raylenght, 0) or raycastCheck(0, -raylenght, 0) or raycastCheck(0, 0, raylenght) or raycastCheck(0, 0, -raylenght) then
			local ok, result = pcall(engine.addShape, engine, xEngine.shapes.box_4x4x4, blockPosition, zeroRotation, false)
			if ok then
				result:setColor(0xff0000)
				return result
			end
		end
	end
end

local function destroyBlock()
	local cast = cameraRaycast()
	if cast then
		cast.object:destroy()
	end
end

local camera = engine:addCamera()
camera.api.setStep(2048)
camera.api.setNonSquareFov(cameraFov * aspectRation, cameraFov)
camera.api.setDistance(8)

local world = {blocks = {}}
for ix = -32, 32 do
	for iy = -32, 32 do
		local shape = engine:addShape(xEngine.shapes.box_4x4x4,
			sm.vec3.new(ix, iy, 0),
			sm.quat.fromEuler(sm.vec3.new(0, 0, 0)),
			false
		)
		shape:setColor((ix + iy) % 2 == 0 and 0x00ee00 or 0x008800)
	end
end

local cameraRotationPerDisplayX = cameraRotationPerDisplay * aspectRation
local oldClickX, oldClickY
local currentPlayerVelocity = 0
local old_mouse_left = false
local old_mouse_right = false
local old_jump = false
local touchedGround = false
local dragged = false

function onTick(dt)
	if wasd then
		if getreg("camera_control") == 1 or wasd.isMouseC() then
			if wasd.isW() then
				cameraRotationY = cameraRotationY - cameraRotationPerTick
			elseif wasd.isS() then
				cameraRotationY = cameraRotationY + cameraRotationPerTick
			end
		else
			if wasd.isW() then
				cameraPosition.x = cameraPosition.x + (math.cos(math.rad(cameraRotation)) * playerSpeed)
				cameraPosition.y = cameraPosition.y + (math.sin(math.rad(cameraRotation)) * playerSpeed)
			elseif wasd.isS() then
				cameraPosition.x = cameraPosition.x - (math.cos(math.rad(cameraRotation)) * playerSpeed)
				cameraPosition.y = cameraPosition.y - (math.sin(math.rad(cameraRotation)) * playerSpeed)
			end
		end

		if wasd.isA() then
			cameraRotation = cameraRotation + cameraRotationPerTick
		elseif wasd.isD() then
			cameraRotation = cameraRotation - cameraRotationPerTick
		end

		local left = wasd.isMouseL() or getreg("destroy_block") == 1
		if left ~= old_mouse_left then
			if left then
				destroyBlock()
			end
		end
		old_mouse_left = left

		local right = wasd.isMouseR() or getreg("spawn_block") == 1
		if right ~= old_mouse_right then
			if right then
				spawnBlock()
			end
		end
		old_mouse_right = right

		local jump = wasd.isQ() or getreg("jump") == 1
		if jump ~= old_jump then
			if touchedGround and jump then
				currentPlayerVelocity = jumpVelocity
			end
		end
		old_jump = jump
	end

	local click = display.getClick()
	if click then
		if click.state == "drag" then
			if oldClickX then
				local offsetX, offsetY = click.x - oldClickX, click.y - oldClickY
				cameraRotation = cameraRotation + ((offsetX / width) * cameraRotationPerDisplayX)
				cameraRotationY = cameraRotationY - ((offsetY / height) * cameraRotationPerDisplay)
			end
			oldClickX, oldClickY = click.x, click.y
			dragged = true
		elseif click.state == "released" then
			if not dragged then
				if click.button == 1 then
					spawnBlock()
				else
					destroyBlock()
				end
			end
			oldClickX, oldClickY = nil, nil
			dragged = false
		elseif click.state == "pressed" then
			oldClickX, oldClickY = click.x, click.y
			dragged = false
		end
	end

	if cameraRotationY < -90 then cameraRotationY = -90 end
	if cameraRotationY > 90 then cameraRotationY = 90 end

	currentPlayerVelocity = currentPlayerVelocity - playerGravity
	if currentPlayerVelocity < -1 then currentPlayerVelocity = -1 end
	
	if currentPlayerVelocity > 0 and playerCast(true) then
		currentPlayerVelocity = 0
	end
	cameraPosition.z = cameraPosition.z + currentPlayerVelocity

	local cast = playerCast(false)
	touchedGround = not not cast
	if cast then
		cameraPosition.z = cast.pointWorld.z + playerHeight
		currentPlayerVelocity = 0
	end

	if not pcall(camera.setPosition, camera, cameraPosition) then
		cameraPosition = sm.vec3.new(defaultPlayerPosition.x, defaultPlayerPosition.y, defaultPlayerPosition.z)
	end
	camera:setRotation(getCameraRotation())

	engine:tick()
	camera.api.drawAdvanced(display, renderSettings)
	display.drawCircle(width / 2, height / 2, math.min(width, height) / 32)
	display.flush()
end

function onStop()
	display.clear()
	display.flush()
end

_enableCallbacks = true