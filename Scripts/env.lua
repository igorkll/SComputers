--dofile("$CONTENT_DATA/Scripts/externAddonAPI.lua")
dofile("$CONTENT_DATA/Scripts/defaultLibs.lua")

local function makeMsg(...)
    local printResult = ""
    local args = {...}
    local len = 0
    for i in pairs(args) do
        if i > len then
            len = i
        end
    end
    
    for i = 1, len do
        local str = tostring(args[i])
        printResult = printResult .. str
        if i ~= len then
            local strlen = #str
            local dtablen = 8
            local tablen = 0
            while tablen <= 0 do
                tablen = dtablen - strlen
                dtablen = dtablen + 8
            end
            printResult = printResult .. string.rep(" ", tablen * 2)
        end
    end

    --printResult = string.gsub(printResult, "\n", "%[NL%]")
    return printResult
end

local function log(self, ...)
    local msg = makeMsg(...)
    if sm.isServerMode() then
        if not self.logMsg then self.logMsg = {} end
        table.insert(self.logMsg, msg)
    else
        sc.lastComputer:cl_logMessage(msg)
    end
end

local function warning(self, msg)
    log(self, "#d69201WARNING: " .. tostring(msg))
end

local function checkAllowMessage(self, methodName)
    if not self.localScriptMode.allowChat then
        --error("print/alert/debug methods are disabled", 3)
        warning(self, "'" .. methodName .. "' has been disabled in the Permission Tool")
    end
    return self.localScriptMode.allowChat
end

local function isolationCheck(isolation)
    if isolation then
        error("this feature is disabled for an isolated environment", 3)
    end
end

function addEnvBetterAPIFeatures(self, env)
	local coroutine = sc.getApi("coroutine")
    if coroutine and sc.coroutineFixed() then
        env.coroutine = {
            create = coroutine.create,
            status = coroutine.status,

            running = function()
                local th = coroutine.running()
                if self.th and th == self.th then
                    return
                end
                return th
            end,
            
            resume = function(co, ...)
                checkArg(1, co, "thread")
                local args = table.pack(...)
                while true do
                    local result = table.pack(
                    coroutine.resume(co, table.unpack(args, 1, args.n)))
                    if result[1] then
                        if coroutine.status(co) == "dead" then
                            return true, table.unpack(result, 2, result.n)
                        elseif result[2] ~= nil then
                            args = table.pack(coroutine.yield(result[2]))
                        else
                            return true, table.unpack(result, 3, result.n)
                        end
                    else
                        return false, result[2]
                    end
                end
            end,
            
            wrap = function(f) -- for bubbling coroutine.resume
                local co = coroutine.create(f)
                return function(...)
                    local result = table.pack(env.coroutine.resume(co, ...))
                    if result[1] then
                        return table.unpack(result, 2, result.n)
                    else
                        error(result[2], 0)
                    end
                end
            end,

            yield = function(...)
                return coroutine.yield(nil, ...)
            end
        }

        function env.sleep(ticks)
            sc.selfCoroutineCheck(self)
            coroutine.yield(ticks)
        end
    end

    if better and better.isAvailable() then
        env.os.date = env.os.date or better.date
    end
end

function addEnvLuaCompatibilityFeatures(self, env)
	env.table.unpack = env.unpack
    
    function env.math.tointeger(x)
        local num = tonumber(x)
        if num then
            local v1, v2 = math.modf(num)
            if v2 == 0 then
                return v1
            end
        end
    end

    function env.math.type(x)
        if type(x) == "number" then
            local v1, v2 = math.modf(x)
            if v2 == 0 then
                return "integer"
            else
                return "float"
            end
        end
    end

    function env.math.ult(m, n)
        local _, v1 = math.modf(m)
        local _, v2 = math.modf(n)
        if v1 ~= 0 then
            error("bad argument #1 to 'ult' (number has no integer representation)", 2)
        end
        if v2 ~= 0 then
            error("bad argument #2 to 'ult' (number has no integer representation)", 2)
        end
        return m < n
    end
end

function envLuaLibTweaks(self, env)
	env.math.randomseed = nil --this method is not in the game, but if it is added, it STILL should not be in SComputers
    if isTweaksAvailable() then
        env.string.rep = customRep --in the case of ("str").rep(), the "tweaks" method in the "methods.lua" file will work
    end
