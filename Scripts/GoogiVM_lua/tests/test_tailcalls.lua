return function(t)
    local P = t.P

    -- A real tail recursion must not consume the call-depth budget.
    local f, err = t.custom([[
local function f(n)
    if n == 0 then return 42 end
    return f(n - 1)
end
return f(100000)
]], {}, { maxCallDepth = 10 })
    t:check(f ~= nil, "tail recursion compile: " .. tostring(err))
    if f then
        local ok, value = pcall(f)
        t:check(ok and value == 42, "tail recursion result: " .. tostring(value))
    end

    -- Mutual tail recursion is also frame-reusing.
    do
        local chunk, cerr = t.custom([[
local even, odd
function even(n)
    if n == 0 then return true end
    return odd(n - 1)
end
function odd(n)
    if n == 0 then return false end
    return even(n - 1)
end
return even(100000)
]], {}, { maxCallDepth = 10 })
        t:check(chunk ~= nil, "mutual tail recursion compile: " .. tostring(cerr))
        if chunk then
            local ok, value = pcall(chunk)
            t:check(ok and value == true, "mutual tail recursion result")
        end
    end

    -- Tail calls preserve all return values.
    t:expect([[
local function g() return 1, 2, 3 end
local function f() return g() end
return f()
]], P(1, 2, 3))

    -- Native functions can be tail-called too.
    t:expect([[
local function f() return tostring(42) end
return f()
]], P("42"))

    -- Method and vararg tail calls.
    t:expect([[
local t = { x = 7 }
function t:get() return self.x end
local function f() return t:get() end
return f()
]], P(7))

    t:expect([[
local function g(...) return ... end
local function f(...) return g(...) end
return f(1, 2, 3)
]], P(1, 2, 3))

    -- A call followed by another value is not a tail call.
    t:expect([[
local function g() return 1, 2 end
local function f() return g(), 3 end
return f()
]], P(1, 3))

    t:expect([[
local function g() return 2 end
local function f() return g() + 1 end
return f()
]], P(3))

    -- Parenthesized calls intentionally collapse multiple returns.
    t:expect([[
local function g() return 1, 2 end
local function f() return (g()) end
return f()
]], P(1))

    -- Callable tables go through the native __call path.
    t:expect([[
local t = setmetatable({}, { __call = function() return 4, 5 end })
local function f() return t() end
return f()
]], P(4, 5))

    -- The caller's result count is preserved.
    t:expect([[
local function g() return 1, 2, 3 end
local function f() return g() end
local a, b = f()
return a, b
]], P(1, 2))

    -- A tail call used as a statement drops all results.
    t:expect([[
local function g() return 1, 2 end
local function f() return g() end
f()
return 9
]], P(9))

    -- Tail calls still propagate errors to pcall.
    local chunk = assert(t.custom([[
local a, b
function a() return b() end
function b() return nil + 1 end
return a()
]], {}, { sourceName = "tail.lua" }))
    do
        local ok, e = pcall(chunk)
        t:check(not ok and type(e) == "string" and
            e:find("tail.lua:3:", 1, true) ~= nil,
            "tail error source line: " .. tostring(e))
    end

    -- Coroutine yields survive a native tail call.
    t:expect([[
local co = coroutine.wrap(function()
    return coroutine.yield(1)
end)
return co()
]], P(1))

    -- Deep tail recursion must not grow the VM value stack.
    do
        local chunk, cerr = t.custom([[
local function f(n, acc)
    if n == 0 then return acc end
    return f(n - 1, acc + 1)
end
return f(600000, 0)
]], {}, { maxCallDepth = 10 })
        t:check(chunk ~= nil, "deep tail recursion compile: " .. tostring(cerr))
        if chunk then
            local ok, value = pcall(chunk)
            t:check(ok and value == 600000,
                "deep tail recursion result: " .. tostring(value))
        end
    end

    -- Tail-call argument relocation must preserve argument order.
    t:expect([[
local function f(a, b, c, n)
    if n == 0 then return a * 100 + b * 10 + c end
    return f(a, b, c, n - 1)
end
return f(1, 2, 3, 5000)
]], P(123))

    -- Vararg tail calls keep every argument while the frame is reused.
    t:expect([[
local function collect(a, b, c, ...)
    local n = select('#', ...)
    if a == 0 then return b + c + n end
    return collect(a - 1, b, c, ...)
end
return collect(5000, 10, 20, 1, 2, 3)
]], P(33))

    -- Fixed result counts still trim values.
    t:expect([[
local function g() return 1, 2, 3 end
local function f() return g() end
local a = f()
return a
]], P(1))
end
