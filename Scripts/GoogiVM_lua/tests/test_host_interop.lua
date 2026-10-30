return function(t)
    local P = t.P

    t:expect([[
local function f(a, b) return a + b end
local ok, v = pcall(f, 2, 3)
return ok, v
]], P(true, 5))

    t:expect([[
local function f(...) return select('#', ...), ... end
local ok, a, b, c, d = pcall(f, 1, nil, 3)
return ok, a, b, c, d
]], P(true, 3, 1, nil, 3))

    t:expect([[
local function f() error({ code = 9 }) end
local ok, err = pcall(f)
return ok, type(err), err.code
]], P(false, "table", 9))

    t:expect([[
local t = {3, 1, 2}
table.sort(t, function(a, b) return a > b end)
return t[1], t[2], t[3]
]], P(3, 2, 1))

    t:expect([[
local t = {{n = 4}, {n = 1}, {n = 3}}
table.sort(t, function(a, b) return a.n < b.n end)
return t[1].n, t[2].n, t[3].n
]], P(1, 3, 4))

    t:expect([[
local out = string.gsub('abc', '%a', function(c) return c:upper() end)
return out
]], P("ABC"))

    t:expect([[
local co = coroutine.create(function(a, b)
    local x = coroutine.yield(a + b)
    return x * 2
end)
local ok1, y = coroutine.resume(co, 2, 3)
local ok2, z = coroutine.resume(co, 7)
return ok1, y, ok2, z, coroutine.status(co)
]], P(true, 5, true, 14, "dead"))

    t:expect([[
local f = coroutine.wrap(function(...)
    for i = 1, 3 do coroutine.yield(i, ...) end
end)
local a, b = f(9)
local c, d = f(9)
return a, b, c, d
]], P(1, 9, 2, 9))

    -- Yielding through nested interpreted calls.
    t:expect([[
local function g()
    coroutine.yield(1)
    return 2
end
local function f()
    local a = g()
    coroutine.yield(3)
    return a + 1
end
local co = coroutine.create(f)
local ok1, a = coroutine.resume(co)
local ok2, b = coroutine.resume(co)
local ok3, c = coroutine.resume(co)
return ok1, a, ok2, b, ok3, c, coroutine.status(co)
]], P(true, 1, true, 3, true, 3, "dead"))

    -- Higher-order native function calls an interpreted callback.
    local function twice(f)
        return f(3)
    end
    t:expect("return twice(function(x) return x * 2 end)", P(6), { twice = twice })

    local function apply(f, a, b)
        return f(a, b)
    end
    t:expect("return apply(function(x, y) return x + y end, 4, 5)", P(9), { apply = apply })

    -- type/tostring see a real function.
    t:expect([[
local function f() end
return type(f), tostring(f):sub(1, 9)
]], P("function", "function:"))

    -- Host function with nil args.
    local function args(...)
        return select("#", ...), ...
    end
    t:expect("return args(1, nil, 3)", P(3, 1, nil, 3), { args = args, select = select })

    -- pcall around a custom closure returning multiple values.
    t:expect([[
local function f() return 4, 5, 6 end
return pcall(f)
]], P(true, 4, 5, 6))

    t:compare([[
local function f(n)
    if n == 0 then return 0 end
    return n + f(n - 1)
end
return f(20)
]])

    -- String methods are available through the host string metatable.
    t:expect("return ('abc'):sub(2, 3), ('x'):len()", P("bc", 1))
    t:expect("return ('abc'):upper()", P("ABC"))
end
