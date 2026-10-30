return function(t)
    local P = t.P

    t:expect([[
local mt = {__index = {x = 8, y = 9}}
local t = setmetatable({}, mt)
return t.x, t.y, t.z
]], P(8, 9, nil))

    t:expect([[
local mt = {__index = function(t, k) return k .. '!' end}
local t = setmetatable({}, mt)
return t.foo, t.bar
]], P("foo!", "bar!"))

    t:expect([[
local base = {x = 1}
local mid = setmetatable({y = 2}, {__index = base})
local t = setmetatable({z = 3}, {__index = mid})
return t.x, t.y, t.z
]], P(1, 2, 3))

    t:expect([[
local log = ''
local mt = {
    __index = function(t, k) log = log .. 'g' .. k; return 5 end,
    __newindex = function(t, k, v) log = log .. 's' .. k .. v; rawset(t, k, v) end
}
local t = setmetatable({}, mt)
local a = t.foo
t.bar = 7
return a, t.bar, log
]], P(5, 7, "gfoosbar7"))

    t:expect([[
local target = {}
local mt = {__newindex = target}
local t = setmetatable({}, mt)
t.x = 10
return t.x, target.x
]], P(nil, 10))

    t:expect([[
local function num(v)
    if type(v) == 'table' then return v.n end
    return v
end
local mt = {
    __add = function(a, b) return num(a) + num(b) end,
    __sub = function(a, b) return num(a) - num(b) end,
    __mul = function(a, b) return num(a) * num(b) end,
    __div = function(a, b) return num(a) / num(b) end,
    __mod = function(a, b) return num(a) % num(b) end,
    __pow = function(a, b) return num(a) ^ num(b) end,
}
local a = setmetatable({n = 10}, mt)
return a + 2, 20 - a, a * 3, a / 2, a % 3, a ^ 2
]], P(12, 10, 30, 5, 1, 100))

    t:expect([[
local mt = {__unm = function(a) return -a.n end}
local a = setmetatable({n = 5}, mt)
return -a
]], P(-5))

    t:expect([[
local mt = {__concat = function(a, b) return tostring(a.n) .. tostring(b.n) end}
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 2}, mt)
return a .. b
]], P("12"))

    t:expect([[
local mt = {__eq = function(a, b) return a.n == b.n end}
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 1}, mt)
local c = setmetatable({n = 2}, mt)
return a == b, a == c, a ~= c
]], P(true, false, true))

    t:expect([[
local mt = {
    __lt = function(a, b) return a.n < b.n end,
    __le = function(a, b) return a.n <= b.n end,
}
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 2}, mt)
return a < b, a <= b, b > a, b >= a
]], P(true, true, true, true))

    t:expect([[
local t = setmetatable({v = 10}, {
    __call = function(self, a, b) return self.v + a + b end
})
return t(2, 3)
]], P(15))

    t:expect([[
local t = setmetatable({v = 1}, {
    __call = function(self, ...) return select('#', ...), ... end
})
return t(4, 5, 6)
]], P(3, 4, 5, 6))

    t:expect([[
local t = setmetatable({}, {
    __index = {
        add = function(self, x) return self.base + x end
    }
})
t.base = 10
return t:add(5)
]], P(15))

    t:expect([[
local mt = {__add = function(a, b) return 99 end}
local a = setmetatable({}, mt)
local b = setmetatable({}, mt)
return a + b, a + 1, 1 + a
]], P(99, 99, 99))

    t:compare([[
local mt = {
    __add = function(a, b) return 42 end,
    __eq = function() return true end,
    __call = function(self, x) return x end,
}
local a = setmetatable({}, mt)
return a + 1, a == a, a(7)
]])

    -- __len is a LuaJIT/5.2+ extension; test only when the host supports it.
    local probe = setmetatable({}, { __len = function() return 42 end })
    if #probe == 42 then
        t:expect([[
local mt = {__len = function(a) return a.n end}
local a = setmetatable({n = 99}, mt)
return #a
]], P(99))
    end

    -- __le fallback through __lt.
    t:compare([[
local mt = { __lt = function(a, b) return a.n < b.n end }
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 2}, mt)
return a <= b, b <= a
]])

    -- __concat chaining.
    t:expect([[
local mt = { __concat = function(a, b)
    return tostring(a.n or a) .. tostring(b.n or b)
end }
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 2}, mt)
return a .. b .. a
]], P("121"))

    -- tostring / metatable protection are host-library behavior.
    t:expect([[
local t = setmetatable({}, { __tostring = function() return 'OBJ' end })
return tostring(t)
]], P("OBJ"))

    t:expect([[
local t = setmetatable({}, { __metatable = 'locked' })
return getmetatable(t)
]], P("locked"))

    -- Metamethods supplied by the host (not interpreted closures).
    local mt = {
        __add = function() return 42 end,
        __call = function(self, x) return x * 2 end,
    }
    t:expect([[
local a = setmetatable({}, mt)
return a + 1, a(5)
]], P(42, 10), { mt = mt, setmetatable = setmetatable })

    t:runtime_error("local a = setmetatable({}, {}); return a + 1")
    t:runtime_error("local a = setmetatable({}, {}); return a < a")
    t:runtime_error("local a = setmetatable({}, {}); return a()")
end
