local function benchmart()
    local a = 0
    local upv = 3

    local function ab(i)
        return i + upv
    end

    for i = 1, 10 do
        local clk = os.clock()
        for i = 1, 10000000 do
            a = a + i + upv
        end
        print("a", os.clock() - clk)

        local clk = os.clock()
        for i = 1, 10000000 do
            a = a + ab(i)
        end
        print("f", os.clock() - clk)
    end

    print(a)
end

print("> luajit benchmart")
benchmart()
if better and better.isAvailable() then
    better.fast()
    print("> luajit benchmart after better.fast")
    benchmart()
end