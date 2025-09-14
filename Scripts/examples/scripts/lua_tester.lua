--this script is testing lua. the lua virtual machine must pass all these tests

if start then return end
start = true
bad = 0

function badMsg(msg)
    bad = bad + 1
    print("bad: " .. msg)
end

print("------------------")

--------------------------------

anyvar = true
function func(anyvar)
    if anyvar then
        badMsg("test 1")
    end
end
func()

--------------------------------

do
    local anyVar2 = true
    function func2()
        if not anyVar2 then
            badMsg("test 2")
        end
    end
end
func2()

--------------------------------

local ok, code = pcall(loadstring, "return #{...}")
if ok and code then
    local ok, data = pcall(code, 1, 2, 3, 4, 5)
    if not ok or data ~= 5 then
        badMsg("test 3")
    end
else
    badMsg("test 3 (preparation)")
end

--------------------------------

function func3(a, b, ...)
    local tbl = {...}
    if #tbl ~= 3 then
        badMsg("test 4")
    end
end
func3(1, 2, 3, 4, 5)

--------------------------------

funcs = {}
for index, value in ipairs({1, 2, 3, 4, 5}) do
    funcs[index] = function ()
        return value
    end
end

if funcs[3]() ~= 3 then
    badMsg("test 5")
end

--------------------------------

local ok = pcall(load, "--[[any test\nany new line]]")
if not ok then
    badMsg("test 6")
end

--------------------------------

local ok, code = pcall(load, [[
::lbl::
if asd then
    return b
end
local b = 2
asd = true
goto lbl
]])
if ok and code then
    local ok, data = pcall(code)
    if not ok or data ~= nil then
        badMsg("test 7")
    end
else
    badMsg("test 7 (preparation)")
end

--------------------------------

do
    local test = 1
end
if test then
    badMsg("test 8")
end

--------------------------------

do
    local function getValues()
        return 1, 2, 3
    end
    local tbl1 = {0, getValues()}
    local tbl2 = {0, getValues(), 2}
    local tbl3 = {getValues()}
    local tbl4 = {getValues(), 2}

    if tbl1[1] ~= 0 or tbl1[2] ~= 1 or tbl1[3] ~= 2 or tbl1[4] ~= 3 or #tbl1 ~= 4 then
        badMsg("test 9. part 1")
    end
    if tbl2[1] ~= 0 or tbl2[2] ~= 1 or tbl2[3] ~= 2 or #tbl2 ~= 3 then
        badMsg("test 9. part 2")
    end
    if tbl3[1] ~= 1 or tbl3[2] ~= 2 or tbl3[3] ~= 3 or #tbl3 ~= 3 then
        badMsg("test 9. part 3")
    end
    if tbl4[1] ~= 1 or tbl4[2] ~= 2 or #tbl4 ~= 2 then
        badMsg("test 9. part 4")
    end
end

--------------------------------

do
    local anyVar3 = 7
    function tchange()
        anyVar3 = 3
    end
    function tget()
        return anyVar3
    end
end
if tget() ~= 7 then
    badMsg("test 10. part1")
end
tchange()
if tget() ~= 3 then
    badMsg("test 10. part2")
end

--------------------------------

if bad > 0 then
    print("bad-lua: " .. bad)
else
    print("normal-lua: " .. bad)
end