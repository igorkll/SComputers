dofile "$CONTENT_DATA/Scripts/Config.lua"

sc.radar = {}

clamp = sm.util.clamp

function radar_needRaycast(direction, halfHcos, halfVcos) -- self pos is (0, 0, 0)
	-- forward direction is (-1, 0, 0)
	-- up direction is (0, 1, 0)
	local dX = direction.x
	local dZ = direction.z

	local xzLen = math.sqrt(dX * dX + dZ * dZ)

	local hdot = clamp(-dX / xzLen, -1, 1) -- clamp because if > 1 acos is nan
	local vdot = clamp((dX*dX + dZ*dZ) / xzLen, -1, 1) -- vec(dX, 0, dZ).normalized().dot( vec(dX, dY, dZ) )

	return hdot >= halfHcos and vdot >= halfVcos
end

function radar_getAngles(direction)
	local dX = direction.x
	local dZ = direction.z

	local xzLen = math.sqrt(dX * dX + dZ * dZ)

	local hdot = clamp(-dX / xzLen, -1, 1)
	local vdot = clamp((dX*dX + dZ*dZ) / xzLen, -1, 1)

	local acos = math.acos

	return acos(hdot) * (direction.z <= 0 and 1 or -1), acos(vdot) * (direction.y >= 0 and 1 or -1)
end

function sc.radar.createRadar(scriptableObject, hResol, vResol, hFov, vFov, minDetectionMassRatio)
	return {
		hResol = hResol,
		vResol = vResol,
		hFov = hFov,
		vFov = vFov,
		angle = 0,
        vAngle = 0,
		scriptableObject = scriptableObject,
		minDetectionMassRatio = minDetectionMassRatio
	}
end

function sc.radar.createData(self)
	return {
		getTargets = function () --> {hangle, vangle, distance}
			local tick = sm.game.getCurrentTick()
			if tick == self.old_tick and not sc.restrictions.disableCallLimit then
				error("getTargets can only be used 1 time per tick on one radar", 2)
			end
			self.old_tick = tick

			return sc.radar.server_makeCasts(self)
		end,

		setAngle = function (a) 
			if type(a) == "number" then
				self.angle = a
			else
				error("Type must be number", 2)
			end
		end,
		getAngle = function () return self.angle end,

        setVAngle = function (a) 
			if type(a) == "number" then
				self.vAngle = a
			else
				error("Type must be number", 2)
			end
		end,
		getVAngle = function () return self.vAngle end,

		setHFov = function (a)
			if type(a) == "number" then
				local pi = math.pi

				if a >= -pi and a <= pi then
					self.hFov = a
				else
					error("Angle must be in [0, pi]", 2)
				end
			else
				error("Type must be number", 2)
			end
		end,
		getHFov = function () return self.hFov end,

		setVFov = function (a)
			if type(a) == "number" then
				local pi = math.pi

				if a >= -pi and a <= pi then
					self.vFov = a
				else
					error("Angle must be in [0, pi]", 2)
				end
			else
				error("Type must be number", 2)
			end
		end,
		getVFov = function () return self.vFov end,
	}
end

local function checkChaffCollision(pos1, pos2)
    for _, chaffObjects in ipairs(sc.sv_chaff_objects) do
        if doesRayIntersectSphere(pos1, pos2, chaffObjects.position, sc.chaff_real_size) then
            return true
        end
    end
end

