local function randname()
    local funcname =  "__"
    for i = 1, 16 do
        funcname = funcname .. tostring(math.floor(math.random(0, 9)))
    end
    return funcname
end

function ll_fix(code) --тут фикситься несколько багов
    local fmain = randname()
    local farg = randname()

    return fmain .. " = " .. fmain .. " or function(...) " .. code .. "\n end return " .. fmain .. "(" .. farg .. "())", farg
end

function ll_shorterr(err)
    return tostring(err or "unknown error")

    --[[
    local function a(str)
        return str:gsub("%p", "%%%1")
    end
    err = err:gsub(a("...ripts/remade-lua-in-lua/lua"), "ll")
    err = err:gsub(a("remade-lua-in-lua/lua"), "ll")
    err = err:gsub(a("interpreter.lua"), "i")
    err = err:gsub(a("parser.lua"), "p")
    err = err:gsub(a("scanner.lua"), "s")
    return err
    ]]
end