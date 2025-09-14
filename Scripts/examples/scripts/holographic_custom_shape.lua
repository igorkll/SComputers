local holo = getComponent("holoprojector")
local uuid = "356ecbf5-d4fa-480f-8409-15d9d8add6a5" --the SComputers computer uuid
local color = "65ff1d" --the SComputers computer color

local rotation = sm.vec3.new(0, 0, 0)

function onStart()
	holo.reset()
	holo.setScale(0.25, 0.25, 0.25)
end

function onTick(dt)
	holo.clear()
	holo.addVoxel(0, 3, 0, color, uuid, nil, rotation)
	holo.flush()

	rotation.x = rotation.x + math.rad(1)
	rotation.y = rotation.y + math.rad(2)
	rotation.z = rotation.z + math.rad(3)
end

function onStop()
	holo.reset()
	holo.clear()
	holo.flush()
end

_enableCallbacks = true