local zero = sm.vec3.zero()
function sc.radar.server_makeCasts(self) --> table[hResol, vResol]
	local hFov = self.hFov
	local vFov = self.vFov
	local hResol = self.hResol
	local vResol = self.vResol
	local angle = self.angle
    local vAngle = self.vAngle

	local minDetectionMassRatio = self.minDetectionMassRatio

	local quatOffset = sm.quat.angleAxis(angle, sm.vec3.new(0, 1, 0))
    local vQuatOffset = sm.quat.angleAxis(vAngle, sm.vec3.new(0, 0, 1))

	local shape = self.scriptableObject.shape
	local sbody = shape.body
	local sbodyId = sbody:getId()

	local sgpos = shape:getWorldPosition()

	local hAngleStep = hFov / hResol
	local vAngleStep = vFov / vResol

	local halfHcos = math.cos(hFov / 2)
	local halfVcos = math.cos(vFov / 2)
	
	local raycast = sm.physics.raycast

	local points = {} -- pointData = { id, x, y, distance, force }

	--local insert = table.insert
	local floor = math.floor
	local insert = table.insert
	local fmod = math.fmod
	local pi = math.pi

	local random = math.random

	local genNoise
	if self.scriptableObject.unrestricted then
		genNoise = function (a)
			return 0
		end
	else
		genNoise = function (a)
			return random() * a - a / 2
		end
	end

    local ctick = sm.game.getCurrentTick()
	local bodies = sm.body.getAllBodies()
	for i = 1, #bodies do
		local body = bodies[i]

		local id = body:getId()

		if id ~= sbodyId then
			local gpos
			if body:isStatic() then
				gpos = body:getShapes()[1].worldPosition
			else
				gpos = body:getCenterOfMassPosition()
			end

			local lpos = vQuatOffset * quatOffset * shape:transformPoint(gpos)
			local dir = lpos:normalize()

			local len = (sgpos - gpos):length()

			local massRatio = body:getMass() / len

			if massRatio >= minDetectionMassRatio and radar_needRaycast(dir, halfHcos, halfVcos) and not checkChaffCollision(sgpos, gpos) then
                local valid, data = raycast(sgpos, gpos, sbody)
                local b = data:getBody()

                if valid and b and b:getId() == body:getId() then
                    local hangle, vangle = radar_getAngles(dir)

                    local hcoord = floor( hangle / hAngleStep + 0.5 )
                    local vcoord = floor( vangle / vAngleStep + 0.5 )
                    local pos = hcoord + vcoord * vResol

                    if not sc.radarDetectedBodies[b.id] then sc.radarDetectedBodies[b.id] = {} end
                    sc.radarDetectedBodies[b.id][self] = {ctick + 40, sgpos, {}}

                    local d = points[pos]
                    if d == nil then
                        points[pos] = {
                            x = hcoord,
                            y = vcoord,

                            distance = len,
                            force = massRatio / minDetectionMassRatio,
                            id = id,
                            type = "body"
                        }
                    else
                        if d.distance > len then
                            d.distance = len
                            d.id = id
                            d.force = massRatio / minDetectionMassRatio
                        end
                    end
                end
			end
		end
	end

	local characters = {}
	for index, value in ipairs(sm.player.getAllPlayers()) do
		table.insert(characters, value.character)
	end
	for index, value in ipairs(sm.unit.getAllUnits()) do
		table.insert(characters, value.character)
	end

	for i = 1, #characters do
		local character = characters[i]

		local id = character:getId()

		local gpos = character:getWorldPosition()

		local lpos = vQuatOffset * quatOffset * shape:transformPoint(gpos)
		local dir = lpos:normalize()

		local len = (sgpos - gpos):length()
		local massRatio = character:getMass() / len

		if massRatio >= minDetectionMassRatio and radar_needRaycast(dir, halfHcos, halfVcos) and not checkChaffCollision(sgpos, gpos) then
			local valid, data = raycast(sgpos, gpos, sbody)
			local p = data:getCharacter()

			if valid and p and p:getId() == character:getId() then
				local hangle, vangle = radar_getAngles(dir)

				local hcoord = floor( hangle / hAngleStep + 0.5 )
				local vcoord = floor( vangle / vAngleStep + 0.5 )
				local pos = hcoord + vcoord * vResol

				local d = points[pos]

				if d == nil then
					points[pos] = {
						x = hcoord,
						y = vcoord,

						distance = len,
						force = massRatio / minDetectionMassRatio,
						id = id,
						type = "character"
					}
				else
					if d.distance > len then
						d.distance = len
						d.id = id
						d.force = massRatio / minDetectionMassRatio
					end
				end
			end
		end
	end

    for i = 1, #sc.sv_chaff_objects do
		local chaffObject = sc.sv_chaff_objects[i]
		local id = chaffObject.id
		local gpos = chaffObject.position

		local lpos = vQuatOffset * quatOffset * shape:transformPoint(gpos)
		local dir = lpos:normalize()

		local len = (sgpos - gpos):length()
		local massRatio = chaffObject.mass / len

		if massRatio >= minDetectionMassRatio and radar_needRaycast(dir, halfHcos, halfVcos) then
			if not raycast(sgpos, gpos, sbody) then
				local hangle, vangle = radar_getAngles(dir)

				local hcoord = floor( hangle / hAngleStep + 0.5 )
				local vcoord = floor( vangle / vAngleStep + 0.5 )
				local pos = hcoord + vcoord * vResol

				local d = points[pos]

				if d == nil then
					points[pos] = {
						x = hcoord,
						y = vcoord,

						distance = len,
						force = massRatio / minDetectionMassRatio,
						id = id,
						type = "body"
					}
				else
					if d.distance > len then
						d.distance = len
						d.id = id
						d.force = massRatio / minDetectionMassRatio
					end
				end
			end
		end
	end

	local result = {} -- [{ id, hangle, vangle, dist, force }]
	local pi2 = pi * 2
	local error = (1 / hResol + 1 / vResol) / 2

	for k, v in pairs(points) do
		local hangle = v.x * hAngleStep + angle + genNoise(hAngleStep)
		hangle = fmod(hangle + pi, pi2) - pi

		local vangle = v.y * vAngleStep + genNoise(vAngleStep)
		vangle = fmod(vangle + pi, pi2) - pi
		
		local distance = v.distance
		distance = distance + genNoise(error * distance)

		local force = v.force
		force = force + genNoise(error * force)

		insert(result, {
			v.id,
			hangle,
			vangle,
			distance,
			force,
			v.type,

            id = v.id,
            hangle = hangle,
            vangle = vangle,
            distance = distance,
            force = force,
            type = v.type
		})
	end

    tableShuffle(result)

	return result
end

function sc.radar.server_onTick(self)
	
end

function sc.radar.server_onCreate(self)
	sc.radarsDatas[self.scriptableObject.interactable:getId()] = sc.radar.createData(self)
end

function sc.radar.server_onDestroy(self)
	sc.radarsDatas[self.scriptableObject.interactable:getId()] = nil
end