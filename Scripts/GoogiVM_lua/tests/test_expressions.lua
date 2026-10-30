return function(t)
    local P = t.P

    t:expect1("return 1 + 2 * 3", 7)
    t:expect1("return (1 + 2) * 3", 9)
    t:expect1("return 17 % 5", 2)
    t:expect1("return 2 ^ 3 ^ 2", 512)
    t:expect1("return -2 ^ 2", -4)
    t:expect1("return (-2) ^ 2", 4)
    t:expect1("return 2 ^ -3", 0.125)
    t:expect1("return -2 ^ -2", -0.25)
    t:expect1("return 1 .. 2 .. 3", "123")
    t:expect1("return 1 + 2 .. 3 * 4", "312")
    t:expect1("return 1 < 2", true)
    t:expect1("return 2 <= 2", true)
    t:expect1("return 3 > 2", true)
    t:expect1("return 3 >= 3", true)
    t:expect1("return 1 == 1", true)
    t:expect1("return 1 ~= 2", true)
    t:expect1("return 'a' < 'b'", true)
    t:expect1("return not 1 == 2", false)
    t:expect1("return not (1 == 2)", true)
    t:expect1("return not not 0", true)
    t:expect1("return #'hello'", 5)
    t:expect1("return #{1, 2, 3, 4}", 4)
    t:expect1("return #{}", 0)

    t:expect1("return false and error('no')", false)
    t:expect1("return nil and error('no')", nil)
    t:expect1("return 3 or error('no')", 3)
    t:expect1("return false or 9", 9)
    t:expect1("return nil or false", false)
    t:expect1("return 1 and 2", 2)
    t:expect1("return 0 and 5", 5)
    t:expect1("return '' or 5", "")
    t:expect1("return nil and 1 or 2", 2)
    t:expect1("return false or true and false", false)
    t:expect1("return 1 or 2 and 3", 1)

    t:expect1("return '2' + 3", 5)
    t:expect1("return '2.5' * 2", 5)
    t:expect1("return '10' - 1", 9)

    t:runtime_error("return 1 .. true")
    t:runtime_error("return 1 + nil")
    t:runtime_error("return nil + 1")
    t:runtime_error("return -nil")
    t:runtime_error("return #123")
    t:runtime_error("return true < false")
    t:runtime_error("return 1 < '2'")
    t:runtime_error("return nil .. 'x'")
    t:runtime_error("return {} + 1")
    t:runtime_error("local f; return f()")
    t:runtime_error("return (nil).x")
    t:runtime_error("local t; return t[1]")

    -- Parentheses suppress multiple results; tests here only check values.
    t:expect1("return (((1)))", 1)

    -- Differential precedence/operator checks.
    local exprs = {
        "1+2*3",
        "1*2+3",
        "1+2*3^2",
        "2^3^2",
        "-2^2",
        "-2^-2",
        "2^-3^2",
        "1 .. 2 .. 3",
        "1+2 .. 3*4",
        "1<2 == true",
        "false or true and false",
        "1 or 2 and 3",
        "nil and 1 or 2",
        "not 1 == 2",
        "not nil == true",
        "'a' .. 'b' == 'ab'",
        "1 == 1 and 2 == 2",
        "1+2 > 2 and 3*3 == 9",
        "#'abc' + 1",
        "-#'abcd'",
        "1 < 2 or 3 < 2 and false",
        "0 and 5 or 6",
        "'' and 5 or 6",
        "false and 5 or 6",
        "not false and not nil",
        "1 ~= 2 and 2 ~= 3",
        "10 % 3 == 1",
        "2^10 == 1024",
    }
    for i = 1, #exprs do
        t:compare("return " .. exprs[i])
    end

    -- Host-specific but valid in Lua 5.1/LuaJIT.
    t:compare("return -7 % 3")
    t:compare("return 7 % -3")
    t:compare("return 1/0")
    t:compare("return -1/0")
    t:compare("return 0/0")
end
