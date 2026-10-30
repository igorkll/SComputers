return function(t)
    local P = t.P

    t:expect("return 1, 2, 3", P(1, 2, 3))
    t:expect("return", P())
    t:expect("local function f() return 1, 2, 3 end return f()", P(1, 2, 3))
    t:expect("local function f() return 1, 2, 3 end return (f())", P(1))
    t:expect("local function f() return 1, 2, 3 end return f(), 9", P(1, 9))
    t:expect("local function f() return 1, 2, 3 end return 0, f()", P(0, 1, 2, 3))

    t:expect("local function f() return 1, 2, 3 end local a, b, c = f() return a, b, c", P(1, 2, 3))
    t:expect("local function f() return 1, 2, 3 end local a, b = f() return a, b", P(1, 2))
    t:expect("local function f() return 1, 2, 3 end local a = f() return a", P(1))
    t:expect("local function f() return 1, 2, 3 end local a, b, c = f(), 9 return a, b, c", P(1, 9, nil))
    t:expect("local function f() return 1, 2, 3 end local a, b = f(), 9 return a, b", P(1, 9))
    t:expect("local function f() return 1, 2, 3 end local a, b, c = 0, f() return a, b, c", P(0, 1, 2))

    t:expect("local function f() return 1, 2, 3 end local t = {f()} return t[1], t[2], t[3]", P(1, 2, 3))
    t:expect("local function f() return 1, 2, 3 end local t = {0, f()} return t[1], t[2], t[4]", P(0, 1, 3))
    t:expect("local function f() return 1, 2, 3 end local t = {f(), 0} return t[1], t[2]", P(1, 0))

    t:expect([[
local function f() return 2, 3 end
local function g(a, b, c) return a * 100 + b * 10 + c end
return g(1, f())
]], P(123))

    t:expect([[
local function f() return 2, 3 end
local function g(a, b, c) return a * 100 + b * 10 + (c or 0) end
return g(f(), 1)
]], P(210))

    t:expect([[
local function f() return end
local function g(...) return select('#', ...) end
return g(f())
]], P(0))

    t:expect([[
local function f() return nil, 2, 3 end
local a, b, c = f()
return a, b, c
]], P(nil, 2, 3))

    -- Varargs.
    t:expect("local function f(...) return ... end return f(1, 2, 3)", P(1, 2, 3))
    t:expect("local function f(a, ...) return a, ... end return f(1, 2, 3)", P(1, 2, 3))
    t:expect("local function f(a, b, ...) return a, b, select('#', ...), ... end return f(1, 2, 3, 4)", P(1, 2, 2, 3, 4))
    t:expect("local function f(...) return select('#', ...) end return f()", P(0))
    t:expect("local function f(...) return select('#', ...) end return f(nil, nil)", P(2))
    t:expect("local function f(...) return select(2, ...) end return f(1, 2, 3)", P(2, 3))
    t:expect("local function f(...) return {...} end local t = f(1, 2, 3) return #t, t[1], t[3]", P(3, 1, 3))
    t:expect("local function f(...) return {0, ...} end local t = f(1, 2, 3) return #t, t[1], t[4]", P(4, 0, 3))
    t:expect("local function f(...) local a, b, c = ... return a, b, c end return f(1, 2, 3)", P(1, 2, 3))
    t:expect("local function f(...) local a, b, c = 0, ... return a, b, c end return f(1, 2)", P(0, 1, 2))
    t:expect("local function f(...) local function g(...) return ... end return g(...) end return f(1, 2, 3)", P(1, 2, 3))
    t:expect("local function f(a, ...) return function(...) return a, ... end end local g = f(1, 2, 3) return g(4, 5)", P(1, 4, 5))
    t:expect("local function f(...) return ... end return f()", P())
    t:expect("local function f(...) return ... end local a, b, c = f(1, 2) return a, b, c", P(1, 2, nil))
    t:expect("local function f(...) return ... end local t = {f(1, 2)} return #t, t[2]", P(2, 2))
    t:expect("local function f(...) return ... end local function g(...) return select('#', ...), ... end return g(f(1, 2, 3))", P(3, 1, 2, 3))
    t:expect("local function f(...) return select('#', ...), ... end return f(1, nil, 3)", P(3, 1, nil, 3))

    -- Top-level chunk is vararg.
    t:expect("return ...", P(7, 8, 9), t.env, 7, 8, 9)
    t:expect("return select('#', ...)", P(2), t.env, nil, nil)

    -- Non-vararg function cannot use ...
    t:compile_error("local function f() return ... end")
    t:compile_error("local f = function() return ... end")
    t:compile_error("function f() return ... end")
    t:compile_error("local function f() local g = function() return ... end end")

    -- Native and custom multi-return interop.
    t:expect("return string.find('hello', 'll')", P(3, 4), t.env)
    t:compare("local function f() return 1, 2, 3 end local function g(...) return select('#', ...), ... end return g(f())")
    t:compare("local function f() return 1, 2, 3 end return f(), f()")
    t:compare("local function f() return end local a, b = 1, 2 a, b = f() return a, b")
    t:compare("local function f() return end local t = {0, f()} return #t, t[1]")
end
