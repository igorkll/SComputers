-- Run with:
--   lua run_all_tests.lua
-- or, preferably, with LuaJIT:
--   luajit run_all_tests.lua
--
-- Target semantics: Lua 5.1 / LuaJIT. Some host-library details
-- (for example # on tables with holes) follow the Lua host.

local H = dofile("tests/helpers.lua")
local custom_loadstring = dofile("custom_loadstring_full.lua")

local modules = {
    "test_lexer",
    "test_syntax",
    "test_expressions",
    "test_statements",
    "test_functions",
    "test_tables",
    "test_varargs_multiret",
    "test_metatables",
    "test_environment",
    "test_errors",
    "test_host_interop",
    "test_regressions",
    "test_superinstructions",
    "test_fuzz",
    "test_stress",
    "test_limits",
    "test_tailcalls",
}

local grand_total = 0
local grand_failed = 0
local started = os.clock()

for i = 1, #modules do
    local name = modules[i]
    local path = "tests/" .. name .. ".lua"
    local ok, fn = pcall(dofile, path)
    local t = H.new_suite(name, custom_loadstring)

    if not ok then
        t:check(false, "cannot load " .. path .. ": " .. tostring(fn))
    elseif type(fn) ~= "function" then
        t:check(false, path .. " must return a function")
    else
        local ran, err = pcall(fn, t)
        if not ran then
            t:check(false, "module crashed: " .. tostring(err))
        end
    end

    grand_total = grand_total + t.total
    grand_failed = grand_failed + t.failed

    if t.failed == 0 then
        print(string.format("[PASS] %-26s %3d checks", name, t.total))
    else
        print(string.format("[FAIL] %-26s %3d/%3d failed",
            name, t.failed, t.total))
        for j = 1, #t.failures do
            print("  - " .. t.failures[j]:gsub("\n", "\n    "))
        end
        if t.failed > #t.failures then
            print("  - ... and " .. (t.failed - #t.failures) .. " more")
        end
    end
end

local elapsed = os.clock() - started
print(string.rep("-", 72))
print(string.format("TOTAL: %d checks, %d failed, %.3f s",
    grand_total, grand_failed, elapsed))
if grand_failed > 0 then
    os.exit(1)
end