end

function envBase(self, env, fromProcessLibrary, isolation)
	env._VERSION = sc.restrictions.vm
	env.checkArg = checkArg --это не стандартный метод lua он был взят из opencomputers(machine.lua) и определен в methods.lua

	local bit32 = _G.bit32 or _G.bit --я знаю что это странно
    local bit = _G.bit or _G.bit32
    local pcall, xpcall = pcall, xpcall

    env.isBetterAPI = function()
        return not not (better and better.isAvailable())
    end

	env.class = function (super) --custom class function(more secure, does not allow access to setmetatable)
		local class = sc.mt_hook({__call = function(class)
			local obj = {}
			for k, v in pairs(class) do
				obj[k] = v
			end
			return obj
		end})
	
		if super then
			for k,v in pairs(super) do
				class[k] = v
			end
			class.super = super
		end
	
		return class
	end

	env.alert = function (...)
        isolationCheck(isolation)
		if self.storageData and self.storageData.dislogs then return end
		sc.coroutineCheck()
		if checkAllowMessage(self, "alert") then
			local msg = makeMsg(...)
			if sm.isServerMode() then
				--sc.lastComputer.network:sendToClients("cl_alertMessage", msg)
				if not self.alertMsg then self.alertMsg = {} end
				table.insert(self.alertMsg, msg)
			else
				sc.lastComputer:cl_alertMessage(msg)
			end
		end
	end

	env.print = function (...)
        isolationCheck(isolation)
		if self.storageData and self.storageData.dislogs then return end
		sc.coroutineCheck()
		if checkAllowMessage(self, "print") then
			local msg = makeMsg(...)
			if sm.isServerMode() then
				--sc.lastComputer.network:sendToClients("cl_chatMessage", msg)
				if not self.printMsg then self.printMsg = {} end
				table.insert(self.printMsg, msg)
			else
				sc.lastComputer:cl_chatMessage(msg)
			end
		end
	end

	env.debug = function (...)
        isolationCheck(isolation)
		if self.storageData and self.storageData.dislogs then return end
		if checkAllowMessage(self, "debug") then
			print(...)
		end
	end

	env.log = function(...)
        isolationCheck(isolation)
		if self.storageData and self.storageData.dislogs then return end
		sc.coroutineCheck()
		log(self, ...)
	end

	env.logPrint = function(...)
        isolationCheck(isolation)
		if self.storageData and self.storageData.dislogs then return end
		sc.coroutineCheck()
		if self.localScriptMode.allowChat then
			local msg = makeMsg(...)
			if sm.isServerMode() then
				if not self.printMsg then self.printMsg = {} end
				table.insert(self.printMsg, msg)
			else
				sc.lastComputer:cl_chatMessage(msg)
			end
		end
		log(self, ...)
	end

	env.warning = function(msg)
        isolationCheck(isolation)
		if self.storageData and self.storageData.dislogs then return end
		sc.coroutineCheck()
		warning(self, msg)
	end

	env.tostring = tostring
	env.tonumber = tonumber
	env.type = type

	env.utf8 = sc.deepcopy(utf8)
	env.string = sc.deepcopy(defaultLibs.string)
	env.table = sc.deepcopy(defaultLibs.table)
	env.math = sc.deepcopy(defaultLibs.math)
	env.bit = sc.deepcopy(bit)
	env.bit32 = sc.deepcopy(bit32)

	env.os = {
		clock = os.clock,
		date = os.date, --os.data is not in Scrap Mechanic, but if it appears, it will appear in SComputers
		difftime = os.difftime,
		--execute = os.execute,
		--exit = os.exit,
		--getenv = os.getenv,
		--remove = os.remove,
		--rename = os.rename,
		--setlocale = os.setlocale,
		time = os.time,
		--tmpname = os.tmpname
	}

	env.assert = assert
	env.error = error
	env.ipairs = ipairs
	env.pairs = pairs
	env.next = next
	env.select = select
	env.unpack = unpack

	env.pcall = function (...)
		sc.yield()
		local ret = {pcall(...)}
		sc.yield()
		return unpack(ret)
	end

	env.xpcall = function (...)
		sc.yield()
		local ret = {xpcall(...)}
		sc.yield()
		return unpack(ret)
	end

	env.load = function (chunk, chunkname, mode, lenv)
		return safe_load_code(self, chunk, chunkname, mode, lenv or env)
	end

	env.loadstring = function (chunk, lenv)
		local ret = {safe_load_code(self, chunk, nil, "t", lenv or env)}
		if not ret[1] then
			error(ret[2], 2)
		end
		return unpack(ret)
	end

	env.execute = function (chunk, lenv, ...)
		local ret = {safe_load_code(self, chunk, nil, "t", lenv or env)}
		if not ret[1] then
			error(ret[2], 2)
		end
		return ret[1](...)
	end
