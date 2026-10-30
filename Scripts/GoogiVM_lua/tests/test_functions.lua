return function(t)
    local P = t.P

    t:expect1("local function f(x) return x * 2 end return f(6)", 12)
    t:expect1("local f = function(a, b) return a + b end return f(2, 3)", 5)
    t:expect1("function f(a, b) return a + b end return f(2, 3)", 5)
    t:expect1("local function fact(n) if n < 2 then return 1 end return n * fact(n - 1) end return fact(6)", 720)
    t:expect1("local function f() return 1 end local g = f return g()", 1)

    t:expect1([[
local function make(x)
    return function() x = x + 1; return x end
end
local f = make(5)
f(); f()
return f()
]], 8)

    t:expect1([[
local function outer()
    local x = 1
    return function()
        x = x + 1
        return function()
            x = x + 1
            return x
        end
    end
end
local f = outer()
local g = f()
g(); g()
return g()
]], 5)

    t:expect([[
local x = 1
x = 2
local f = function() return x end
x = 3
return f()
]], P(3))

    t:expect([[
local x = 1
local f = function() x = x + 1; return x end
x = 10
return f(), f(), x
]], P(11, 12, 12))

    t:expect([[
local x = 1
local get = function() return x end
local set = function(v) x = v end
set(9)
return get(), x
]], P(9, 9))

    t:expect([[
local function a()
    local x = 10
    local function b()
        local y = 20
        return function() x = x + 1; y = y + 1; return x + y end
    end
    return b()
end
local f = a()
return f(), f()
]], P(32, 34))

    t:expect([[
local t = {}
for i = 1, 3 do t[i] = function() return i end end
return t[1](), t[2](), t[3]()
]], P(1, 2, 3))

    t:expect([[
local t = {}
for k, v in ipairs({10, 20, 30}) do t[k] = function() return k, v end end
local a, b = t[1]()
local c, d = t[3]()
return a, b, c, d
]], P(1, 10, 3, 30))

    t:expect([[
local t = {}
local i = 0
while i < 3 do
    i = i + 1
    local x = i
    t[i] = function() return x end
end
return t[1](), t[2](), t[3]()
]], P(1, 2, 3))

    t:expect([[
local t = {}
local i = 0
repeat
    i = i + 1
    local x = i
    t[i] = function() return x end
until i == 3
return t[1](), t[2](), t[3]()
]], P(1, 2, 3))

    t:expect([[
local t = {}
for i = 1, 3 do
    local x = i * 10
    t[i] = function(v)
        if v then x = v end
        return x
    end
end
t[2](99)
return t[1](), t[2](), t[3]()
]], P(10, 99, 30))

    t:expect([[
local even, odd
function even(n)
    if n == 0 then return true end
    return odd(n - 1)
end
function odd(n)
    if n == 0 then return false end
    return even(n - 1)
end
return even(10), odd(10)
]], P(true, false))

    t:expect([[
local t = {x = 5}
function t.add(self, y) return self.x + y end
function t:mul(y) return self.x * y end
return t.add(t, 2) + t:mul(3)
]], P(22))

    t:expect([[
local t = {a = {b = {}}}
function t.a.b:m(x) return self.v + x end
t.a.b.v = 10
return t.a.b:m(5)
]], P(15))

    t:expect([[
local function outer()
    local t = {}
    function t:m(x) return x * 2 end
    return t
end
return outer():m(4)
]], P(8))

    t:expect([[
local x = 1
local function f() return x end
x = 2
local function g() return x end
x = 3
return f(), g(), x
]], P(3, 3, 3))

    t:expect([[
local log = {}
local function f(n) log[#log + 1] = n; return n end
local a = f(1) + f(2)
return a, log[1], log[2]
]], P(3, 1, 2))

    t:compare([[
local function f(x)
    return function(y) return x + y end
end
local a = f(10)
local b = f(20)
return a(1), a(2), b(1), b(2)
]])

    t:compare([[
local a = 1
local function outer()
    local b = 2
    local function middle()
        local c = 3
        return function() a = a + 1; b = b + 1; c = c + 1; return a + b + c end
    end
    return middle()
end
local f = outer()
return f(), f()
]])

    -- `function name()` assigns to an existing local or upvalue.
    t:expect("local f; function f() return 1 end return f()", P(1))
    t:expect([[
local f
local function make()
    function f() return 2 end
end
make()
return f()
]], P(2))

    -- Immediate invocation of an anonymous function via parentheses.
    t:expect("return (function(a, b) return a + b end)(2, 3)", P(5))

    -- Chained calls and field access.
    t:expect([[
local t = {x = {y = 4}}
local function get() return t end
return get().x.y, (get()).x.y
]], P(4, 4))

    -- Method call with string/table argument sugar.
    t:expect([[
local t = {}
function t:m(x) return x end
return t:m'abc', t:m{1}[1]
]], P("abc", 1))

    -- Multiple nested function levels with vararg forwarding.
    t:expect([[
local function a(...)
    local function b(...)
        local function c(...)
            return select('#', ...), ...
        end
        return c(...)
    end
    return b(...)
end
return a(1, 2, 3)
]], P(3, 1, 2, 3))
end
