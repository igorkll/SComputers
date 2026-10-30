return function(t)
    local P = t.P

    -- Generic for stops only on nil, not on false.
    t:expect([[
local calls = 0
for k in function()
    calls = calls + 1
    if calls == 1 then return false end
    if calls == 2 then return 'x' end
    return nil
end do end
return calls
]], P(3))

    -- The loop variable is independent from the internal control value.
    t:expect("local s = 0; for i = 1, 3 do s = s + i; i = 100 end return s", P(6))
    t:expect("local s = 0; for k, v in ipairs({1, 2, 3}) do s = s + v; v = 100 end return s", P(6))

    -- Each loop iteration gets a fresh captured cell.
    t:expect([[
local t = {}
for i = 1, 3 do t[i] = function() return i end end
return t[1](), t[2](), t[3]()
]], P(1, 2, 3))

    t:expect([[
local t = {}
for k, v in ipairs({10, 20, 30}) do t[k] = function() return k, v end end
local a, b = t[1]()
local c, d = t[2]()
local e, f = t[3]()
return a, b, c, d, e, f
]], P(1, 10, 2, 20, 3, 30))

    -- Captured locals are backpatched even when accessed before the capture.
    t:expect([[
local x = 1
x = 2
local f = function() return x end
x = 3
return f()
]], P(3))

    -- Repeat body locals are visible in the until condition.
    t:expect("local i = 0; repeat local x = i + 1; i = x until x == 4; return i", P(4))

    -- Last list field expands even with a trailing separator.
    t:expect("local function f() return 1, 2, 3 end local t = {f(),} return #t, t[3]", P(3, 3))

    -- Last argument expands.
    t:expect([[
local function f() return 2, 3 end
local function g(a, b, c) return a * 100 + b * 10 + c end
return g(1, f())
]], P(123))

    -- false is a valid table key for pairs/next.
    t:expect([[
local t = {[false] = 'f', a = 1}
local count, ff, aa = 0, nil, nil
for k, v in pairs(t) do
    count = count + 1
    if k == false then ff = v else aa = v end
end
return count, ff, aa
]], P(2, "f", 1))

    -- Parenthesized call is a valid statement.
    t:expect([[
local hit = false
local function f() hit = true end
(f)()
return hit
]], P(true))

    -- Field assignment through a call result.
    t:expect([[
local t = {}
local function f() return t end
f().x = 5
return t.x
]], P(5))

    -- More than 60 upvalues in a script function.
    local names = {}
    local values = {}
    local terms = {}
    for i = 1, 100 do
        names[i] = "x" .. i
        values[i] = i
    end
    local src = "local " .. table.concat(names, ",") .. " = " ..
        table.concat(values, ",") .. "\n" ..
        "local function f() return " .. table.concat(names, " + ") ..
        " end\nreturn f()"
    local f, err = t:compile(src)
    t:check(f ~= nil, "100-upvalue compile: " .. tostring(err))
    if f then
        local ok, v = pcall(f)
        t:check(ok and v == 5050, "100-upvalue result: " .. tostring(v))
    end

    -- Nested upvalue propagation through an intermediate function.
    t:expect([[
local x = 1
local function outer()
    local y = 10
    local function middle()
        local z = 100
        return function()
            x = x + 1
            y = y + 1
            z = z + 1
            return x, y, z
        end
    end
    return middle()
end
local f = outer()
local a, b, c = f()
local d, e, g = f()
return a, b, c, d, e, g
]], P(2, 11, 101, 3, 12, 102))

    -- Assignment evaluation order with table bases and keys.
    t:expect([[
local log = {}
local t = {}
local function f(n) log[#log + 1] = n; return n end
local function b(n) log[#log + 1] = n; return t end
b(1)[f(2)], b(3)[f(4)] = f(5), f(6)
return t[2], t[4], table.concat(log, ',')
]], P(5, 6, "1,2,3,4,5,6"))

    -- Vararg in the middle and at the end of a return list.
    t:expect([[
local function f(...) return ..., 99 end
return f(1, 2, 3)
]], P(1, 99))

    t:expect([[
local function f(...) return 99, ... end
return f(1, 2, 3)
]], P(99, 1, 2, 3))
end
