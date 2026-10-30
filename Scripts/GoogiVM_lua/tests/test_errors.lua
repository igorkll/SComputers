return function(t)
    local P = t.P

    -- API validation.
    local f, err = t.custom(nil, {})
    t:check(f == nil and type(err) == "string", "nil source must fail")
    f, err = t.custom(123, {})
    t:check(f == nil and type(err) == "string", "non-string source must fail")
    f, err = t.custom("return 1", 5)
    t:check(f == nil and type(err) == "string", "non-table env must fail")

    -- Omitted env defaults to an empty sandbox, not _G.
    local default_chunk = assert(t.custom("return 1, x"))
    t:pack_equal(t.P(default_chunk()), P(1, nil), "default env")

    -- Returned chunk type.
    local chunk = assert(t:compile("return 1"))
    t:equal(type(chunk), "function", "chunk type")

    -- Empty chunk returns nothing.
    local empty = assert(t:compile(""))
    local p = t.P(empty())
    t:equal(p.n, 0, "empty chunk results")

    -- Fresh locals on each call.
    local fresh = assert(t:compile("local x = 1; x = x + 1; return x"))
    t:equal(fresh(), 2, "first invocation")
    t:equal(fresh(), 2, "second invocation")

    -- Syntax errors are returned as nil, string.
    t:compile_error("local x =")
    t:compile_error("if true then")
    t:compile_error("while do end")
    t:compile_error("repeat x = 1")
    t:compile_error("return 1 +")
    t:compile_error("break")
    t:compile_error("function f(")
    t:compile_error("local t = {1,,2}")
    t:compile_error("a() = 1")

    -- Syntax errors have line information.
    local bad, msg = t.custom("local x = 1\nif x then\n  local y =\nend", {})
    t:check(bad == nil, "bad source must not compile")
    t:check(type(msg) == "string" and msg:find("line 4", 1, true) ~= nil,
        "syntax error should mention line 4: " .. tostring(msg))

    -- Compile errors must not execute anything.
    local side = {}
    local cf = t.custom("x = 1; local = 2", side)
    t:check(cf == nil and side.x == nil, "compile error must not execute")

    -- Runtime errors must propagate to pcall, not be swallowed by the loader.
    t:runtime_error("return nil + 1")
    t:runtime_error("return (nil).x")
    t:runtime_error("local f; return f()")
    t:runtime_error("local t = {}; return t[1].x")
    t:runtime_error("return 'a' < 1")
    t:runtime_error("return 1 < false")
    t:runtime_error("return {} .. 'x'")
    t:runtime_error("return #123")
    t:runtime_error("for i = 1, 2, 0 do end")
    t:runtime_error("for i = 1, 'x' do end")
    t:runtime_error("for i = true, 2 do end")

    -- runtime errors can be caught by pcall.
    t:expect([[
local ok, err = pcall(function() return nil + 1 end)
return ok, type(err)
]], P(false, "string"))

    -- error objects (tables) are preserved.
    t:expect([[
local ok, err = pcall(function() error({ code = 7 }) end)
return ok, type(err), err.code
]], P(false, "table", 7))

    -- xpcall handler.
    t:expect([[
local hit = false
local ok, value = xpcall(function() error('boom') end, function(e)
    hit = true
    return type(e)
end)
return ok, value, hit
]], P(false, "string", true))

    -- Errors from metamethods and iterators.
    t:runtime_error([[
local t = setmetatable({}, {__add = function() error('add') end})
return t + 1
]])
    t:runtime_error([[
for k in function() error('iter') end do end
]])

    -- Errors caught by guest pcall must keep the sandbox source location and
    -- must not leak host file paths.
    do
        local chunk = assert(t.custom([[
local ok, err = pcall(function() return nil + 1 end)
return ok, err
]], t.env, { sourceName = "pcall.lua" }))
        local ran, gok, gerr = pcall(chunk)
        t:check(ran and gok == false and type(gerr) == "string",
            "pcall result shape: " .. tostring(gerr))
        t:check(type(gerr) == "string" and gerr:find("pcall.lua:", 1, true) ~= nil,
            "pcall error keeps source name: " .. tostring(gerr))
        t:check(type(gerr) == "string" and
            gerr:find("custom_loadstring_full", 1, true) == nil,
            "pcall error must not leak host paths: " .. tostring(gerr))
    end

    -- xpcall handlers receive the formatted sandbox message.
    do
        local chunk = assert(t.custom([[
local ok, msg = xpcall(function() error("kaboom") end, function(e) return e end)
return ok, msg
]], t.env, { sourceName = "xpcall.lua" }))
        local ran, gok, gmsg = pcall(chunk)
        t:check(ran and gok == false and type(gmsg) == "string" and
            gmsg:find("xpcall.lua:", 1, true) ~= nil,
            "xpcall handler formatted error: " .. tostring(gmsg))
    end

    -- Guest pcall still forwards multiple results and accepts native targets.
    t:expect("local ok, a, b = pcall(function() return 1, 2 end); return ok, a, b",
        P(true, 1, 2))
    t:expect("local ok, v = pcall(string.upper, 'abc'); return ok, v", P(true, "ABC"))

    -- Native targets with guest callbacks must not leak host paths.
    do
        local chunk = assert(t.custom([[
local ok, e = pcall(table.sort, {3, 1, 2}, function(a, b) error("cmp") end)
return ok, e
]], t.env, { sourceName = "native.lua" }))
        local ran, gok, gerr = pcall(chunk)
        t:check(ran and gok == false and type(gerr) == "string",
            "native-target pcall shape: " .. tostring(gerr))
        t:check(type(gerr) == "string" and gerr:find("native.lua:", 1, true) ~= nil,
            "native-target pcall location: " .. tostring(gerr))
        t:check(type(gerr) == "string" and
            gerr:find("custom_loadstring_full", 1, true) == nil,
            "native-target pcall must not leak host paths: " .. tostring(gerr))
    end

    do
        local chunk = assert(t.custom([[
local ok, e = pcall(string.gsub, "abc", "%a", function(c) error("gsub") end)
return ok, e
]], t.env, { sourceName = "gsub.lua" }))
        local ran, gok, gerr = pcall(chunk)
        t:check(ran and gok == false and type(gerr) == "string" and
            gerr:find("gsub.lua:", 1, true) ~= nil and
            gerr:find("custom_loadstring_full", 1, true) == nil,
            "gsub callback error: " .. tostring(gerr))
    end

    -- xpcall with a native target also hands the handler a sandbox message.
    do
        local chunk = assert(t.custom([[
local ok, msg = xpcall(table.sort, function(m) return "H:" .. m end,
    {3, 1, 2}, function(a, b) error("cmp2") end)
return ok, msg
]], t.env, { sourceName = "xpcall2.lua" }))
        local ran, gok, gmsg = pcall(chunk)
        t:check(ran and gok == false and type(gmsg) == "string" and
            gmsg:find("H:xpcall2.lua:", 1, true) ~= nil and
            gmsg:find("custom_loadstring_full", 1, true) == nil,
            "xpcall native-target handler: " .. tostring(gmsg))
    end

    -- error(msg, level) must select the requested interpreted frame.
    do
        local src = [[
local function a() error("lvl", LEVEL) end
local function b()
    a()
end
local ok, e = pcall(b)
return ok, e
]]
        for level, want in pairs({ [0] = "lvl", [1] = "lvl.lua:1:", [2] = "lvl.lua:3:" }) do
            local chunk = assert(t.custom(src:gsub("LEVEL", tostring(level)),
                t.env, { sourceName = "lvl.lua" }))
            local ran, gok, gerr = pcall(chunk)
            t:check(ran and gok == false and type(gerr) == "string" and
                gerr:find(want, 1, true) == 1,
                "error level " .. level .. ": " .. tostring(gerr))
        end
    end

    -- Uncaught traceback frames must point at the call lines, not the next one.
    do
        local chunk = assert(t.custom([[
local function g() error("D") end
local function f()
  g()
end
local function h()
  f()
end
h()
]], t.env, { sourceName = "tb.lua" }))
        local ran, gerr = pcall(chunk)
        t:check(not ran and type(gerr) == "string" and
            gerr:find("  at tb.lua:3", 1, true) ~= nil,
            "traceback call site 1: " .. tostring(gerr))
        t:check(not ran and type(gerr) == "string" and
            gerr:find("  at tb.lua:6", 1, true) ~= nil,
            "traceback call site 2: " .. tostring(gerr))
        t:check(not ran and type(gerr) == "string" and
            gerr:find("  at tb.lua:8", 1, true) ~= nil,
            "traceback call site 3: " .. tostring(gerr))
    end

    -- Host argument errors report the real callee name, not the VM local `f`.
    t:expect([[
local ok, e = pcall(function() return string.rep(5) end)
return ok, e:find("to 'rep'", 1, true) ~= nil and e:find("to 'f'", 1, true) == nil
]], P(false, true))
    t:expect([[
local ok, e = pcall(function() return math.floor("x") end)
return ok, e:find("to 'floor'", 1, true) ~= nil
]], P(false, true))

    -- Caught errors stay single-line, matching native pcall shape.
    t:expect([[
local ok, e = pcall(function()
    local function g() error("nested") end
    g()
end)
return ok, e:find("\n", 1, true) == nil
]], P(false, true))

    -- Runtime error after partial side effects keeps the side effect.
    local env = {}
    local c = assert(t:compile("x = 1; return nil + 1", env))
    local ok = pcall(c)
    t:check(not ok and env.x == 1, "side effects before runtime error")
end
