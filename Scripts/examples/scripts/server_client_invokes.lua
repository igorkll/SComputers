--clientInvoke ONLY works in unsafe mode
--serverInvoke it only works from the client side and can be used to transfer data back to the server

local effectsCount = 0

local function effect_createEffect(name)
	effectsCount = effectsCount + 1
	clientInvoke("self.effectList = self.effectList or {}; table.insert(self.effectList, sm.effect.createEffect(..., self.interactable))", name)
	return effectsCount
end

local function effect_setOffsetPosition(index, position)
	clientInvoke("self.effectList = self.effectList or {}; local index, position = ... self.effectList[index]:setOffsetPosition(position)", index, position)
end

local function effect_setOffsetRotation(index, rotation)
	clientInvoke("self.effectList = self.effectList or {}; local index, rotation = ... self.effectList[index]:setOffsetRotation(rotation)", index, rotation)
end

local function effect_start(index)
	clientInvoke("self.effectList = self.effectList or {}; local index = ... self.effectList[index]:start()", index)
end

local function effect_stop(index)
	clientInvoke("self.effectList = self.effectList or {}; local index = ... self.effectList[index]:stop()", index)
end

local function effect_setParameter(index, key, value)
	clientInvoke("self.effectList = self.effectList or {}; local index, key, value = ... self.effectList[index]:setParameter(key, value)", index, key, value)
end

local function effect_setScale(index, scale)
	clientInvoke("self.effectList = self.effectList or {}; local index, scale = ... self.effectList[index]:setScale(scale)", index, scale)
end

local function clientRequest(player, callback, func, ...)
	clientInvokeTo(player, "serverInvoke(\"" .. callback .. "(...)\", " .. func .. "(...))", ...)
end

function onStart()
	effect1 = effect_createEffect("ShapeRenderable")
	effect_setOffsetPosition(effect1, sm.vec3.new(1, 1, 0))
	effect_setParameter(effect1, "uuid", sm.uuid.new("a683f897-5b8a-4c96-9c46-7b9fbc76d186"))
	effect_setParameter(effect1, "color", sm.color.new(1, 0, 0))
	effect_setScale(effect1, sm.vec3.new(2, 2, 2))
	effect_start(effect1)

	effect2 = effect_createEffect("ShapeRenderable")
	effect_setOffsetPosition(effect2, sm.vec3.new(-1, 1, 0))
	effect_setParameter(effect2, "uuid", sm.uuid.new("a683f897-5b8a-4c96-9c46-7b9fbc76d186"))
	effect_setParameter(effect2, "color", sm.color.new(0, 0, 1))
	effect_start(effect2)
end

function onTick()
	clientRequest(sm.player.getAllPlayers()[1], "cameraResponse", "sm.camera.getDirection")
end

function onStop()
	effect_stop(effect1)
	effect_stop(effect2)
end

function cameraResponse(...)
	print("cameraResponse: ", ...)
end

_enableCallbacks = true