return function(t)
    local P = t.P

    -- Locals, globals, multiple assignment.
    t:expect1("local x = 5; return x", 5)
    t:expect1("local a, b = 1, 2; a, b = b, a; return a * 10 + b", 21)
    t:expect1("local a, b = 1, 2, 3; return a * 10 + b", 12)
    t:expect1("local a, b = 1; return a * 10 + (b or 0)", 10)
    t:expect1("local a, b, c = 1, 2, 3; a, b, c = c, a, b; return a * 100 + b * 10 + c", 312)
    local env = {}
    local f = assert(t:compile("x = 42", env))
    local ok = pcall(f)
    t:check(ok and env.x == 42, "global assignment must write into env")
    t:expect1("return x", 9, { x = 9 })
    t:expect1("local x = 1; do local x = 2 end; return x", 1)
    t:expect1("local x = 1; local x = x + 1; local x = x + 1; return x", 3)

    -- If/elseif/else and branch scopes.
    t:expect1("if true then return 1 else return 2 end", 1)
    t:expect1("if false then return 1 else return 2 end", 2)
    t:expect1("if nil then return 1 elseif 3 == 3 then return 3 else return 4 end", 3)
    t:expect1("if false then elseif false then elseif true then return 7 end return 8", 7)
    t:expect1("local x = 1; if false then local x = 2 else x = 3 end; return x", 3)
    t:expect1("local x = 1; if true then local x = 2 end; return x", 1)

    -- While.
    t:expect1("local i = 0; while i < 5 do i = i + 1 end; return i", 5)
    t:expect1("local i = 0; while true do i = i + 1; if i == 3 then break end end; return i", 3)
    t:expect1("local i = 0; while i < 3 do local x = i; i = x + 1 end; return i", 3)

    -- Repeat.
    t:expect1("local i = 0; repeat i = i + 1 until i == 3; return i", 3)
    t:expect1("local i = 0; repeat local x = i + 1; i = x until x == 4; return i", 4)
    t:expect1("local i = 0; repeat i = i + 1; if i == 2 then break end until false; return i", 2)
    t:expect1("local i = 0; repeat i = i + 1 until true; return i", 1)

    -- Numeric for.
    t:expect1("local s = 0; for i = 1, 5 do s = s + i end; return s", 15)
    t:expect1("local s = 0; for i = 5, 1, -2 do s = s + i end; return s", 9)
    t:expect1("local s = 0; for i = 1, 6, 2 do s = s + i end; return s", 9)
    t:expect1("local s = 0; for i = 1.5, 3.5, 0.5 do s = s + i end; return s", 12.5)
    t:expect1("local n = 0; for i = 1, 0 do n = n + 1 end; return n", 0)
    t:expect1("local n = 0; for i = 1, 3, 0.5 do n = n + 1 end; return n", 5)
    t:expect1("local s = 0; for i = '1', '3' do s = s + i end; return s", 6)
    t:expect1("local i = 99; for i = 1, 2 do end; return i", 99)
    t:expect1("local t = {}; for i = 1, 3 do t[#t + 1] = i; i = 100 end; return t[1] + t[2] + t[3]", 6)
    t:expect("local i = 5; local s = 0; for i = i, i + 1 do s = s + i end; return s, i", P(11, 5))

    -- Break and nested loops.
    t:expect1("local s = 0; for i = 1, 3 do for j = 1, 3 do if j == 2 then break end; s = s + 1 end end; return s", 3)
    t:expect1("local s = 0; for i = 1, 3 do if i == 2 then break end; s = s + i end; return s", 1)
    t:expect1("local n = 0; for i = 1, 2 do while true do n = n + 1; break end end; return n", 2)

    -- Generic for.
    t:expect1("local s = 0; for k, v in ipairs({10, 20, 30}) do s = s + v end; return s", 60)
    t:expect1("local s = 0; for k, v in pairs({a = 1, b = 2}) do s = s + v end; return s", 3)
    t:expect1("local s = 0; for k, v in next, {a = 1, b = 2} do s = s + v end; return s", 3)
    t:expect1([[
local function iter(state, ctrl)
    ctrl = ctrl + 1
    if ctrl <= state then return ctrl, ctrl * 2 end
end
local s = 0
for k, v in iter, 3, 0 do s = s + v end
return s
]], 12)
    t:expect1([[
local n = 0
local calls = 0
for k in function() calls = calls + 1; if calls == 1 then return false end; if calls == 2 then return 'x' end; return nil end do
    n = n + 1
end
return n
]], 2)
    t:expect([[
local t = {[false] = 'f', a = 1}
local count, ff, aa = 0, nil, nil
for k, v in pairs(t) do
    count = count + 1
    if k == false then ff = v else aa = v end
end
return count, ff, aa
]], P(2, "f", 1))
    t:expect1("local t = {}; for i = 1, 3 do t[i] = i end; local s = 0; for k, v in ipairs(t) do s = s + v end return s", 6)
    t:expect1("local n = 0; for k in function() return nil end do n = n + 1 end; return n", 0)

    -- Generic for evaluates the explist once.
    t:expect([[
local calls = 0
local function iterator()
    calls = calls + 1
    if calls == 1 then return 1 end
    return nil
end
local n = 0
for k in iterator do n = n + 1 end
return calls, n
]], P(2, 1))

    -- Scopes after loops and branches.
    t:expect1("local x = 1 for i = 1, 2 do local x = i end return x", 1)
    t:expect1("local x = 1 for k, v in ipairs({2, 3}) do local x = v end return x", 1)
    t:expect1("local x = 1 while x < 3 do local y = x; x = y + 1 end return x", 3)
    t:expect("local a, b = 1, 2 repeat local c = a + b; a = b; b = c until c > 10 return a, b, c", P(8, 13, nil))

    -- Generic for explist can expand the last call or vararg.
    t:expect([[
local function triple() return next, {a = 1, b = 2}, nil end
local s = 0
for k, v in triple() do s = s + v end
return s
]], P(3))

    t:expect([[
local function run(...)
    local s = 0
    for k, v in ... do s = s + v end
    return s
end
return run(next, {a = 1, b = 2}, nil)
]], P(3))

    -- Return from inside loops.
    t:expect([[
local function f()
    for i = 1, 5 do
        if i == 3 then return i end
    end
end
return f()
]], P(3))

    t:expect([[
local function f()
    while true do return 7 end
end
return f()
]], P(7))

    t:expect([[
local function f()
    repeat return 9 until true
end
return f()
]], P(9))
end
