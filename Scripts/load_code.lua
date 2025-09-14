local pcall, xpcall, unpack, error, pairs, type = pcall, xpcall, unpack, error, pairs, type

function addServiceCode(self, code, env, serviceTable)
	local computer = self
	local yieldName = self.yieldName
	--local yieldArg = "null"

	local yield
	if sm.isServerMode() then
		yield = self.sv_yield
	else
		yield = self.cl_yield
	end
	
	local function local_yield(arg, locals)
		yield(self)
	end

	if env then
		local setmetatable = sc.getApi("setmetatable")
		local getmetatable = sc.getApi("getmetatable")
		if setmetatable and getmetatable and pcall(setmetatable, {}, {}) and pcall(getmetatable, {}) then
			setmetatable(env, nil)
			env[yieldName] = nil
			setmetatable(env,
				{
					__index = {
						[yieldName] = local_yield
					},
					__newindex = function (self, key, value)
						if key == yieldName then
							error("failed to rewrite a mod-protected function", 2)
						end

						local mt = getmetatable(self)
						setmetatable(self, nil)
						self[key] = value
						setmetatable(self, mt)
					end
				}
			)
		else
			env[yieldName] = local_yield
		end
	end

	if serviceTable then
		serviceTable.yield = local_yield
		--serviceTable.yieldArg = yieldArg
	end

	--------------------------------

	local patterns = {
		--[[
		{ "if([ %(])(.-)([ %)])then([ \n])", "if%1%2%3then%4__internal_yield() " },
		{ "elseif([ %(])(.-)([ %)])then([ \n])", "elseif%1%2%3then%4__internal_yield() " },
		{ "([ \n])else([ \n])", "%1else%2__internal_yield() " },--]]
		{"([%);\n ])do([ \n%(])", "%1do%2 " .. yieldName .. "() "},
		{"([%);\n ])repeat([ \n%(])", "%1repeat%2 " .. yieldName .. "() "},
		{"([%);\n ])goto([ \n%(])", " " .. yieldName .. "() %1goto%2"},
		{"([%);\n ])until([ \n%(])", " " .. yieldName .. "() %until%2"},
		--{"([%);\n ])?)([ \n%(])", "%1?)%2__internal_yield() "} --пожалуй лишнее
	}

	local function gsub(s)
		for i = 1, #patterns, 1 do
			s = s:gsub(patterns[i][1], patterns[i][2])
		end
		return s
	end

	local function process(code)
		local wrapped = ""
		local in_str = false

		while #code > 0 do
			if not (code:find('"', nil, true) or code:find("'", nil, true) or code:find("[", nil, true)) then
				wrapped = wrapped .. gsub(code)
				break
			end

			local chunk, quote = code:match('(.-)([%["\'])')
			code = code:sub(#chunk + 2)

			if quote == '"' or quote == "'" then
				if in_str == quote then
					in_str = false
					wrapped = wrapped .. chunk .. quote
				elseif not in_str then
					in_str = quote
					wrapped = wrapped .. gsub(chunk) .. quote
				else
					wrapped = wrapped .. gsub(chunk) .. quote
				end
			elseif quote == "[" then
				local prefix = "%]"
				if code:sub(1, 1) == "[" then
					prefix = "%]%]"
					code = code:sub(2)
					wrapped = wrapped .. gsub(chunk) .. quote .. "["
				elseif code:sub(1, 1) == "=" then
					local pch = code:find("(=-%[)")
					if not pch then -- syntax error
						return wrapped .. chunk .. quote .. code
					end
					local e = code:sub(1, pch)
					prefix = prefix .. e .. "%]"
					code = code:sub(pch + #e + 1)
					wrapped = wrapped .. gsub(chunk) .. "[" .. e .. "["
				else
					wrapped = wrapped .. gsub(chunk) .. quote
				end

				if #prefix > 2 then
					local strend = code:match(".-" .. prefix)
					code = code:sub(#strend + 1)
					wrapped = wrapped .. strend
				end
			end
		end

		return wrapped
	end

	--------------------------------

	if sc.restrictions.cpu < 0 then
		return code, env
	end

	local newCode = {}
	local newCodeI = 1
	for i = 1, #code do
		local char = code:sub(i, i)
		if char ~= "\r" then
			if char == "\t" then
				newCode[newCodeI] = " "
			else
				newCode[newCodeI] = char
			end
			newCodeI = newCodeI + 1
		end
	end
	local code, err = process(table.concat(newCode))
	if code then
		return yieldName .. "() do " .. code .. " \n end " .. yieldName .. "() ", env
	else
		return nil, err or "unknown error"
	end
end


local function createAdditionalInfo(names, values)
	local str = "  -  ("
	for i, lstr in ipairs(names) do
		if type(values[i]) == "string" then
			str = str .. lstr .. "-\"" .. tostring(values[i] or "unknown") .. "\""
		else
			str = str .. lstr .. "-'" .. tostring(values[i] or "unknown") .. "'"
		end
		if i ~= #names then
			str = str .. ", "
		end
	end
	return str .. ")"
end

function checkVMname()
	local vm = sc.restrictions.vm
	if vm == "scrapVM" and _G.luavm then
		return "scrapVM"
	elseif vm == "betterAPI" and better then
		return "betterAPI"
	elseif vm == "luaInLua" and ll_Scanner and ll_Parser and ll_Interpreter then
		return "luaInLua"
	elseif vm == "dlm" and dlm and dlm.loadstring then
		return "dlm"
	elseif vm == "hsandbox" and _HENV and _HENV.load then
		return "hsandbox"
	elseif vm == "advancedExecuter" and sm.advancedExecuter then
		return "advancedExecuter"
	elseif FiOne_lua then
		return "FiOne_lua"
	end
end

function shortTraceback(...)
	local tbl = {...}
	if not tbl[1] then
		tbl[2] = tostring(tbl[2])
		if ScriptableComputer and ScriptableComputer.shortTraceback then
			local lines = strSplit(string, tbl[2], "\n", true)
			for i = 1, ScriptableComputer.shortTraceback do
				table.remove(lines, #lines)
			end
			tbl[2] = table.concat(lines, "\n")
		end
	end
	return unpack(tbl)
end

function smartCall(nativePart, func, ...)
	if nativePart ~= func then
		local self, tunnel
		pcall(function ()
			self, tunnel = nativePart[2], nativePart[1]
		end)

		if self then
			ll_Interpreter.internalData[self.env[self.yieldName]] = true --а нехер перезаписывать __internal_yield, крашеры ебаные
			local result
			if sc.traceback then
				result = {shortTraceback(xpcall(func, sc.traceback, ...))}
			else
				result = {pcall(func, ...)}
			end
			ll_Interpreter.internalData[self.env[self.yieldName]] = nil

			if result[1] then
				return unpack(result)
			else
				local str = ll_shorterr(result[2])
				if tunnel.lastEval then
					str = str .. createAdditionalInfo({"line", "eval", "name"}, {tunnel.lastEval.line, tunnel.lastEval.type, tunnel.lastEval.chunkname})
				end
				return nil, str
			end
		end
	end

	if sc.traceback then
		return shortTraceback(xpcall(func, sc.traceback, ...))
	else
		return pcall(func, ...)
	end
end

function load_code(self, chunk, chunkname, mode, env, serviceTable)
	checkArg(1, self,		 "table", "nil")
	checkArg(2, chunk,		"string")
	checkArg(3, chunkname,	"string", "nil")
	checkArg(4, mode,		 "string", "nil")
	checkArg(5, env,		  "table",  "nil")
	checkArg(6, serviceTable, "table",  "nil")

	mode = mode or "bt"
	env = env or _G

	local vm = sc.restrictions.vm
	if vm == "fullLuaEnv" and a and a.load then
		return a.load(chunk, chunkname, mode, env)
	elseif vm == "scrapVM" and _G.luavm then
		if self and not self.luastate then
			self.luastate = {}
		end

		local code, err = _G.luavm.custom_loadstring(self and self.luastate or {}, chunk, env)
		if code then
			return code --я хз че там в втором аргументе в данный момент
		else
			return code, err
		end
	elseif vm == "betterAPI" and better then
		return better.loadstring(chunk, chunkname, env)
	elseif vm == "dlm" and dlm and dlm.loadstring then
		return dlm.loadstring(chunk, chunkname, env)
	elseif vm == "hsandbox" and _HENV and _HENV.load then
		return _HENV.load(chunk, chunkname, mode, env)
	elseif vm == "luaInLua" and ll_Scanner and ll_Parser and ll_Interpreter then
		if chunkname and chunkname:sub(1, 1) == "=" then
			chunkname = chunkname:sub(2, #chunkname)
		end

		local tunnel = {}
		local function getScriptTree(script)
			local ran, tokens = pcall(ll_Scanner.scan, ll_Scanner, script)
			if ran then
				local ran, tree = pcall(ll_Parser.parse, ll_Parser, tokens, chunkname, tunnel, serviceTable)
				return ran, tree
			else
				return ran, tokens
			end
		end
		
		local newchunk, getargsfunc = ll_fix(chunk)
		local ran, tree = getScriptTree(newchunk)
		if ran then
			local enclosedEnv = ll_Interpreter:encloseEnvironment(env)

			local function resultFunction(...)
				local args = {...}
				env[getargsfunc] = function ()
					return unpack(args)
				end
				
				if self then
					ll_Interpreter.internalData[self.env[self.yieldName]] = true --а нехер перезаписывать __internal_yield, крашеры ебаные
				end
				local result = {pcall(ll_Interpreter.evaluate, ll_Interpreter, tree, enclosedEnv)}
				if self then
					ll_Interpreter.internalData[self.env[self.yieldName]] = nil
				end

				if result[1] then
					return unpack(result, 2)
				else
					local str = ll_shorterr(result[2])
					if tunnel.lastEval then
						str = str .. createAdditionalInfo({"line", "eval", "name"}, {tunnel.lastEval.line, tunnel.lastEval.type, tunnel.lastEval.chunkname})
					end
					error(str, 2)
				end
			end

			return mt_hook({
				__call = function(_, ...)
					local result = {pcall(resultFunction, ...)}
					if not result[1] then
						error(result[2], 2)
					else
						return unpack(result, 2)
					end
				end,
				__index = function(_, key)
					if key == 1 then
						return tunnel
					elseif key == 2 then
						return self
					elseif key == 3 then
						return resultFunction
					end
				end
			})
		else
			return nil, ll_shorterr(tree)
		end
	elseif vm == "advancedExecuter" and sm.advancedExecuter then
		return sm.advancedExecuter.loadstring(chunk, chunkname, mode, env)
	elseif FiOne_lua then
		if chunkname and chunkname:sub(1, 1) == "=" then
			chunkname = chunkname:sub(2, #chunkname)
		end
		local ok, result = pcall(FiOne_lua.load, self, chunk, chunkname, env)
		if ok then
			return result
		else
			return nil, result
		end
	else
		return nil, 'failed to load the code, try changing "vm" in "PermissionTool"'
	end
end

function safe_load_code(self, chunk, chunkname, mode, env)
	checkArg(1, self,	  "table")
	checkArg(2, chunk,	 "string")
	checkArg(3, chunkname, "string", "nil")
	checkArg(4, mode,	  "string", "nil")
	checkArg(5, env,	   "table",  "nil")

	if sc.shutdownFlag then
		return nil, "CRITICAL ISSUE IN SCOMPUTERS"
	end

	local codelen = #chunk
	if codelen > sc.maxcodelen then
		return nil, "the code len " .. mathRound(codelen) .. " bytes, the maximum code len " .. sc.maxcodelen .. " bytes"
	end

	env = env or {}
	mode = mode or "bt"

	if mode == "bt" then
		mode = "t"
	elseif mode == "t" then
		mode = "t"
	elseif mode == "b" then
		return nil, "bytecode is unsupported"
	else
		return nil, "this load mode is unsupported"
	end

	local preloadOk, preloadErr = load_code(self, chunk, chunkname, mode, {}) --syntax errors check
	if not preloadOk then
		return nil, preloadErr
	end

	local serviceTable = {}
	chunk, env = addServiceCode(self, chunk, env, serviceTable) --env may be a error
	if not chunk then
		return nil, env
	end
	
	return load_code(self, chunk, chunkname, mode, env, serviceTable)
end