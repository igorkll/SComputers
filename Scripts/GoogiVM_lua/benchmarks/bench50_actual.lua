--[[
  50-case head-to-head benchmark: GoogiVM vs FiOne vs native LuaJIT.

  Run this from the repository root so that `custom_loadstring_full.lua`
  resolves next to it:

      luajit benchmarks/bench50_actual.lua [fione_path] [luac_dir] [work_dir]

  Requirements
  ------------
  * LuaJIT (or Lua 5.1) to run this script.
  * A FiOne checkout          -- fione_path, or FIONE_PATH, or ./FiOne/source.lua
  * A Lua 5.1 compiler        -- luac_dir, or LUAC_DIR, or the current directory
    The directory must contain `luac5.1.exe` on Windows or `luac5.1` on POSIX.
    It is entered before each compile because the Windows build ships a
    side-by-side CRT manifest and only resolves it from its own directory.

  Every argument can also be supplied through the environment (`FIONE_PATH`,
  `LUAC_DIR`, `BENCH_DIR`); command-line arguments win.

  Outputs
  -------
  `work_dir` (default `bench50-work`, created if missing) receives the
  intermediate `.lua`/`.luac` pairs. The three result files are written to the
  current directory:

      BENCHMARK_50.md        report with medians, ratios and aggregates
      BENCHMARK_50.csv       per-case medians / best / reps
      BENCHMARK_50_raw.csv   every individual sample (7 per case per engine)

  Point `work_dir` at a scratch directory, not at the repository, if you do not
  want the intermediates to show up as untracked files.

  The timed region is execution only: FiOne bytecode compilation and GoogiVM
  source compilation are outside the timer.
]]

local unpack = unpack or table.unpack

local FS = package.config or "/"
local DIRSEP = FS:sub(1, 1)
local IS_WINDOWS = DIRSEP == "\\"

local function fail(msg)
    io.stderr:write("bench50: " .. msg .. "\n")
    os.exit(1)
end

local function current_dir()
    local handle = io.popen and io.popen(IS_WINDOWS and "cd" or "pwd")
    if not handle then return nil end
    local dir = handle:read("*l")
    handle:close()
    return dir and (dir:gsub("[\r\n]+$", "")) or nil
end

local function absolute(path)
    if path:match("^%a:[/\\]") or path:sub(1, 1) == "/" then return path end
    local base = current_dir()
    if not base then return path end
    return base .. DIRSEP .. path
end

local FIONE_PATH = absolute(os.getenv("FIONE_PATH")
    or (arg and arg[1])
    or ("FiOne" .. DIRSEP .. "source.lua"))
local LUAC_DIR = absolute(os.getenv("LUAC_DIR")
    or (arg and arg[2])
    or ".")
local WORK_DIR = absolute(os.getenv("BENCH_DIR")
    or (arg and arg[3])
    or "bench50-work")

local SAMPLES = 7
local MIN_SAMPLE = 0.02

if not io.open(FIONE_PATH, "rb") then
    fail("cannot open the FiOne source at '" .. FIONE_PATH .. "'.\n" ..
        "  Pass the path to FiOne/source.lua as the first argument or in FIONE_PATH.")
end

local LUAC_BIN = "luac5.1" .. (IS_WINDOWS and ".exe" or "")
do
    local probe = io.open(LUAC_DIR .. DIRSEP .. LUAC_BIN, "rb")
    if not probe then
        fail("cannot find " .. LUAC_BIN .. " in '" .. LUAC_DIR .. "'.\n" ..
            "  Pass the directory that contains the Lua 5.1 compiler as the second argument or in LUAC_DIR.")
    end
    probe:close()
end

WORK_DIR = WORK_DIR:gsub("[/\\]+$", "")

local ours = assert(dofile("custom_loadstring_full.lua"))
local FiOne = assert(dofile(FIONE_PATH))

if IS_WINDOWS then
    os.execute('if not exist "' .. WORK_DIR .. '" mkdir "' .. WORK_DIR .. '" >nul 2>nul')
else
    os.execute('mkdir -p "' .. WORK_DIR .. '"')
end

