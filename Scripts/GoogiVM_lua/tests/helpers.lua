-- Shared harness for the full custom_loadstring test suite.
-- Run from the project root: lua run_all_tests.lua
-- Recommended target: LuaJIT 2.1 (Lua 5.1 semantics).

local H = {}

local unpack = unpack or table.unpack

function H.pack(...)
    return { n = select("#", ...), ... }
end

H.P = H.pack

local function same(a, b, seen)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) == "number" then
        if a ~= a and b ~= b then
            return true
        end
        return a == b
    end
    if type(a) ~= "table" then
        if type(a) == "function" then
            return true
        end
        return a == b
    end
    if a == b then
        return true
    end
    seen = seen or {}
    if seen[a] == b then
        return true
    end
    seen[a] = b
    for k, v in pairs(a) do
        if type(k) == "table" or type(k) == "function" then
            return false
        end
        if not same(v, b[k], seen) then
            return false
        end
    end
    for k in pairs(b) do
        if type(k) ~= "table" and type(k) ~= "function" and a[k] == nil then
            return false
        end
    end
    return true
end

H.same = same

function H.std_env()
    return {
        assert = assert,
        error = error,
        ipairs = ipairs,
        pairs = pairs,
        next = next,
        select = select,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        pcall = pcall,
        xpcall = xpcall,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        rawget = rawget,
        rawset = rawset,
        rawequal = rawequal,
        table = table,
        string = string,
        math = math,
        coroutine = coroutine,
        setfenv = setfenv,
        getfenv = getfenv,
    }
end

local function native_chunk(source, env)
    local loader = loadstring or load
    local f, err = loader(source)
    if not f then
        return nil, err
    end
    if env and setfenv then
        setfenv(f, env)
    end
    return f
end

function H.new_suite(name, custom_loadstring)
    local t = {
        name = name,
        custom = custom_loadstring,
        total = 0,
        failed = 0,
        failures = {},
        env = H.std_env(),
        P = H.P,
    }

    local function fail(msg)
        t.failed = t.failed + 1
        if #t.failures < 20 then
            t.failures[#t.failures + 1] = msg
        end
    end

    function t:check(cond, msg)
        self.total = self.total + 1
        if not cond then
            fail(msg or "check failed")
        end
        return cond
    end

    function t:equal(got, want, msg)
        return self:check(got == want,
            (msg or "equal") .. ": got " .. tostring(got) ..
            ", want " .. tostring(want))
    end

    function t:pack_equal(got, want, msg)
        self.total = self.total + 1
        if got.n ~= want.n then
            fail((msg or "pack_equal") .. ": got " .. got.n ..
                 " values, want " .. want.n)
            return false
        end
        for i = 1, want.n do
            if not same(got[i], want[i], {}) then
                fail((msg or "pack_equal") .. ": value #" .. i ..
                     " got " .. tostring(got[i]) ..
                     ", want " .. tostring(want[i]))
                return false
            end
        end
        return true
    end

    function t:compile(source, env)
        local f, err = self.custom(source, env or self.env)
        return f, err
    end

    function t:expect(source, expected, env, ...)
        local f, err = self:compile(source, env)
        self.total = self.total + 1
        if not f then
            fail("compile failed: " .. tostring(err) .. "\n--- source ---\n" ..
                 tostring(source))
            return
        end
        local got = H.pack(pcall(f, ...))
        if not got[1] then
            fail("runtime error: " .. tostring(got[2]) ..
                 "\n--- source ---\n" .. tostring(source))
            return
        end
        local values = { n = got.n - 1 }
        for i = 2, got.n do
            values[i - 1] = got[i]
        end
        self.total = self.total - 1
        self:pack_equal(values, expected,
            "results\n--- source ---\n" .. tostring(source))
    end

    function t:expect1(source, want, env, ...)
        self:expect(source, H.P(want), env, ...)
    end

    function t:compile_error(source, env)
        local f, err = self:compile(source, env)
        self.total = self.total + 1
        if f then
            fail("source compiled but should fail:\n" .. tostring(source))
            return false
        end
        if type(err) ~= "string" or not err:find("syntax error", 1, true) then
            fail("bad compile error for source:\n" .. tostring(source) ..
                 "\nerror: " .. tostring(err))
            return false
        end
        return true
    end

    function t:runtime_error(source, env, ...)
        local f, err = self:compile(source, env)
        self.total = self.total + 1
        if not f then
            fail("compile failed in runtime_error: " .. tostring(err) ..
                 "\n--- source ---\n" .. tostring(source))
            return false
        end
        local got = H.pack(pcall(f, ...))
        if got[1] then
            fail("expected runtime error, got success:\n" .. tostring(source))
            return false
        end
        return true
    end

    function t:syntax_ok(source, env)
        local f, err = self:compile(source, env)
        self.total = self.total + 1
        if not f then
            fail("valid source rejected: " .. tostring(err) ..
                 "\n--- source ---\n" .. tostring(source))
            return false
        end
        return true
    end

    function t:syntax_bad(source, env)
        return self:compile_error(source, env)
    end

    function t:compare(source, env, ...)
        self.total = self.total + 1
        local use_env = env or self.env
        local cf, cerr = self.custom(source, use_env)
        if not cf then
            fail("custom compile failed: " .. tostring(cerr) ..
                 "\n--- source ---\n" .. tostring(source))
            return
        end
        local nf, nerr = native_chunk(source, use_env)
        if not nf then
            fail("native compile failed: " .. tostring(nerr) ..
                 "\n--- source ---\n" .. tostring(source))
            return
        end
        local cp = H.pack(pcall(cf, ...))
        local np = H.pack(pcall(nf, ...))
        if cp[1] ~= np[1] then
            fail("success/error mismatch\n--- source ---\n" .. tostring(source) ..
                 "\nnative: " .. tostring(np[1]) .. " " .. tostring(np[2]) ..
                 "\ncustom: " .. tostring(cp[1]) .. " " .. tostring(cp[2]))
            return
        end
        if not cp[1] then
            return
        end
        if cp.n ~= np.n then
            fail("result count mismatch\n--- source ---\n" .. tostring(source) ..
                 "\nnative: " .. (np.n - 1) .. " values" ..
                 "\ncustom: " .. (cp.n - 1) .. " values")
            return
        end
        for i = 2, np.n do
            if not same(np[i], cp[i], {}) then
                fail("value mismatch #" .. (i - 1) ..
                     "\n--- source ---\n" .. tostring(source) ..
                     "\nnative: " .. tostring(np[i]) ..
                     "\ncustom: " .. tostring(cp[i]))
                return
            end
        end
    end

    return t
end

return H
