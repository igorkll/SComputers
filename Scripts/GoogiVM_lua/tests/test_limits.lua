return function(t)
    local unpack = unpack or table.unpack
    local custom = t.custom

    -- Native function environments must not be reachable through getfenv.
    if getfenv then
        local f, err = custom("return getfenv(getfenv)", { getfenv = getfenv })
        t:check(f ~= nil, "getfenv native test compile: " .. tostring(err))
        if f then
            local ok = pcall(f)
            t:check(not ok, "getfenv(native) must be rejected")
        end
    end

    -- Native function environments must not be changed through setfenv.
    if setfenv then
        local f, err = custom("return setfenv(print, {})", {
            setfenv = setfenv,
            print = print,
        })
        t:check(f ~= nil, "setfenv native test compile: " .. tostring(err))
        if f then
            local ok = pcall(f)
            t:check(not ok, "setfenv(native) must be rejected")
        end
    end

    -- Guest pcall/xpcall must not bypass the fenv guards by calling them
    -- through a native protected call.
    if getfenv then
        local f = custom([[
local blocked = pcall(getfenv, print)
local plain = pcall(getfenv, 0)
return blocked, plain
]], { getfenv = getfenv, print = print, pcall = pcall })
        t:check(f ~= nil, "guest pcall(getfenv) compiled")
        if f then
            local ok, blocked, plain = pcall(f)
            t:check(ok and blocked == false and plain == true,
                "pcall(getfenv, native) must be blocked, pcall(getfenv, 0) allowed")
        end

        f = custom([[
local ok = xpcall(getfenv, function() return 0 end, print)
return ok
]], { getfenv = getfenv, print = print, xpcall = xpcall })
        t:check(f ~= nil, "guest xpcall(getfenv) compiled")
        if f then
            local ok, res = pcall(f)
            t:check(ok and res == false, "xpcall(getfenv, native) must be blocked")
        end
    end

    if setfenv then
        local f = custom([[
return pcall(setfenv, 0, {})
]], { setfenv = setfenv, pcall = pcall })
        t:check(f ~= nil, "guest pcall(setfenv, 0) compiled")
        if f then
            local ok, res = pcall(f)
            t:check(ok and res == false, "pcall(setfenv, 0, {}) must be blocked")
        end
    end

    -- Options must be a table.
    local f, err = custom("return 1", {}, 5)
    t:check(f == nil and type(err) == "string", "non-table options rejected")

    -- Invalid limits must be rejected.
    f, err = custom("return 1", {}, { maxInstructions = -1 })
    t:check(f == nil and type(err) == "string", "negative limit rejected")
    f, err = custom("return 1", {}, { maxInstructions = 0 / 0 })
    t:check(f == nil and type(err) == "string", "NaN limit rejected")

    -- Compile-time source limit.
    f, err = custom("return 123456789", {}, { maxSourceBytes = 4 })
    t:check(f == nil and tostring(err):find("maxSourceBytes", 1, true) ~= nil,
        "maxSourceBytes: " .. tostring(err))

    -- Compile-time bytecode limit.
    f, err = custom("return 1", {}, { maxCodeSlots = 1 })
    t:check(f == nil and tostring(err):find("maxCodeSlots", 1, true) ~= nil,
        "maxCodeSlots: " .. tostring(err))

    -- Runtime instruction limit.
    f = assert(custom("while true do end", {}, { maxInstructions = 1000 }))
    t:check(not pcall(f), "maxInstructions must abort an infinite loop")

    -- Runtime call-depth limit.
    f = assert(custom([[
local function f(n)
    if n == 0 then return 0 end
    return 1 + f(n - 1)
end
return f(100)
]], {}, { maxCallDepth = 20 }))
    t:check(not pcall(f), "maxCallDepth must abort deep recursion")

    -- Runtime argument limit.
    f = assert(custom([[
local function f(...) return ... end
return f(...)
]], {}, { maxArgs = 10 }))
    do
        local args = {}
        for i = 1, 50 do args[i] = i end
        t:check(not pcall(f, unpack(args)), "maxArgs must reject too many arguments")
    end

    -- Runtime return-value limit.
    f = assert(custom("return ...", {}, { maxReturns = 10 }))
    do
        local args = {}
        for i = 1, 50 do args[i] = i end
        t:check(not pcall(f, unpack(args)), "maxReturns must reject too many return values")
    end

    -- Runtime stack limit.
    f = assert(custom("return ...", {}, { maxStack = 10 }))
    do
        local args = {}
        for i = 1, 50 do args[i] = i end
        t:check(not pcall(f, unpack(args)), "maxStack must reject a large stack")
    end

    -- Runtime errors are mapped to the interpreted source line.
    f = assert(custom([[
local x = nil
return x + 1
]], {}, { sourceName = "trace.lua" }))
    do
        local ok, err = pcall(f)
        t:check(not ok and type(err) == "string" and
            err:find("trace.lua:2:", 1, true) ~= nil,
            "runtime error source line: " .. tostring(err))
    end

    -- Fused loop operations still report the body source line.
    f = assert(custom([[
local s = 0
local x = 1
for i = 1, 3 do
    s = s + x
    x = {}
end
return s
]], {}, { sourceName = "loop.lua" }))
    do
        local ok, err = pcall(f)
        t:check(not ok and type(err) == "string" and
            err:find("loop.lua:4:", 1, true) ~= nil,
            "fused loop error source line: " .. tostring(err))
    end

    -- A traceback contains the interpreted call frames.
    f = assert(custom([[
local function a()
    local function b()
        return nil + 1
    end
    local x = b()
    return x
end
return a()
]], {}, { sourceName = "trace.lua" }))
    do
        local ok, err = pcall(f)
        t:check(not ok and type(err) == "string" and
            err:find("trace.lua:3:", 1, true) ~= nil and
            err:find("  at trace.lua:", 1, true) ~= nil,
            "runtime traceback: " .. tostring(err))
    end

    -- sourceName must be a string.
    f, err = custom("return 1", {}, { sourceName = 123 })
    t:check(f == nil and type(err) == "string", "invalid sourceName rejected")
end
