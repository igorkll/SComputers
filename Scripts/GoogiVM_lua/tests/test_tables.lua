return function(t)
    local P = t.P

    t:expect1("local t = {}; return #t", 0)
    t:expect("local t = {1, 2, 3}; return t[1], t[2], t[3], #t", P(1, 2, 3, 3))
    t:expect("local t = {a = 1, b = 2}; return t.a, t.b, t.c", P(1, 2, nil))
    t:expect("local t = {[1] = 'a', [true] = 't'}; return t[1], t[true]", P("a", "t"))
    t:expect("local t = {[false] = 'f'}; return t[false]", P("f"))
    t:expect("local t = {1; 2, a = 3, [4] = 5,}; return t[1], t[2], t.a, t[4]", P(1, 2, 3, 5))
    t:expect("local t = {[1] = 'a', [1] = 'b'}; return t[1]", P("b"))
    t:expect("local t = {a = 1, a = 2}; return t.a", P(2))
    t:expect("local t = {[1] = 'x', 'y'}; return t[1]", P("y"))
    t:expect("local t = {'x', [1] = 'y'}; return t[1]", P("y"))

    t:expect([[
local t = {1, {2, {3, 4}}, 5}
return t[1], t[2][1], t[2][2][2], t[3]
]], P(1, 2, 4, 5))

    t:expect([[
local t = { [true] = 'yes', [false] = 'no', [1 + 2] = 'three' }
return t[true], t[false], t[3]
]], P("yes", "no", "three"))

    t:expect([[
local function f() return 1, 2, 3 end
local t = {0, f()}
return #t, t[1], t[2], t[4]
]], P(4, 0, 1, 3))

    t:expect([[
local function f() return 1, 2, 3 end
local t = {f(), f()}
local a, b, c, d = t[1], t[2], t[3], t[4]
return a, b, c, d
]], P(1, 1, 2, 3))

    t:expect([[
local function f() return 1, 2, 3 end
local t = {f(), 9}
return t[1], t[2]
]], P(1, 9))

    t:expect([[
local function f() return 1, 2, 3 end
local t = {f(),}
return #t, t[1], t[2], t[3]
]], P(3, 1, 2, 3))

    t:expect([[
local function f(...) local t = {0, ...}; return #t, t[1], t[4] end
return f(4, 5, 6)
]], P(4, 0, 6))

    t:expect([[
local t = {x = 1}
function t:add(a, b) self.x = self.x + a + b; return self.x end
return t:add(2, 3), t:add(1, 1)
]], P(6, 8))

    t:expect([[
local t = {a = {b = {c = 7}}}
return t.a.b.c
]], P(7))

    t:expect([[
local function f(x) return x * 2 end
local t = {f(3), f(4)}
return t[1], t[2]
]], P(6, 8))

    t:expect([[
local function f() return {10, 20, 30} end
return f()[2]
]], P(20))

    t:expect([[
local t = {}
t[2] = 5
t['a'] = 6
t.a = t.a or 7
return t[2], t.a
]], P(5, 6))

    t:expect([[
local t = {a = {b = {}}}
t.a.b.c = 9
t.a.b['d'] = 10
return t.a.b.c, t.a.b.d
]], P(9, 10))

    t:expect([[
local t = {}
local function f() return t end
f().x = 5
f()[1] = 6
return t.x, t[1]
]], P(5, 6))

    t:expect([[
local t = {}
local n = 0
local function f() n = n + 1; return t end
f().a, f().b = n, n + 10
return t.a, t.b, n
]], P(2, 12, 2))

    t:expect([[
local function f(s) return s .. '!' end
return f'hi'
]], P("hi!"))

    t:expect([[
local function f(t) return t.x end
return f{x = 8}
]], P(8))

    t:expect([[
local t = {a = {b = {}}}
function t.a.b.c() return 8 end
return t.a.b.c()
]], P(8))

    t:expect([[
local t = {a = {b = {}}}
function t.a.b:c(v) return self.x + v end
t.a.b.x = 5
return t.a.b:c(7)
]], P(12))

    t:expect([[
local t = {}
function t:m() return self end
return t:m() == t
]], P(true))

    t:expect([[
local function f() return 1, 2, 3 end
local function g(a, b, c, d) return a + b + c + d end
return g(0, f())
]], P(6))

    t:compare([[
local t = {1, 2, 3}
local a, b, c, d = t[1], t[2], t[3], t[4]
return a, b, c, d
]])

    t:compare([[
local function f() return 1, 2, 3 end
local t = {f(), f()}
return #t, t[1], t[2], t[3]
]])

    t:compare("return {1, 2, a = 3, [4] = 'x'}")
    t:compare("local t = {a = {b = {1, 2}}}; return t")

    -- Multi-return values are adjusted to one in keyed/named fields.
    t:expect([[
local function f() return 1, 2 end
local t = {a = f(), [5] = f()}
return t.a, t[5]
]], P(1, 1))

    -- Last list field expands with a trailing semicolon too.
    t:expect([[
local function f() return 1, 2, 3 end
local t = {f();}
return #t, t[2], t[3]
]], P(3, 2, 3))

    -- Parenthesized table and function results can be indexed.
    t:expect("return ({x = 1}).x", P(1))
    t:expect("return (function() return {x = 2} end)().x", P(2))

    -- Calls with table/string sugar in expression position.
    t:expect([[
local function f(x) return x end
return f'abc', f{2}[1]
]], P("abc", 2))

    t:expect([[
local t = {}
function t:m(x) return x end
return t:m'abc', t:m{1}[1]
]], P("abc", 1))
end
