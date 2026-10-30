return function(t)
    local P = t.P

    -- Deep interpreter recursion (explicit VM frames, not host C recursion).
    t:expect1([[
local function f(n)
    if n == 0 then return 0 end
    return 1 + f(n - 1)
end
return f(5000)
]], 5000)

    -- Many active locals.
    local n = 150
    local names, values, terms = {}, {}, {}
    for i = 1, n do
        names[i] = "x" .. i
        values[i] = tostring(i)
        terms[i] = "x" .. i
    end
    local src = "local " .. table.concat(names, ",") .. " = " ..
        table.concat(values, ",") .. "\nreturn " ..
        table.concat(terms, " + ")
    local f, err = t:compile(src)
    t:check(f ~= nil, "150 locals compile: " .. tostring(err))
    if f then
        local ok, v = pcall(f)
        t:check(ok and v == n * (n + 1) / 2,
            "150 locals result: " .. tostring(v))
    end

    -- Large table constructor.
    local items = {}
    for i = 1, 1000 do items[i] = tostring(i) end
    local table_src = "local t = {" .. table.concat(items, ",") ..
        "}; return #t, t[1], t[1000]"
    t:expect(table_src, P(1000, 1, 1000))

    -- Large source / many statements.
    local lines = { "local s = 0" }
    for i = 1, 2000 do
        lines[#lines + 1] = "s = s + " .. (i % 7)
    end
    lines[#lines + 1] = "return s"
    local sum = 0
    for i = 1, 2000 do sum = sum + (i % 7) end
    t:expect(table.concat(lines, "\n"), P(sum))

    -- Big loop in the VM.
    t:expect1([[
local s = 0
for i = 1, 100000 do s = s + i end
return s
]], 5000050000)

    -- Long string and long comment.
    local big = string.rep("a", 100000)
    t:expect1("return # [[" .. big .. "]]", 100000)
    t:expect1("--[[" .. string.rep("x", 100000) .. "]] return 7", 7)

    -- Nested do blocks.
    local depth = 200
    local nested = string.rep("do ", depth) ..
        "return 123 " .. string.rep("end ", depth)
    t:expect1(nested, 123)

    -- Nested parentheses.
    local expr = "return " .. string.rep("(", 200) .. "1" ..
        string.rep(")", 200)
    t:expect1(expr, 1)

    -- Many parameters and many return values.
    local params, args = {}, {}
    for i = 1, 120 do
        params[i] = "a" .. i
        args[i] = tostring(i)
    end
    t:expect1("local function f(" .. table.concat(params, ",") ..
        ") return a1 + a120 end return f(" .. table.concat(args, ",") .. ")",
        121)

    local rets = {}
    for i = 1, 100 do rets[i] = tostring(i) end
    t:expect1("local function f() return " .. table.concat(rets, ",") ..
        " end return select('#', f())", 100)

    -- Many closures over loop variables.
    t:expect1([[
local fs = {}
for i = 1, 100 do fs[i] = function() return i end end
local s = 0
for i = 1, 100 do s = s + fs[i]() end
return s
]], 5050)

    -- A table with many keyed fields.
    local fields = {}
    for i = 1, 500 do
        fields[#fields + 1] = "k" .. i .. "=" .. i
    end
    t:expect1("local t={" .. table.concat(fields, ",") ..
        "}; return t.k1 + t.k500", 501)
end