end

function createSafeEnv(self, settings, fromProcessLibrary, isolation)
    --методы ninput, input, getChildComputers, getParentComputers были переделанны на ipairs вместо pairs
    --чтобы сохранялся порядок подключений

    local localLibs = {}
    local requireSelf = self
    if isolation then
        requireSelf = {realself = self} --we use a separate library cache for an isolated environment
    end

	local env
	env = {
        require = function (name)
            checkArg(1, name, "string")
            sc.coroutineCheck()
            if localLibs[name] then
                return localLibs[name]
            end
            return scomputers.require(requireSelf, name)
        end,

		getmetatable = function (t) return t.__metatable or {} end,
		setmetatable = function (t1, t2) t1.__metatable = t2 end,

        sm = {
            vec3 = sc.deepcopy(sm.vec3),
            util = sc.deepcopy(sm.util),
            quat = sc.deepcopy(sm.quat),
            noise = sc.deepcopy(sm.noise),
            color = sc.deepcopy(sm.color),
            uuid = sc.deepcopy(sm.uuid),
            json = {
                parseJsonString = function (str)
                    checkArg(1, str, "string")
                    return sm.json.parseJsonString(str)
                end,
                writeJsonString = function (obj)
                    checkArg(1, obj, "table")
                    jsonEncodeInputCheck(obj, 0)
                    return sm.json.writeJsonString(obj)
                end,
            },
            game = {
                getCurrentTick = sm.game.getCurrentTick,
                getServerTick = sm.game.getServerTick
            },
            projectile = {
                solveBallisticArc = sm.projectile.solveBallisticArc
            }
        },

        encryptCode = function(message)
            checkArg(1, message, "string", "nil")
            isolationCheck(isolation)
            if self.storageData.encryptCode then
                return false
            end
            if self.new_code then
                self.storageData.script = self.new_code
                self.new_code = nil
            end
            self.encrypt_flag = true
            self.encrypt_msg = message
            return true
        end,
        isCodeEncrypted = function()
            isolationCheck(isolation)
            return not not self.storageData.encryptCode
        end,

        getreg = function (n)
            isolationCheck(isolation)
            return self.registers[n]
        end,
        setreg = function (n, v)
            isolationCheck(isolation)
            if type(v) == "boolean" or type(v) == "number" then
                self.registers[n] = v
            else
                error("Value must be number or boolean", 2)
            end
        end,

        out = function (p)
            sc.coroutineCheck()
            isolationCheck(isolation)
            if not self.interactable then return end

            if type(p) == "number" then
                self.currentOutputActive = p ~= 0
                self.currentOutputPower = p
                self.interactable:setActive(p ~= 0)
                self.interactable:setPower(p)
            elseif type(p) == "boolean" then
                self.currentOutputActive = p
                self.currentOutputPower = p and 1 or 0
                self.interactable:setActive(p)
                self.interactable:setPower(p and 1 or 0)
            else
                error("Type must be number or boolean", 2)
            end
        end,

        input = function (color)
            sc.coroutineCheck()
            isolationCheck(isolation)
            if not self.interactable then return false end

            if color then
                color = sc.formatColorStr(color)
                
                for i, v in ipairs(self.interactable:getParents(sm.interactable.connectionType.logic)) do
                    local p_color = sc.formatColorStr(v.shape.color)
                    
                    if p_color == color and v:isActive() then
                        return true
                    end
                end
            else
                for i, v in ipairs(self.interactable:getParents(sm.interactable.connectionType.logic)) do
                    if v:isActive() then
                        return true
                    end
                end
            end
            return false
        end,

        ninput = function (color)
            sc.coroutineCheck()
            isolationCheck(isolation)
            if not self.interactable then return {} end

            if color then
                color = sc.formatColorStr(color)

                local out = {}
                for i, v in ipairs(self.interactable:getParents()) do
                    local p_color = sc.formatColorStr(v.shape.color)
                    if p_color == color then
                        table.insert(out, v:getPower())
                    end
                end
                return out
            else
                local out = {}
                for i, v in ipairs(self.interactable:getParents()) do
                    table.insert(out, v:getPower())
                end
                return out
            end
        end,

        clearregs = function ()
            isolationCheck(isolation)
            for k in pairs(self.registers) do
                self.registers[k] = nil
            end
        end,

        getParentComputers = function ()
            sc.coroutineCheck()
            isolationCheck(isolation)
            if not self.interactable then return {} end

            local ret = {}
            local datas = sc.computersDatas
            for i, v in ipairs(self.interactable:getParents(sm.interactable.connectionType.composite)) do
                local data = datas[v:getId()]
                if data and not data.self.storageData.invisible and data.public then
                    table.insert(ret, data.public)
                end
            end
            return ret
        end,

        getChildComputers = function ()
            sc.coroutineCheck()
            isolationCheck(isolation)
            if not self.interactable then return {} end
            
            local ret = {}
            local datas = sc.computersDatas
            for i, v in ipairs(self.interactable:getChildren(sm.interactable.connectionType.composite)) do
                local data = datas[v:getId()]
                if data and not data.self.storageData.invisible and data.public then
                    table.insert(ret, data.public)
                end
            end
            return ret
        end,
        

		setLock = function (state)
            checkArg(1, state, "boolean", "nil")
            isolationCheck(isolation)
            self.storageData.__lock = not not state
		end,
        getLock = function ()
            isolationCheck(isolation)
			return not not self.storageData.__lock
		end,



        setCode = function (code)
            checkArg(1, code, "string")
            if #code > self.maxcodesize then
                error(self.maxCodeSizeStr, 2)
            end
            isolationCheck(isolation)
            self.storageData.encryptCode = false
            self.storageData.encryptedCode = nil
            self.new_code = code
        end,
        getCode = function ()
            isolationCheck(isolation)
            return self.storageData.script or ""
        end,

        setEncryptedCode = function(bytecode, message)
            checkArg(1, bytecode, "string")
            checkArg(2, message, "string", "nil")
            isolationCheck(isolation)
            if #bytecode > self.maxcodesize then
                error(self.maxCodeSizeStr, 2)
            end
            self.storageData.encryptCode = false
            self.storageData.encryptedCode = nil
            self.new_ecode = bytecode
            self.new_ecode_msg = message
        end,


        setData = function (data)
            checkArg(1, data, "string")
            if #data > (1024 * 4) then
                error("the maximum userdata size is 4KB", 2)
            end
            isolationCheck(isolation)
            self.storageData.userdata = base64.encode(data)
            self.storageData.userdata_bs64 = true
        end,
        getData = function ()
            isolationCheck(isolation)
            if self.storageData.userdata then
                if self.storageData.userdata_bs64 then
                    return (base64.decode(self.storageData.userdata))
                else
                    return self.storageData.userdata
                end
            else
                return ""
            end
        end,
        setTable = function(tbl)
            checkArg(1, tbl, "table")
            env.setData(json.encode(tbl))
        end,
        getTable = function()
            local ok, tbl = pcall(json.decode, env.getData())
            if ok and type(tbl) == "table" then
                return tbl
            end
            return {}
        end,
        


        setInvisible = function (state) --when you turn on your computer, it will be impossible to detect using getParentComputers and getChildComputers. however, you can still provide the API using setComponentApi
            checkArg(1, state, "boolean", "nil")
            isolationCheck(isolation)
            self.storageData.invisible = not not state
        end,
        getInvisible = function ()
            isolationCheck(isolation)
            return not not self.storageData.invisible
        end,



        setAlwaysOn = function (state)
            checkArg(1, state, "boolean")
            isolationCheck(isolation)
            self.storageData.alwaysOn = state
        end,
        getAlwaysOn = function ()
            isolationCheck(isolation)
            return not not self.storageData.alwaysOn
        end,



        setComponentApi = function (name, api)
            checkArg(1, name, "string", "nil")
            checkArg(2, api,  "table",  "nil")
            isolationCheck(isolation)
            if name and api then
                self.customcomponent_name = name
                self.customcomponent_api = api
            end
            self.customcomponent_flag = true
        end,
        getComponentApi = function ()
            isolationCheck(isolation)
            return self.customcomponent_name, self.customcomponent_api
        end,


        
        reboot = function ()
            isolationCheck(isolation)
            if self.storageData.noSoftwareReboot then
                error("this computer cannot be restarted programmatically", 2)
                return
            end
            
            self.software_reboot_flag = true
        end,
        getCurrentComputer = function ()
            isolationCheck(isolation)
            return self.publicTable.public
        end,
        getComponents = function (name)
            checkArg(1, name, "string")
            sc.coroutineCheck()
            isolationCheck(isolation)
            return sc.getComponents(self, name, settings)
        end,
        getComponent = function(name)
            checkArg(1, name, "string")
            sc.coroutineCheck()
            isolationCheck(isolation)
            local components = sc.getComponents(self, name, settings)
            if #components > 0 then
                return components[1]
            else
                error("the \"" .. name .. "\" component is missing", 2)
            end
        end,
        getMaxAvailableCpuTime = function ()
            return round(self.localScriptMode.cpulimit or sc.restrictions.cpu, 5)
        end,

        getDeltaTime = function ()
            return sc.deltaTime or 0
        end,
        getDeltaTimeTps = function ()
            return sc.deltaTimeTps or 0
        end,

        getSkippedTicks = function ()
            return self.skipped or 0
        end,
        getLagScore = function ()
            return self.lagScore or 0
        end,
        getUptime = function ()
            return self.uptime or 0
        end,
        getTick = function ()
            return self.computerTick or 0
        end,

        getDeviceType = function()
            isolationCheck(isolation)
            if self.interactable then
                return "computer"
            elseif self.tool then
                return "tablet"
            else
                return "unknown"
            end
        end,

        --limitations of the amount of RAM in development
        getUsedRam = function ()
            return self.usedRam or 0
        end,
        getTotalRam = function ()
            return self.cdata.ram or 0
        end,

        isComponentAvailable = function(componentTable)
            checkArg(1, componentTable, "table")
            return (not not pcall(componentTable[1]))
        end,

        getMotorByLabel = function(label)
            checkArg(1, label, "string")
            sc.coroutineCheck()
            isolationCheck(isolation)
            local components = env.getMotorsByLabel(label)
            if #components > 0 then
                return components[1]
            else
                error("there is no \"motor\" with the \"" .. label .."\" label", 2)
            end
        end,
        getMotorsByLabel = function(label)
            checkArg(1, label, "string")
            sc.coroutineCheck()
            isolationCheck(isolation)
            return sc.getComponents(self, "motor", settings, function (publicData)
                return publicData and publicData.label == label
            end)
        end,

        getComponentByLabel = function(componentType, label)
            checkArg(1, componentType, "string")
            checkArg(2, label, "string")
            sc.coroutineCheck()
            isolationCheck(isolation)
            local components = env.getComponentsByLabel(componentType, label)
            if #components > 0 then
                return components[1]
            else
                error("there is no \"" .. componentType .."\" with the \"" .. label .."\" label", 2)
            end
        end,
        getComponentsByLabel = function(componentType, label)
            checkArg(1, componentType, "string")
            checkArg(2, label, "string")
            isolationCheck(isolation)
            sc.coroutineCheck()
            if componentType == "motor" then
                return env.getMotorsByLabel(label)
            else
                return sc.getComponents(self, componentType, settings, function (publicData)
                    if not publicData or not publicData.sc_component or not publicData.sc_component.label then
                        return false
                    end
                    return publicData.sc_component.label() == label
                end)
            end
        end
	}
	envBase(self, env, fromProcessLibrary, isolation)

    if isolation then
        requireSelf.env = env
    end

    ---------------- better api

    addEnvBetterAPIFeatures(self, env)

    ---------------- compatibility with new versions of lua

    addEnvLuaCompatibilityFeatures(self, env)

    ---------------- links

    env._G = env
    env._ENV = env
    env.sci = env --для совместимости

    ---------------- legacy
    
    env.getDisplays = function ()
        return env.getComponents("display")
    end

    env.getMotors = function ()
        return env.getComponents("motor")
    end
    
    env.getRadars = function ()
        return env.getComponents("radar")
    end
    
    env.getPorts = function ()
        return env.getComponents("port")
    end

    env.getDisks = function ()
        return env.getComponents("disk")
    end

    env.getCameras = function ()
        return env.getComponents("camera")
    end

    env.getHoloprojectors = function ()
        return env.getComponents("holoprojector")
    end

    env.getSynthesizers = function ()
        return env.getComponents("synthesizer")
    end

    env.getLeds = function ()
        return env.getComponents("led")
    end

    env.getKeyboards = function ()
		return env.getComponents("keyboard")
	end

    env.getParentComputersData = env.getParentComputers
    env.getChildComputersData = env.getChildComputers
    env.getConnectedDisplaysData = env.getDisplays
    env.getConnectedMotorsData = env.getMotors
    env.getConnectedRadarsData = env.getRadars

    env.getLagsScore = env.getLagScore

    ---------------- safety

    if env.coroutine and not sc.coroutineFixed() then
        local function disableCoroutine(api)
            for funcname, func in pairs(api) do
                api[funcname] = function (...)
                    sc.coroutineCheck()
                    local result = {pcall(func, ...)}
                    if result[1] then
                        return unpack(result, 2)
                    else
                        error(result[2], 2)
                    end
                end
            end
        end

        for apiname, api in pairs(env.sm) do
            disableCoroutine(api) --you can't call scrapmechanic methods from coroutine because it calls bugsplat
        end
    end

    local positiveModulo = sm.util.positiveModulo
    env.sm.util.positiveModulo = function (x, n) --для предотвашения bugsplat
        checkArg(1, x, "number")
        checkArg(2, n, "number")
        if n ~= 0 and math.floor(n) == n then
            return positiveModulo(x, n)
        end
        error("cannot be divided by " .. (tostring(n) or ""), 2)
    end

    envLuaLibTweaks(self, env)

    do
        local whook = "withoutHook_"
        local tblChecked = {}
        local function deleteFunctionsWithoutHook(tbl)
            if tblChecked[tbl] then
                return
            end
            tblChecked[tbl] = true

            for key, value in pairs(tbl) do
                if type(key) == "string" and key:sub(1, #whook) == whook then
                    tbl[key] = nil
                else
                    local t = type(value)
                    if t == "table" then
                        deleteFunctionsWithoutHook(value)
                    end
                end
            end
        end
        deleteFunctionsWithoutHook(env)
    end

    localLibs.utf8 = env.utf8
    localLibs.math = env.math
    localLibs.string = env.string
    localLibs.table = env.table
    localLibs.os = env.os
    localLibs.bit = env.bit
    localLibs.bit32 = env.bit32

    ---------------- env hooks

    for i, hook in ipairs(sc.envhooks) do
        print("envhook (" .. i .."): ", pcall(hook, self, env))
    end

    if self.defaultData.localEnvHook then --can be set when using scmframework
        self.defaultData.localEnvHook(self, env)
    end

	return env
end

function createUnsafeEnv(self, settings, fromProcessLibrary, isolation)
	local env = createSafeEnv(self, settings, fromProcessLibrary, isolation)

	env.global = _G
	env.self = self
	env.sm = sm
    env.dlm = dlm

    env.clientInvoke = function (code, ...)
        checkArg(1, code, "string")
        table.insert(self.clientInvokes, {code, self.localScriptMode.scriptMode ~= "unsafe", {...}, self.rebootId})
    end

    env.clientInvokeTo = function (player, code, ...)
        checkArg(1, player, "string", "Player")
        checkArg(2, code, "string")
        table.insert(self.clientInvokes, {code, self.localScriptMode.scriptMode ~= "unsafe", {...}, self.rebootId, player = player})
    end

	return env
end

function createClientEnv(self)
	local env = {}

	envBase(self, env)

	env.global = _G
	env.self = self
	env.sm = sm
    env.dlm = dlm

	env.serverInvoke = function (code, ...)
        checkArg(1, code, "string")
        table.insert(self.serverInvokes, {code, {...}})
    end

	addEnvBetterAPIFeatures(self, env)
    addEnvLuaCompatibilityFeatures(self, env)
	envLuaLibTweaks(self, env)

	for i, hook in ipairs(sc.cl_envhooks) do
        print("client envhook (" .. i .."): ", pcall(hook, self, env))
    end

    if self.defaultData.localEnvHook then --can be set when using scmframework
        self.defaultData.localEnvHook(self, env)
    end

	return env
end