local cases = {
    { "loop_sum_100k", "local s=0; for i=1,100000 do s=s+i end; return s" },
    { "loop_sum_1m", "local s=0; for i=1,1000000 do s=s+i end; return s" },
    { "loop_add_const_1m", "local s=0; for i=1,1000000 do s=s+2 end; return s" },
    { "loop_sub_1m", "local s=0; for i=1,1000000 do s=s-1 end; return s" },
    { "loop_mul_100k", "local s=1; for i=1,100000 do s=s*1.000001 end; return s" },
    { "loop_mod_100k", "local s=0; for i=1,100000 do s=(s+i)%7 end; return s" },
    { "nested_loop_100x100", "local s=0; for i=1,100 do for j=1,100 do s=s+1 end end; return s" },
    { "while_sum_100k", "local s=0; local i=0; while i<100000 do i=i+1; s=s+i end; return s" },
    { "repeat_sum_100k", "local s=0; local i=0; repeat i=i+1; s=s+i until i>=100000; return s" },
    { "loop_break_100k", "local s=0; for i=1,100000 do if i==50000 then break end; s=s+i end; return s" },
    { "branch_if_1m", "local s=0; for i=1,1000000 do if i%2==0 then s=s+i else s=s-1 end end; return s" },
    { "branch_and_or_100k", "local s=0; for i=1,100000 do if i>10 and i<50 or i>90 then s=s+1 end end; return s" },
    { "branch_mod3_100k", "local s=0; for i=1,100000 do if i%3==0 then s=s+i elseif i%3==1 then s=s-1 else s=s+2 end end; return s" },
    { "branch_nested_100k", "local s=0; for i=1,100000 do if i%2==0 then if i%4==0 then s=s+2 else s=s+1 end else s=s-1 end end; return s" },
    { "calls_simple_1m", "local function f(x) return x+1 end; local s=0; for i=1,1000000 do s=f(s) end; return s" },
    { "calls_twoarg_1m", "local function f(a,b) return a+b end; local s=0; for i=1,1000000 do s=f(s,1) end; return s" },
    { "calls_threearg_500k", "local function f(a,b,c) return a+b+c end; local s=0; for i=1,500000 do s=f(s,1,2) end; return s" },
    { "recursion_fib_20", "local function f(n) if n<2 then return n end return f(n-1)+f(n-2) end; return f(20)" },
    { "recursion_fact_10", "local function f(n) if n<=1 then return 1 end return n*f(n-1) end; return f(10)" },
    { "mutual_recursion_1000", "local even, odd; even=function(n) if n==0 then return true end return odd(n-1) end; odd=function(n) if n==0 then return false end return even(n-1) end; return even(1000)" },
    { "tail_recursion_1000", "local function f(n,a) if n==0 then return a end return f(n-1,a+n) end; return f(1000,0)" },
    { "closures_create_100k", "local t=0; for i=1,100000 do local f=function() return i end; t=t+1 end; return t" },
    { "closure_upvalue_1m", "local n=0; local function f() n=n+1; return n end; local s=0; for i=1,1000000 do s=f() end; return s" },
    { "closure_factory_100k", "local function make(x) return function(y) return x+y end end; local s=0; for i=1,100000 do local f=make(i); s=s+f(1) end; return s" },
    { "closure_loop_capture_100k", "local fs={}; for i=1,100000 do fs[i]=function() return i end end; return fs[100000]()" },
    { "table_write_200k", "local t={}; for i=1,200000 do t[i]=i end; return t[200000]" },
    { "table_read_200k", "local t={}; for i=1,200000 do t[i]=i end; local s=0; for i=1,200000 do s=s+t[i] end; return s" },
    { "table_mixed_100k", "local t={}; local s=0; for i=1,100000 do t[i]=i; s=s+t[i] end; return s" },
    { "table_string_keys_50k", "local t={}; local s=0; for i=1,50000 do t[i%100]=i end; for i=1,100 do s=s+(t[i] or 0) end; return s" },
    { "table_constructor_100k", "local s=0; for i=1,100000 do local t={i,i+1,i+2}; s=s+t[1] end; return s" },
    { "table_nested_50k", "local t={}; for i=1,50000 do t[i]={x=i} end; local s=0; for i=1,50000 do s=s+t[i].x end; return s" },
    { "ipairs_100k", "local t={}; for i=1,100000 do t[i]=i end; local s=0; for i,v in ipairs(t) do s=s+v end; return s" },
    { "pairs_20k", "local t={}; for i=1,20000 do t[i]=i end; local s=0; for k,v in pairs(t) do s=s+v end; return s" },
    { "generic_next_100k", "local t={}; for i=1,100000 do t[i]=i end; local s=0; local k=nil; while true do k=next(t,k); if k==nil then break end; s=s+t[k] end; return s" },
    { "generic_ipairs_50k", "local t={}; for i=1,50000 do t[i]=i end; local s=0; for i,v in ipairs(t) do s=s+v end; return s" },
    { "string_concat_10k", "local s=''; for i=1,10000 do s=s..'x' end; return #s" },
    { "string_sub_50k", "local s='abcdef'; local n=0; for i=1,50000 do n=n+#string.sub(s,2,4) end; return n" },
    { "string_byte_100k", "local s=0; for i=1,100000 do s=s+string.byte('a') end; return s" },
    { "string_format_50k", "local s=0; for i=1,50000 do s=s+#string.format('%d',i) end; return s" },
    { "string_gsub_10k", "local s=0; for i=1,10000 do s=s+#string.gsub('aaa','a','b') end; return s" },
    { "math_sqrt_100k", "local s=0; for i=1,100000 do s=s+math.sqrt(i) end; return s" },
    { "math_sin_100k", "local s=0; for i=1,100000 do s=s+math.sin(i) end; return s" },
    { "math_floor_100k", "local s=0; for i=1,100000 do s=s+math.floor(i/3) end; return s" },
    { "varargs_count_100k", "local function f(...) return select('#',...) end; local s=0; for i=1,100000 do s=s+f(i,i+1) end; return s" },
    { "varargs_sum_100k", "local function f(...) local a,b=...; return a+b end; local s=0; for i=1,100000 do s=s+f(i,i+1) end; return s" },
    { "multiret_100k", "local function f(i) return i,i+1,i+2 end; local s=0; for i=1,100000 do local a,b,c=f(i); s=s+a+b+c end; return s" },
    { "multi_assign_100k", "local a,b=0,0; for i=1,100000 do a,b=b,a; a=a+1; b=b+2 end; return a+b" },
    { "method_call_100k", "local t={n=0}; function t:inc(x) self.n=self.n+x; return self.n end; local s=0; for i=1,100000 do s=t:inc(1) end; return s" },
    { "metatable_add_100k", "local mt={__add=function(a,b) return a.n+b.n end}; local a=setmetatable({n=1},mt); local b=setmetatable({n=2},mt); local s=0; for i=1,100000 do s=s+(a+b) end; return s" },
    { "prime_count_10k", "local n=0; for x=2,10000 do local p=true; for d=2,math.floor(math.sqrt(x)) do if x%d==0 then p=false; break end end; if p then n=n+1 end end; return n" },
}

