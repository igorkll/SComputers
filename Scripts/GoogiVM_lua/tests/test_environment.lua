return function(t)
    local P = t.P

    t:expect1("return x", 5, { x = 5 })
    t:expect1("local x = 6; return x", 6, { x = 5 })

    local env = {}
    local f = assert(t:compile("x = 42; local y = 2; return x + y", env))
    local ok = pcall(f)
    t:check(ok and env.x == 42, "global assignment must update env")
    t:equal(env.y, nil, "local must not leak into env")

    -- No implicit _G.
    t:expect1("return _G", nil, {})
    t:expect1("return os", nil, {})
    t:expect1("return io", nil, {})
    t:expect1("return debug", nil, {})

    -- Environment metatable reads/writes are honored.
    local store = {}
    local meta_env = setmetatable({ store = store }, {
        __index = function(_, k)
            if k == "x" then return 5 end
            return store[k]
        end,
        __newindex = function(_, k, v)
            store[k] = v * 2
        end,
    })
    t:expect("y = 3; return x, store.y", P(5, 6), meta_env)
    t:equal(store.y, 6, "env __newindex")

    -- Separate chunks have separate environments.
    local env1, env2 = {}, {}
    local f1 = assert(t:compile("return x", env1))
    local f2 = assert(t:compile("return x", env2))
    env1.x, env2.x = 1, 2
    t:equal(f1(), 1, "chunk 1 env")
    t:equal(f2(), 2, "chunk 2 env")

    -- Nested closures keep the same env.
    t:expect([[
local function f() return x end
return f()
]], P(77), { x = 77 })

    -- Function environments via getfenv/setfenv when the host supports them.
    if setfenv and getfenv then
        local fenv = t.env
        local chunk = assert(t:compile([=[
local function inner() return x, y end
return inner
]=], fenv))

        t:check(getfenv(chunk) == fenv, "getfenv(chunk) must be env")

        local newenv = { x = 10, y = 20, getfenv = getfenv, setfenv = setfenv }
        setfenv(chunk, newenv)
        local inner = chunk()
        t:expect("local i = ...; return i()", P(10, 20), newenv, inner)
        t:equal(getfenv(chunk), newenv, "host setfenv on chunk")

        local src = [=[
local function f() return x end
setfenv(1, { x = 88, getfenv = getfenv, setfenv = setfenv })
return f()
]=]
        local c2 = assert(t:compile(src, { x = 1, getfenv = getfenv, setfenv = setfenv }))
        t:equal(c2(), 1, "old closures keep their old environment")

        local src2 = [=[
setfenv(1, { x = 88, getfenv = getfenv, setfenv = setfenv })
local function f() return x end
return f()
]=]
        local c3 = assert(t:compile(src2, { x = 1, getfenv = getfenv, setfenv = setfenv }))
        t:equal(c3(), 88, "new closures inherit changed environment")

        local src3 = [=[
local function outer()
    local before = getfenv(1)
    local function inner()
        return getfenv(1), getfenv(2)
    end
    return before, inner()
end
local a, b, c = outer()
return a == b, b == c
]=]
        local c4 = assert(t:compile(src3, t.env))
        t:pack_equal(t.P(c4()), P(true, true), "getfenv levels")

        local src4 = [=[
local function f() return x end
setfenv(f, { x = 99, getfenv = getfenv, setfenv = setfenv })
return f()
]=]
        local c5 = assert(t:compile(src4, { x = 1, getfenv = getfenv, setfenv = setfenv }))
        t:equal(c5(), 99, "setfenv(function)")

        local src5 = [=[
local function setparent()
    setfenv(2, { x = 77, getfenv = getfenv, setfenv = setfenv })
end
setparent()
return x
]=]
        local c6 = assert(t:compile(src5, { x = 1, getfenv = getfenv, setfenv = setfenv }))
        t:equal(c6(), 77, "setfenv(level)")

        t:runtime_error("setfenv(0, {})", t.env)

        -- getfenv(function), setfenv(function) return value.
        t:expect([[
local function f() return x end
local e = getfenv(f)
return e == getfenv(1), e.x
]], P(true, 5), { x = 5, getfenv = getfenv, setfenv = setfenv })

        t:expect([[
local function f() return x end
local g = setfenv(f, {x = 9, getfenv = getfenv, setfenv = setfenv})
return g == f, f()
]], P(true, 9), { x = 1, getfenv = getfenv, setfenv = setfenv })

        -- Current function environment changes immediate global access.
        t:expect([[
setfenv(1, {x = 10, getfenv = getfenv, setfenv = setfenv})
y = 20
return x, y
]], P(10, 20), { x = 1, getfenv = getfenv, setfenv = setfenv })

        -- Invalid levels are errors.
        t:runtime_error("return getfenv(99)", t.env)
        t:runtime_error("setfenv(99, {})", t.env)
        t:runtime_error("setfenv(1, 5)", t.env)
    end
end
