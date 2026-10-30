return function(t)
    math.randomseed(1234567)

    -- Differential expression fuzzing.
    local atoms = { "0", "1", "2", "3", "-1", "0.5", "true", "false", "nil" }
    local bins = {
        "+", "-", "*", "/", "%", "^", "==", "~=", "<", "<=", ">", ">=",
        "and", "or",
    }

    local function expr(depth)
        if depth <= 0 then
            return atoms[math.random(#atoms)]
        end
        local r = math.random(10)
        if r <= 2 then
            return atoms[math.random(#atoms)]
        elseif r <= 4 then
            return "(" .. expr(depth - 1) .. ")"
        elseif r <= 5 then
            return "(not " .. expr(depth - 1) .. ")"
        elseif r <= 6 then
            return "(- " .. expr(depth - 1) .. ")"
        else
            return "(" .. expr(depth - 1) .. " " ..
                bins[math.random(#bins)] .. " " .. expr(depth - 1) .. ")"
        end
    end

    local expr_count = 15000
    for i = 1, expr_count do
        t:compare("return " .. expr(4))
        if t.failed >= 20 then break end
    end

    -- Differential statement/program fuzzing.
    local names = { "a", "b", "c", "d" }
    local function pick(x) return x[math.random(#x)] end
    local function atom()
        local r = math.random(5)
        if r == 1 then return tostring(math.random(1, 9)) end
        if r == 2 then return pick(names) end
        if r == 3 then return "(" .. pick(names) .. "+" .. math.random(1, 5) .. ")" end
        if r == 4 then return "i" end
        return "x"
    end
    local function expr2(depth)
        if depth <= 0 then return atom() end
        local r = math.random(8)
        if r <= 2 then return atom() end
        if r == 3 then return "(" .. expr2(depth - 1) .. ")" end
        if r == 4 then return "(- " .. expr2(depth - 1) .. ")" end
        if r == 5 then return "not " .. expr2(depth - 1) end
        local ops = { "+", "-", "*", "==", "~=", "<", ">=", "and", "or" }
        return "(" .. expr2(depth - 1) .. " " .. pick(ops) .. " " ..
            expr2(depth - 1) .. ")"
    end
    local function assign(allow_i)
        local target = pick(names)
        return target .. " = " .. expr2(2)
    end
    local function block()
        local out = {}
        for i = 1, math.random(1, 3) do
            out[#out + 1] = assign()
        end
        return table.concat(out, "; ")
    end
    local function stmt()
        local r = math.random(12)
        if r <= 4 then
            return assign()
        elseif r == 5 then
            return "if " .. expr2(2) .. " then " .. block() ..
                " else " .. block() .. " end"
        elseif r == 6 then
            return "for i=1," .. math.random(1, 4) .. " do " .. block() .. " end"
        elseif r == 7 then
            return "do local i=0; while i<" .. math.random(1, 4) ..
                " do i=i+1; " .. block() .. " end end"
        elseif r == 8 then
            return "do local i=0; repeat i=i+1; " .. block() ..
                " until i>=" .. math.random(1, 4) .. " end"
        elseif r == 9 then
            return "local function f(x) return " .. expr2(2) .. " end; a=f(a)"
        elseif r == 10 then
            return "local t={" .. expr2(1) .. "," .. expr2(1) ..
                ",k=" .. expr2(1) .. "}; a=t[1]+t.k"
        elseif r == 11 then
            return "for k,v in ipairs({" .. math.random(1, 5) .. "," ..
                math.random(1, 5) .. "," .. math.random(1, 5) ..
                "}) do a=a+v end"
        else
            return "if " .. expr2(1) .. " then local x=9; a=a+x end"
        end
    end
    local function program()
        local out = { "local a,b,c,d=1,2,3,4", "local x=5", "local i=0" }
        for i = 1, math.random(4, 10) do
            out[#out + 1] = stmt()
        end
        out[#out + 1] = "return a,b,c,d"
        return table.concat(out, "\n")
    end

    local stmt_count = 3000
    for i = 1, stmt_count do
        t:compare(program())
        if t.failed >= 20 then break end
    end
end
