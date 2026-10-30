return function(t)
    local P = t.P

    -- Empty/whitespace-only chunks.
    t:expect("", P())
    t:expect(" \t\r\n\f\v ", P())
    t:expect(";;;", P())

    -- Comments.
    t:expect("-- comment", P())
    t:expect1("-- comment\nreturn 1", 1)
    t:expect1("return 1 -- trailing", 1)
    t:expect1("return 1 --[[block]] + 2", 3)
    t:expect1("return 1 --[==[block\nwith ]] inside]==] + 2", 3)
    t:expect1("--[[ only comment ]] return 9", 9)
    t:expect1("return 1\r\n+ 2", 3)
    t:expect1("return 1\r+ 2", 3)

    -- Numeric literals.
    t:expect1("return 123", 123)
    t:expect1("return 0", 0)
    t:expect1("return 1.5", 1.5)
    t:expect1("return .5", 0.5)
    t:expect1("return 1.", 1.0)
    t:expect1("return 1e2", 100)
    t:expect1("return 1E-2", 0.01)
    t:expect1("return 2.5e+2", 250)
    t:expect1("return 0xFF", 255)
    t:expect1("return 0x10 + 1", 17)
    t:expect1("return -7", -7)
    t:expect1("return - 7", -7)

    -- Short strings and escapes.
    t:expect1([[return 'abc']], "abc")
    t:expect1([[return "abc"]], "abc")
    t:expect1([=[return "a\nb"]=], "a\nb")
    t:expect1([=[return "a\tb"]=], "a\tb")
    t:expect1([=[return "\a\b\f\n\r\t\v"]=], "\a\b\f\n\r\t\v")
    t:expect1([=[return "\\\"\'"]=], "\\\"'")
    t:expect1([=[return "\065\066\067"]=], "ABC")
    t:expect1([=[return "\0"]=], "\0")
    t:expect1([=[return "a\
b"]=], "a\nb")
    t:expect1([=[return 'a"b']=], 'a"b')
    t:expect1([=[return "a'b"]=], "a'b")

    -- Long strings.
    t:expect1("return [[abc]]", "abc")
    t:expect1("return [[a\nb]]", "a\nb")
    t:expect1("return [[\nabc]]", "abc")
    t:expect1("return [==[a]b]==]", "a]b")
    t:expect1("return [=[one\ntwo]=]", "one\ntwo")
    t:expect1("return [==[a]==]", "a")

    -- UTF-8 is just bytes inside string literals.
    t:expect1([[return "Привет"]], "Привет")

    -- Token boundaries / operators used by expressions.
    t:expect1("return 1+2", 3)
    t:expect1("return 3-2", 1)
    t:expect1("return 2*3", 6)
    t:expect1("return 6/2", 3)
    t:expect1("return 7%4", 3)
    t:expect1("return 2^3", 8)
    t:expect1("return 1 .. 2", "12")
    t:expect1("return 1==1", true)
    t:expect1("return 1~=2", true)
    t:expect1("return 1<2", true)
    t:expect1("return 1<=1", true)
    t:expect1("return 2>1", true)
    t:expect1("return 2>=2", true)
    t:expect1("return #'abcd'", 4)
    t:expect1("return not nil", true)
    t:expect1("return true and false or true", true)

    -- Semicolons and empty statements.
    t:expect1(";;; return 5 ;;;", 5)
    t:expect1("local x=1; return x;", 1)

    -- Malformed tokens / literals.
    t:compile_error("return 'abc")
    t:compile_error('return "abc')
    t:compile_error("return [[abc")
    t:compile_error("--[[ unfinished")
    t:compile_error("--[=[ unfinished")
    t:compile_error([[return "\z"]])
    t:compile_error([[return "\256"]])
    t:compile_error("@")
    t:compile_error("return $")
    t:compile_error("return 0x")
    t:compile_error("return 1.2.3")
    t:compile_error("return 1..2")
    t:compile_error("return 0x1..2")
    t:compile_error("return 1e")

    -- Numeric and string results that are easy to get wrong.
    t:expect1("return 1 .. 'x'", "1x")
    t:expect1("return 'x' .. 1", "x1")
    t:expect1("return - -1", 1)
    t:expect1("return not not 0", true)
end