assert(#cases == 50, "expected 50 cases, got " .. #cases)

local function make_env()
    return {
        assert = assert, error = error, ipairs = ipairs, pairs = pairs,
        next = next, select = select, type = type, tostring = tostring,
        tonumber = tonumber, pcall = pcall, xpcall = xpcall,
        setmetatable = setmetatable, getmetatable = getmetatable,
        rawget = rawget, rawset = rawset, rawequal = rawequal,
        table = table, string = string, math = math,
        coroutine = coroutine,
    }
end

local function write_file(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

local function compile_ours(src)
    local env = make_env()
    local fn, err = ours(src, env, {
        maxInstructions = math.huge,
        maxCallDepth = math.huge,
        maxStack = math.huge,
        sourceName = "bench",
    })
    assert(fn, err)
    return fn
end

local function compile_native(src)
    local env = make_env()
    local fn = assert(loadstring(src, "=bench"))
    if setfenv then setfenv(fn, env) end
    return fn
end

local fi_counter = 0
local function compile_fione(src)
    fi_counter = fi_counter + 1
    local stem = WORK_DIR .. DIRSEP .. "case" .. string.format("%02d", fi_counter)
    local srcpath = stem .. ".lua"
    local bcpath = stem .. ".luac"
    write_file(srcpath, src)
    local cmd
    if IS_WINDOWS then
        cmd = 'cd /d "' .. LUAC_DIR .. '" && ' .. LUAC_BIN .. ' -o "' ..
            bcpath .. '" "' .. srcpath .. '"'
    else
        cmd = 'cd "' .. LUAC_DIR .. '" && ' .. LUAC_BIN .. ' -o "' ..
            bcpath .. '" "' .. srcpath .. '"'
    end
    local status = os.execute(cmd)
    local ok = (status == 0) or (status == true)
    assert(ok, "luac failed: " .. cmd)
    local proto = FiOne.bc_to_state(read_file(bcpath))
    return FiOne.wrap_state(proto, make_env())
end

local function same_value(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) == "number" then
        if a ~= a and b ~= b then return true end
        local d = math.abs(a - b)
        return d <= 1e-9 * math.max(1, math.abs(a), math.abs(b))
    end
    return a == b
end

local function measure(fn)
    -- Prevent a trace compiled for a previous case from biasing this one.
    if jit and jit.flush then jit.flush() end
    for _ = 1, 3 do fn() end

    -- Make each timed sample long enough for os.clock's 1 ms resolution.
    local reps = 1
    while reps <= 4096 do
        local t = os.clock()
        for _ = 1, reps do fn() end
        if os.clock() - t >= MIN_SAMPLE then break end
        reps = reps * 2
    end

    local samples = {}
    local best
    for i = 1, SAMPLES do
        local t = os.clock()
        for _ = 1, reps do fn() end
        local elapsed = (os.clock() - t) / reps
        samples[i] = elapsed
        if not best or elapsed < best then best = elapsed end
    end
    local sorted = {}
    for i = 1, SAMPLES do sorted[i] = samples[i] end
    table.sort(sorted)
    return sorted[(SAMPLES + 1) / 2], best, reps, samples
end

local rows = {}
local failed = 0
for i, case in ipairs(cases) do
    local name, src = case[1], case[2]
    local o, f, n
    local ok, err = pcall(function()
        o = compile_ours(src)
        f = compile_fione(src)
        n = compile_native(src)
    end)
    if not ok then
        failed = failed + 1
        print("COMPILE FAIL", name, err)
        rows[#rows + 1] = { name = name, error = tostring(err) }
    else
        local ov = { pcall(o) }
        local fv = { pcall(f) }
        local nv = { pcall(n) }
        if not ov[1] or not fv[1] or not nv[1] then
            failed = failed + 1
            print("RUN FAIL", name, tostring(ov[2]), tostring(fv[2]), tostring(nv[2]))
            rows[#rows + 1] = { name = name, error = "runtime" }
        elseif not same_value(ov[2], fv[2]) or not same_value(ov[2], nv[2]) then
            failed = failed + 1
            print("RESULT MISMATCH", name, tostring(ov[2]), tostring(fv[2]), tostring(nv[2]))
            rows[#rows + 1] = { name = name, error = "result mismatch" }
        else
            local ot, ob, orep, osamples = measure(o)
            local ft, fb, frep, fsamples = measure(f)
            local nt, nb, nrep, nsamples = measure(n)
            rows[#rows + 1] = {
                name = name,
                ours = ot, ours_best = ob, ours_samples = osamples,
                fi = ft, fi_best = fb, fi_samples = fsamples,
                native = nt, native_best = nb, native_samples = nsamples,
                reps = orep .. "/" .. frep .. "/" .. nrep,
                result = tostring(ov[2]),
            }
            print(string.format("%02d %-28s ours=%.6f fi=%.6f native=%.6f",
                i, name, ot, ft, nt))
        end
    end
end

local function fmt(x)
    if type(x) ~= "number" then return tostring(x) end
    return string.format("%.6f", x)
end

local function ratio(a, b)
    if type(a) ~= "number" or type(b) ~= "number" or b <= 0 then return "n/a" end
    return string.format("%.2fx", b / a)
end

-- Aggregates
local wins, losses, ties = 0, 0, 0
local logsum, counted = 0, 0
local sum_ours, sum_fi = 0, 0
for _, r in ipairs(rows) do
    if not r.error and r.ours and r.fi and r.ours > 0 and r.fi > 0 then
        local q = r.fi / r.ours
        if q > 1.05 then wins = wins + 1
        elseif q < 0.95 then losses = losses + 1
        else ties = ties + 1 end
        logsum = logsum + math.log(q)
        counted = counted + 1
        sum_ours = sum_ours + r.ours
        sum_fi = sum_fi + r.fi
    end
end
local geomean = counted > 0 and math.exp(logsum / counted) or 0

local md = {}
md[#md + 1] = "# 50 head-to-head benchmarks: GoogiVM vs FiOne vs LuaJIT native"
md[#md + 1] = ""
md[#md + 1] = "Date: " .. os.date("%Y-%m-%d")
md[#md + 1] = "Host: " .. _VERSION .. " (" .. (jit and jit.version or "no JIT") .. ")"
md[#md + 1] = "Owner: current `custom_loadstring_full.lua`"
md[#md + 1] = "FiOne: `SovereignSatellite/FiOne` @ `18cf0113dcef568b6b679096e372c7bbf7ac6d27`"
md[#md + 1] = "Bytecode compiler for FiOne: `luac5.1` (Lua 5.1.5)"
md[#md + 1] = ""
md[#md + 1] = "## Methodology"
md[#md + 1] = ""
md[#md + 1] = "- 50 distinct Lua 5.1 workloads; each was run on all three engines."
md[#md + 1] = "- All engines received the same source and the same standard-library environment."
md[#md + 1] = "- Timed region is execution only: FiOne bytecode loading and GoogiVM compilation are outside the timer."
md[#md + 1] = "- 3 warm-up iterations, " .. SAMPLES ..
    " measured iterations; JIT traces are flushed before each engine/case measurement."
md[#md + 1] = "- The table shows the median; `bench50_actual.lua` also writes an untracked `BENCHMARK_50_raw.csv` with every individual sample."
md[#md + 1] = "- Native LuaJIT is a reference baseline, not a pure-Lua competitor."
md[#md + 1] = ""
md[#md + 1] = "## Results"
md[#md + 1] = ""
md[#md + 1] = "| # | Case | GoogiVM (s) | FiOne (s) | LuaJIT native (s) | FiOne / GoogiVM | Native / GoogiVM | Reps O/F/N | Result |"
md[#md + 1] = "|---:|---|---:|---:|---:|---:|---:|---:|---|"
for i, r in ipairs(rows) do
    if r.error then
        md[#md + 1] = string.format("| %d | `%s` | %s | %s | %s | %s | %s | %s | ERROR: %s |",
            i, r.name, "-", "-", "-", "-", "-", "-", r.error)
    else
        md[#md + 1] = string.format("| %d | `%s` | %s | %s | %s | %s | %s | %s | `%s` |",
            i, r.name, fmt(r.ours), fmt(r.fi), fmt(r.native),
            ratio(r.ours, r.fi), ratio(r.ours, r.native), r.reps, r.result)
    end
end
md[#md + 1] = ""
md[#md + 1] = "## Aggregate (median execution times)"
md[#md + 1] = ""
md[#md + 1] = "- Cases: **" .. counted .. "** (failures: " .. failed .. ")."
md[#md + 1] = "- GoogiVM faster than FiOne (>5%): **" .. wins ..
    "**; slower (<-5%): **" .. losses .. "**; within 5%: **" .. ties .. "**."
md[#md + 1] = string.format("- Geometric mean FiOne/GoogiVM speed ratio: **%.2fx**.", geomean)
md[#md + 1] = string.format("- Sum of medians: GoogiVM **%.4f s**, FiOne **%.4f s** (**%.2fx**).",
    sum_ours, sum_fi, sum_fi / sum_ours)
md[#md + 1] = ""
md[#md + 1] = "## Limitations"
md[#md + 1] = ""
md[#md + 1] = "- These are 50 project-local microbenchmarks, not a standardized suite."
md[#md + 1] = "- Execution only: FiOne bytecode compilation and GoogiVM compilation are excluded."
md[#md + 1] = "- FiOne is a Lua 5.1 bytecode interpreter; it needs an external Lua 5.1 compiler."
md[#md + 1] = "- LuaJIT native uses `loadstring` and JIT; it is not a pure-Lua competitor."
md[#md + 1] = "- Single machine, one process, JIT traces flushed per engine/case; results are indicative, not statistically rigorous."

write_file("BENCHMARK_50.md", table.concat(md, "\n") .. "\n")

local csv = { "case,ours_median,ours_best,fiOne_median,fiOne_best,native_median,native_best,reps,result" }
for _, r in ipairs(rows) do
    if not r.error then
        csv[#csv + 1] = string.format("%s,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%s,%s",
            r.name, r.ours, r.ours_best, r.fi, r.fi_best, r.native, r.native_best,
            r.reps, (r.result:gsub(",", ";")))
    end
end
write_file("BENCHMARK_50.csv", table.concat(csv, "\n") .. "\n")

local raw = { "case,engine,sample,seconds" }
for _, r in ipairs(rows) do
    if not r.error then
        for i = 1, SAMPLES do
            raw[#raw + 1] = string.format("%s,googi,%d,%.9f", r.name, i, r.ours_samples[i])
            raw[#raw + 1] = string.format("%s,fione,%d,%.9f", r.name, i, r.fi_samples[i])
            raw[#raw + 1] = string.format("%s,native,%d,%.9f", r.name, i, r.native_samples[i])
        end
    end
end
write_file("BENCHMARK_50_raw.csv", table.concat(raw, "\n") .. "\n")

print(string.format(
    "wrote BENCHMARK_50.md, BENCHMARK_50.csv, BENCHMARK_50_raw.csv; failures=%d geomean=%.2fx",
    failed, geomean))
