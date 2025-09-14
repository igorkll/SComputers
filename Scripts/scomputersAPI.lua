local scomputers = {}

local function clientCallcheck(functionName)
	if not sm.isServerMode() then
		sm.log.warning(functionName .. ": must be called from the client's side")
	end
end

function scomputers.addExample(name, code, architecture)
    checkArg(1, name, "string")
    checkArg(2, code, "string")
	checkArg(3, architecture, "string", "nil")
	clientCallcheck("scomputers.addExample")
    addCustomExample(name, code, architecture)
end

function scomputers.addLibrary(name, constructor)
    checkArg(1, name, "string")
    checkArg(2, constructor, "function") --function(self, env):table
    _G["sc_reglib_" .. name] = constructor
end

function scomputers.addEnvHook(envhook)
    checkArg(1, envhook, "function") --function(self, env)
    table.insert(sc.envhooks, envhook)
end

function scomputers.addClEnvHook(envhook)
	checkArg(1, envhook, "function") --function(self, env)
	clientCallcheck("scomputers.addClEnvHook")
	table.insert(sc.cl_envhooks, envhook)
end

function scomputers.require(self, name)
    if name:find("%.") or name:find("%/") or name:find("%\\") then
        error("the library name cannot contain the characters: \"/.\\\"", 2)
    end

    if not self.libcache then self.libcache = {} end
    if self.libcache[name] then return self.libcache[name] end

    --[[
    if dlm and dlm.loadfile then
        --print("loading library", name, "WITH-DLM")

        local lastId = #sc.internal_libs_folders
        for i, folder in ipairs(sc.internal_libs_folders) do
            local code, err = dlm.loadfile(folder .. "/" .. name .. ".lua", _G)
            if type(code) ~= "function" then
                if i == lastId then
                    --error("load error: " .. tostring(err or "unknown"), 2)
                    error("the \"" .. name .. "\" library was not found", 2)
                end
            else
                local result = {pcall(code)}
                if not result[1] or type(result[2]) ~= "table" then
                    error("exec error: " .. tostring(result[2] or "unknown"), 2)
                else
                    self.libcache[name] = result[2]
                    break
                end
            end
        end
    else
        --print("loading library", name, "WITHOUT-DLM")

        if not sc.internal_libs[name] then
            for _, folder in ipairs(sc.internal_libs_folders) do
                if pcall(dofile, folder .. "/" .. name .. ".lua") then
                    break
                end
            end
        end
        if not sc.internal_libs[name] then
            error("the \"" .. name .. "\" library was not found", 2)
        end
        self.libcache[name] = sc.mt_hook({__index = function(_, key)
            return sc.internal_libs[name][key]
        end})
    end
    ]]

    for _, folder in ipairs(sc.internal_libs_folders) do
        pcall(dofile, folder .. "/" .. name .. ".lua")
    end
    local libraryLoader = _G["sc_reglib_" .. name]
    if not libraryLoader then
        error("the \"" .. name .. "\" library was not found", 2)
    end
    self.libcache[name] = libraryLoader(self, self.env)
    return self.libcache[name] or error("the \"" .. name .. "\" library was not found", 2)
end

function scomputers.realIsComputerConnected(interactable)
    for _, interactable2 in ipairs(interactable:getParents()) do
        if sc.allComputersIds[interactable2.id] then
            return true
        end
    end

    for _, interactable2 in ipairs(interactable:getChildren()) do
        if sc.allComputersIds[interactable2.id] then
            return true
        end
    end

    return false
end

function scomputers.isComputerConnected(interactable)
    if sc.restrictions and sc.restrictions.disCompCheck then
        return true
    end

    return scomputers.realIsComputerConnected(interactable)
end

function scomputers.isUnsafeFeatures(interactable)
    if sc.restrictions and sc.restrictions.scriptMode == "unsafe" then
        return true
    end

    for _, interactable2 in ipairs(interactable:getParents()) do
        if interactable2.shape.uuid == sc.UNSAFE_COMPUTER_UUID then
            return true
        end
    end

    for _, interactable2 in ipairs(interactable:getChildren()) do
        if interactable2.shape.uuid == sc.UNSAFE_COMPUTER_UUID then
            return true
        end
    end

    return false
end

function scomputers.addChaffObject(position, id, mass)
    local chaffObject = {
        position = sm.vec3.new(position.x, position.y, position.z),
        move = sm.vec3.new(
            math.random(-50, 50) / 40 / 100,
            math.random(-50, 50) / 40 / 100,
            math.random(-350, -250) / 40 / 100
        ),
        id = id,
        mass = mass
    }

    if sm.isServerMode() then
        table.insert(sc.sv_chaff_objects, chaffObject)
    else
        table.insert(sc.cl_chaff_objects, chaffObject)
    end
end

function scomputers.base64_encode(data)
    return base64.encode(data, true)
end

function scomputers.base64_decode(data)
    return base64.decode(data, true)
end

function scomputers.sha256_bin(data)
    return sha256.sha256bin(data, true)
end

function scomputers.sha256_hex(data)
    return sha256.sha256hex(data, true)
end

function scomputers.md5_bin(data)
    return md5.sum(data, true)
end

function scomputers.md5_hex(data)
    return md5.sumhexa(data, true)
end

_G.scomputers = scomputers

if not __SCMFRAMEWORK then
    sm.scomputers = scomputers
end