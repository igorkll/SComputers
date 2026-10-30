--[[
  GoogiVM (custom_loadstring_full.lua)
  Pure-Lua Lua 5.1 compiler and bytecode interpreter.
  Does not use load, loadstring, FFI, debug, io, or os.

  API:
    local custom_loadstring = dofile("custom_loadstring_full.lua")
    local chunk, err = custom_loadstring(source, env, options)

  Supported:
    - while, repeat/until, numeric for, generic for
    - varargs (...), nested functions, closures/upvalues, tail calls
    - table constructors (nested, named/keyed/list fields)
    - multiple assignment and multiple returns
    - method calls/definitions, local function
    - all Lua 5.1 operators and host metamethod semantics
    - syntax and runtime errors with source-line mapping

  Lua 5.1 does not include bitwise operators; expose a library such as
  `bit` through `env` if needed.
]]

local str_find = string.find
local str_match = string.match
local str_sub = string.sub
local str_byte = string.byte
local str_char = string.char
local str_gsub = string.gsub
local tconcat = table.concat
local tostring = tostring
local tonumber = tonumber
local type = type
local error = error
local pcall = pcall
local select = select
local setmetatable = setmetatable
local getfenv = getfenv
local setfenv = setfenv
local getmetatable = getmetatable
local next = next
local ipairs = ipairs
local ipairs_iter = ipairs and select(1, ipairs({}))
local unpack = unpack or table.unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local closure_info = setmetatable({}, { __mode = "k" })

-- Default execution policy. All limits can be overridden per chunk through
-- the optional third argument to custom_loadstring.
local DEFAULT_LIMITS = {
    maxSourceBytes = 4 * 1024 * 1024,
    maxCodeSlots = 8 * 1024 * 1024,
    maxInstructions = 50 * 1000 * 1000,
    maxCallDepth = 10000,
    maxStack = 1000000,
    maxArgs = 1000,
    maxReturns = 1000,
}

-- Fused ("super") opcodes produced by the post-compile peephole pass.
-- All are >= 52; normal opcodes remain 1..51.
local FOP = {
    MOVLOCAL = 52,
    MOVLOCAL_NOP = 53,
    MOVLOCAL_CELL = 54,
    SETLOCAL_K = 55,
    SETLOCAL_INDEX = 56,
    SETLOCAL_FIELD = 57,

    ADD_RR = 58, ADD_RK = 59,
    SUB_RR = 60, SUB_RK = 61,
    MUL_RR = 62, MUL_RK = 63,
    DIV_RR = 64, DIV_RK = 65,
    MOD_RR = 66, MOD_RK = 67,
    POW_RR = 68, POW_RK = 69,

    EQ_RR = 70, EQ_RK = 71,
    NE_RR = 72, NE_RK = 73,
    LT_RR = 74, LT_RK = 75,
    LE_RR = 76, LE_RK = 77,
    GT_RR = 78, GT_RK = 79,
    GE_RR = 80, GE_RK = 81,

    EQ_K = 82, NE_K = 83, LT_K = 84, LE_K = 85, GT_K = 86, GE_K = 87,
    INDEX_RR = 88, INDEX_RK = 89, FIELD_R = 90,

    SETINDEX_RR = 91, SETINDEX_RK = 92,
    SETFIELD_RV = 93, SETFIELD_RK = 94,

    -- 95-101 were folded into ASSIGN_RR/RK/INDEX (154-156).

    JMPF_LOCAL = 102, JMPNIL_LOCAL = 103,

    -- 104-109 and 120-131 were folded into JMPF_CMP_* (151-153).

    FORLOOP_MOV = 110, FORLOOP_CELL = 111,
    FORLOOP_ADD_RR = 112, FORLOOP_ADD_RK = 113,
    FORLOOP_ADD_INDEX = 114,
    FORLOOP_SETINDEX_RR = 115, FORLOOP_SETINDEX_RK = 116,
    FORLOOP_SUB_RR = 117, FORLOOP_SUB_RK = 118,
    JMPF_MOD_EQ_K = 119,

    TFOR_2 = 132,
    TFOR_1 = 133,
    NEWTABLE_LOCAL = 134,
    SETLIST_R = 135,
    SETLIST_K = 136,
    SETLIST_ADD_RK = 137,
    NEWTABLE_FIELD_R = 138,
    NEWTABLE_FIELD_K = 139,
    NEWTABLE_SETINDEX_R = 140,
    NEWTABLE_LIST3_ADD_RK = 141,
    JMPF_MOD_RR_EQ_K = 142,
    ADD_ASSIGN_BINOP_RR = 143,
    SETLOCAL_BOOL = 144,
    FORLOOP_MOD_RR_EQ_K = 145,
    FORLOOP_NEWTABLE_SETINDEX_R = 146,

    TESTF_CMP_RR = 147, TESTF_CMP_RK = 148,
    TESTT_CMP_RR = 149, TESTT_CMP_RK = 150,
    JMPF_CMP_RR = 151, JMPF_CMP_RK = 152, JMPF_CMP_K = 153,

    -- Compound assignment collapsed to one opcode per shape; the arithmetic
    -- operator travels in the dead slot at C[pc + 4] as the base opcode
    -- number (ADD=13 .. CONCAT=19).
    ASSIGN_RR = 154, ASSIGN_RK = 155, ASSIGN_INDEX = 156,

    -- `a, b = b, a`
    SWAP = 157,

    -- `x = (x + y) % k`, e.g. s = (s + i) % 7
    ASSIGN_MOD_ADD_RK = 158,

    -- `t[x % k] = v`
    SETINDEX_MOD_RK = 159,

    -- `local cell = { v = x }; local f = function() ... end`
    CLOSURE_CELL = 160,

    -- `t[cell.v] = function() ... end` (closure over a boxed loop variable)
    SETINDEX_CLOSURE_CELL = 161,

    -- `for ... do s = s <op> operand end` for ops other than + and -.
    -- The arithmetic kind is stored in the dead slot C[body + 16].
    FORLOOP_ASSIGN_RR = 162, FORLOOP_ASSIGN_RK = 163,
}

local run_closure
local active_trace = nil

-- LuaJIT 2.1 can intermittently miscompile the base comparison path inside
-- the large VM function. Keeping comparisons in a tiny, non-JIT function is
-- cheap compared to making the entire interpreter non-JIT.
local function compare_op(op, a, b)
    if op == 23 then
        return a == b
    elseif op == 24 then
        return a ~= b
    elseif op == 25 then
        return a < b
    elseif op == 26 then
        return a <= b
    elseif op == 27 then
        return a > b
    else
        return a >= b
    end
end
if type(jit) == "table" and jit.off then
    jit.off(compare_op)
end

-- Ordered comparisons on two numbers are the overwhelmingly common case inside
-- hot loops. Doing them inline keeps those loops traceable by LuaJIT instead of
-- bouncing through the jit-disabled compare_op on every iteration. Anything
-- else (strings, metamethods) still goes through compare_op unchanged.
local function cmp_lt(a, b)
    if type(a) == "number" and type(b) == "number" then
        return a < b
    end
    return compare_op(25, a, b)
end

local function cmp_le(a, b)
    if type(a) == "number" and type(b) == "number" then
        return a <= b
    end
    return compare_op(26, a, b)
end

local function cmp_gt(a, b)
    if type(a) == "number" and type(b) == "number" then
        return a > b
    end
    return compare_op(27, a, b)
end

local function cmp_ge(a, b)
    if type(a) == "number" and type(b) == "number" then
        return a >= b
    end
    return compare_op(28, a, b)
end

-- Generic form used by the fused compare+test opcodes, which carry the
-- comparison opcode as a separate operand.
local function cmp_value(op, a, b)
    if op == 23 then
        return a == b
    elseif op == 24 then
        return a ~= b
    elseif op == 25 then
        return cmp_lt(a, b)
    elseif op == 26 then
        return cmp_le(a, b)
    elseif op == 27 then
        return cmp_gt(a, b)
    else
        return cmp_ge(a, b)
    end
end

-- Messages already carrying a sandbox location are prefixed with this byte so
-- nested handlers do not re-prefix them. It is stripped at every boundary the
-- guest or the host can observe.
local LOCATION_MARK = "\1"

local function sandbox_message(err)
    if type(err) ~= "string" then
        return err
    end
    if str_sub(err, 1, 1) == LOCATION_MARK then
        return str_sub(err, 2)
    end
    -- Drop a host location prefix ("file.lua:12: " or "C:\...\vm.lua:12: ")
    -- without inventing a sandbox location.
    local body = str_match(err, "^.-:%d+: ([^\n]*)")
    return body or err
end

local last_native_fn = nil
local native_name_cache = setmetatable({}, { __mode = "k" })

local function native_name_of(fn, env)
    if type(fn) ~= "function" or type(env) ~= "table" then
        return nil
    end
    local name = native_name_cache[fn]
    if name then
        return name
    end
    for k, v in pairs(env) do
        if v == fn then
            if type(k) == "string" then
                name = k
                break
            end
        elseif type(v) == "table" then
            for k2, v2 in pairs(v) do
                if v2 == fn and type(k2) == "string" then
                    name = k2
                    break
                end
            end
            if name then
                break
            end
        end
    end
    if name then
        native_name_cache[fn] = name
    end
    return name
end

local function append_trace(out, trace, head)
    local frames = trace.frames
    local fi = trace.fi
    if frames and fi and fi > 1 then
        local skipped_head = false
        for i = fi - 1, 1, -1 do
            local fr = frames[i]
            if fr then
                local fp = fr.p
                local fl = fr.line
                if not fl then
                    local fpc = fr.pc or 1
                    fl = fp.lines and fp.lines[fpc]
                end
                if fl then
                    local tag = (fp.sourceName or "<string>") .. ":" .. fl
                    if not skipped_head and tag == head then
                        -- The header already points at this frame (for
                        -- example error("m", 2) blaming the caller).
                        skipped_head = true
                    else
                        out = out .. "\n  at " .. tag
                    end
                end
            end
        end
    end
    return out
end

local function format_runtime_error(err, trace, with_trace)
    if type(err) ~= "string" then
        return err
    end
    if str_sub(err, 1, 1) == LOCATION_MARK then
        local out = str_sub(err, 2)
        if with_trace and trace and trace.cur then
            local head = str_match(out, "^([^\n]*):%d+: ")
            out = append_trace(out, trace, head)
        end
        return out
    end
    if not trace or not trace.cur then
        return err
    end
    local p = trace.cur.p
    local pc = trace.pc or 1
    local line = p.lines and p.lines[pc]
    if not line then
        return err
    end

    -- Host errors start with "file.lua:NN: " (possibly a Windows path such as
    -- "C:\mods\vm.lua:1771: ..."). Replace that with the interpreted source
    -- location so host paths never leak into the sandbox.
    local msg = str_match(err, "^.-:%d+: ([^\n]*)") or err

    -- Host argument errors name the dispatcher local `f` (or `?` when the
    -- function was called through pcall); restore the real name if known.
    if last_native_fn and
       (str_find(msg, "to 'f'", 1, true) or str_find(msg, "to '?'", 1, true)) then
        local name = native_name_of(last_native_fn, trace.cur.env)
        if name then
            msg = str_gsub(msg, "to 'f'", "to '" .. name .. "'", 1)
            msg = str_gsub(msg, "to '%?'", "to '" .. name .. "'", 1)
        end
    end

    local out = (p.sourceName or "<string>") .. ":" .. line .. ": " .. msg

    if with_trace ~= false then
        out = append_trace(out, trace, (p.sourceName or "<string>") .. ":" .. line)
    end
    return out
end

local function sandbox_error(err, trace, with_trace)
    local formatted = format_runtime_error(err, trace, with_trace)
    if formatted ~= err then
        return formatted
    end
    return sandbox_message(err)
end

-- Forward declarations: defined after get_closure_env/set_closure_env below.
local sandbox_getfenv, sandbox_setfenv

-- Kept outside run_closure so the dispatch loop stays small enough for the
-- LuaJIT trace compiler.
local function protected_call(is_xpcall, target, handler, tr, outer_trace,
                              S, fpos, top, caller_env, frames, fi)
    local target_info = closure_info[target]
    local te = target_info and tr or outer_trace
    local rs

    -- getfenv/setfenv must never reach the host implementation: the host would
    -- happily return a native function's environment, which is the host _G.
    local guarded, new_e
    if getfenv and target == getfenv then
        guarded = function(a)
            return sandbox_getfenv(a, caller_env, frames, fi)
        end
    elseif setfenv and target == setfenv then
        guarded = function(a, b)
            local r
            r, new_e = sandbox_setfenv(a, b, frames, fi)
            return r
        end
    end
    if guarded then
        -- pcall(target, ...) stores args from fpos+2; xpcall(target, handler, ...)
        -- shifts them by the handler slot.
        local first = is_xpcall and (fpos + 3) or (fpos + 2)
        local nargs = top - first + 1
        if is_xpcall then
            local function finish(err)
                local msg = sandbox_error(err, te, false)
                if handler == nil then
                    return msg
                end
                if closure_info[handler] then
                    return run_closure(handler, {}, msg)
                end
                return handler(msg)
            end
            if nargs < 1 then
                rs = pack(xpcall(guarded, finish))
            elseif nargs == 1 then
                rs = pack(xpcall(guarded, finish, S[first]))
            else
                rs = pack(xpcall(guarded, finish, S[first], S[first + 1]))
            end
        else
            if nargs < 1 then
                rs = pack(pcall(guarded))
            elseif nargs == 1 then
                rs = pack(pcall(guarded, S[first]))
            else
                rs = pack(pcall(guarded, S[first], S[first + 1]))
            end
            if not rs[1] then
                rs[2] = sandbox_error(rs[2], te, false)
            end
        end
        rs.new_e = new_e
        return rs
    end

    if not is_xpcall then
        if target_info then
            rs = pack(pcall(run_closure, target, tr, unpack(S, fpos + 2, top)))
        else
            last_native_fn = target
            rs = pack(pcall(target, unpack(S, fpos + 2, top)))
        end
        if not rs[1] then
            rs[2] = sandbox_error(rs[2], te, false)
        end
        return rs
    end

    local args = { n = 0 }
    local n = 0
    for j = fpos + 3, top do
        n = n + 1
        args[n] = S[j]
    end
    args.n = n

    local function finish(err)
        local msg = sandbox_error(err, te, false)
        if handler == nil then
            return msg
        end
        if closure_info[handler] then
            return run_closure(handler, {}, msg)
        end
        return handler(msg)
    end

    if target_info then
        rs = pack(xpcall(function()
            return run_closure(target, tr, unpack(args, 1, n))
        end, finish))
    else
        last_native_fn = target
        rs = pack(xpcall(function()
            return target(unpack(args, 1, n))
        end, finish))
    end
    return rs
end

local function make_closure(proto, upvals, fenv, set_native_env)
    local info
    local function closure(...)
        if info.fast then
            return run_closure(closure, nil, ...)
        end
        local trace = {}
        local result = pack(pcall(run_closure, closure, trace, ...))
        if result[1] then
            return unpack(result, 2, result.n)
        end
        error(sandbox_error(result[2], trace, true), 0)
    end
    local env = fenv or proto.env
    local native_env = false
    -- Only the root chunk needs a native Lua fenv for host getfenv/setfenv.
    -- Nested closures resolve getfenv/setfenv through closure_info instead.
    if set_native_env and setfenv then
        native_env = pcall(setfenv, closure, env)
    end
    info = {
        p = proto, u = upvals, env = env, fenv = native_env,
        limits = proto.limits, fast = not set_native_env,
    }
    closure_info[closure] = info
    return closure
end

local function get_closure_env(fn)
    local info = closure_info[fn]
    if not info then
        return nil
    end
    if info.fenv and getfenv then
        return getfenv(fn)
    end
    return info.env
end

local function set_closure_env(fn, newenv)
    local info = closure_info[fn]
    if not info then
        return false
    end
    info.env = newenv
    if info.fenv and setfenv then
        info.fenv = pcall(setfenv, fn, newenv)
    end
    return true
end

-- Sandbox-safe getfenv/setfenv. Both the CALLD special case and guest
-- pcall/xpcall route through these, so a native function environment (the
-- host _G) can never be reached from interpreted code.
sandbox_getfenv = function(arg, caller_env, frames, fi)
    if arg == nil then
        arg = 1
    end
    if type(arg) == "number" then
        if arg == 0 then
            return caller_env
        end
        if arg < 0 then
            error("bad argument #1 to 'getfenv' (invalid level)", 0)
        end
        local idx = fi - arg + 1
        if idx < 1 then
            error("bad argument #1 to 'getfenv' (invalid level)", 0)
        end
        return frames[idx].env
    elseif type(arg) == "function" then
        if closure_info[arg] then
            return get_closure_env(arg)
        end
        error("getfenv: native function environments are disabled", 0)
    end
    error("bad argument #1 to 'getfenv' (number or function expected)", 0)
end

sandbox_setfenv = function(target, newenv, frames, fi)
    if type(newenv) ~= "table" then
        error("bad argument #2 to 'setfenv' (table expected)", 0)
    end
    if type(target) == "number" then
        if target <= 0 then
            error("cannot change environment of thread", 0)
        end
        local idx = fi - target + 1
        if idx < 1 then
            error("invalid level", 0)
        end
        local fr = frames[idx]
        set_closure_env(fr.cl, newenv)
        local new_e
        for j = 1, fi do
            if frames[j].cl == fr.cl then
                frames[j].env = newenv
                if j == fi then
                    new_e = newenv
                end
            end
        end
        return fr.cl, new_e
    elseif type(target) == "function" then
        if closure_info[target] then
            set_closure_env(target, newenv)
            local new_e
            for j = 1, fi do
                if frames[j].cl == target then
                    frames[j].env = newenv
                    if j == fi then
                        new_e = newenv
                    end
                end
            end
            return target, new_e
        end
        error("setfenv: native function environments are disabled", 0)
    end
    error("bad argument #1 to 'setfenv' (number or function expected)", 0)
end

run_closure = function(fn, trace, ...)
    trace = trace or {}
    active_trace = trace
    local LOADK, LOADBOOL, LOADNIL = 1, 2, 3
    local GETLOCAL, SETLOCAL, GETCELL, SETCELL, CELL = 4, 5, 6, 7, 8
    local GETUPVAL, SETUPVAL, GETGLOBAL, SETGLOBAL = 9, 10, 11, 12
    local ADD, SUB, MUL, DIV, MOD, POW = 13, 14, 15, 16, 17, 18
    local CONCAT, UNM, NOT, LEN = 19, 20, 21, 22
    local EQ, NE, LT, LE, GT, GE = 23, 24, 25, 26, 27, 28
    local TESTF, TESTT, JMPF, JMP, CALLD = 29, 30, 31, 32, 33
    local RET, VARARG, NEWTABLE, FIELD, INDEX = 34, 35, 36, 37, 38
    local SETFIELD, SETINDEX, SELF, SETLIST, SETLISTMULTI = 39, 40, 41, 42, 43
    local MARK, POP, FORPREP, FORLOOP, CLOSURE = 44, 45, 46, 47, 48
    local PEEK, NOP, JMPNIL = 49, 50, 51

    local F_MOVLOCAL, F_MOVLOCAL_NOP, F_MOVLOCAL_CELL = 52, 53, 54
    local F_SETLOCAL_K, F_SETLOCAL_INDEX, F_SETLOCAL_FIELD = 55, 56, 57
    local F_ADD_RR, F_ADD_RK, F_SUB_RR, F_SUB_RK = 58, 59, 60, 61
    local F_MUL_RR, F_MUL_RK, F_DIV_RR, F_DIV_RK = 62, 63, 64, 65
    local F_MOD_RR, F_MOD_RK, F_POW_RR, F_POW_RK = 66, 67, 68, 69
    local F_EQ_RR, F_EQ_RK, F_NE_RR, F_NE_RK = 70, 71, 72, 73
    local F_LT_RR, F_LT_RK, F_LE_RR, F_LE_RK = 74, 75, 76, 77
    local F_GT_RR, F_GT_RK, F_GE_RR, F_GE_RK = 78, 79, 80, 81
    local F_EQ_K, F_NE_K, F_LT_K, F_LE_K = 82, 83, 84, 85
    local F_GT_K, F_GE_K = 86, 87
    local F_INDEX_RR, F_INDEX_RK, F_FIELD_R = 88, 89, 90
    local F_SETINDEX_RR, F_SETINDEX_RK = 91, 92
    local F_SETFIELD_RV, F_SETFIELD_RK = 93, 94
    local F_JMPF_LOCAL, F_JMPNIL_LOCAL = 102, 103
    local F_FORLOOP_MOV, F_FORLOOP_CELL = 110, 111
    local F_FORLOOP_ADD_RR, F_FORLOOP_ADD_RK = 112, 113
    local F_FORLOOP_ADD_INDEX = 114
    local F_FORLOOP_SETINDEX_RR, F_FORLOOP_SETINDEX_RK = 115, 116
    local F_FORLOOP_SUB_RR, F_FORLOOP_SUB_RK = 117, 118
    local F_JMPF_MOD_EQ_K = 119
    local F_TFOR_2, F_TFOR_1 = 132, 133
    local F_NEWTABLE_LOCAL = 134
    local F_SETLIST_R, F_SETLIST_K, F_SETLIST_ADD_RK = 135, 136, 137
    local F_NEWTABLE_FIELD_R, F_NEWTABLE_FIELD_K = 138, 139
    local F_NEWTABLE_SETINDEX_R = 140
    local F_NEWTABLE_LIST3_ADD_RK = 141
    local F_JMPF_MOD_RR_EQ_K = 142
    local F_ADD_ASSIGN_BINOP_RR = 143
    local F_SETLOCAL_BOOL = 144
    local F_FORLOOP_MOD_RR_EQ_K = 145
    local F_FORLOOP_NEWTABLE_SETINDEX_R = 146
    local F_TESTF_CMP_RR, F_TESTF_CMP_RK = 147, 148
    local F_TESTT_CMP_RR, F_TESTT_CMP_RK = 149, 150
    local F_JMPF_CMP_RR, F_JMPF_CMP_RK, F_JMPF_CMP_K = 151, 152, 153
    local F_ASSIGN_RR, F_ASSIGN_RK, F_ASSIGN_INDEX = 154, 155, 156
    local F_SWAP = 157
    local F_ASSIGN_MOD_ADD_RK = 158
    local F_SETINDEX_MOD_RK = 159
    local F_CLOSURE_CELL = 160
    local F_SETINDEX_CLOSURE_CELL = 161
    local F_FORLOOP_ASSIGN_RR, F_FORLOOP_ASSIGN_RK = 162, 163

    local info = closure_info[fn]
    local p = info.p
    local limits = info.limits or {}
    local maxInstructions = limits.maxInstructions
    local instructionBudget = maxInstructions
    local args = pack(...)
    local nargs = args.n
    if limits.maxArgs and nargs > limits.maxArgs then
        error("too many arguments", 0)
    end

    local S = {}
    local top = 0
    local frames = {}
    local fi = 1
    local free_frames = {}
    local free_frame_count = 0

    local base = 1
    local maxreg = p.maxreg
    local va = nil

    if p.isvararg then
        local nv = nargs - p.numparams
        if nv > 0 then
            va = { n = nv }
            for i = 1, nv do
                va[i] = args[p.numparams + i]
            end
        end
    end

    for i = 1, p.numparams do
        S[i] = args[i]
    end
    for i = p.numparams + 1, maxreg do
        S[i] = nil
    end
    top = maxreg
    if limits.maxStack and top > limits.maxStack then
        error("stack limit exceeded", 0)
    end

    local cenv = info.env
    if info.fenv and getfenv then
        cenv = getfenv(fn)
    end

    local cur = {
        p = p, ups = info.u, base = base, pc = 1,
        ret_sp = 0, wanted = -1, va = va, env = cenv, cl = fn,
        line = nil,
    }
    frames[1] = cur
    trace.p = p
    trace.cur = cur
    trace.frames = frames
    trace.fi = fi
    trace.pc = 1

    local C = p.code
    local K = p.consts
    local U = info.u
    local e = cenv
    local pc = 1
    local has_jit = type(jit) == "table"

    while true do
        if instructionBudget then
            instructionBudget = instructionBudget - 1
            if instructionBudget == 0 then
                error("instruction limit exceeded", 0)
            end
        end

        trace.pc = pc
        local op = C[pc]

        if op >= 52 then
            -- Fast-path ordering for the hottest fused opcodes.

            -- Balanced dispatch tree (generated): ~5 compares instead of ~90.
            if op < 102 then
                if op < 73 then
                    if op < 62 then
                        if op < 56 then
                            if op == 52 then
                                S[base + C[pc + 1] - 1] = S[base + C[pc + 2] - 1]
                                pc = pc + 8
                            elseif op == 53 then
                                S[base + C[pc + 1] - 1] = S[base + C[pc + 2] - 1]
                                pc = pc + 12
                            elseif op == 54 then
                                S[base + C[pc + 1] - 1] =
                                    { v = S[base + C[pc + 2] - 1] }
                                pc = pc + 12
                            elseif op == 55 then
                                S[base + C[pc + 1] - 1] = K[C[pc + 2]]
                                pc = pc + 8
                            else
                                error("bad fused bytecode", 0)
                            end
                        else
                            if op < 58 then
                                if op == 56 then
                                    local dest = base + C[pc + 1] - 1
                                    local t = S[base + C[pc + 2] - 1]
                                    local k = S[base + C[pc + 3] - 1]
                                    S[dest] = t[k]
                                    pc = pc + 16
                                elseif op == 57 then
                                    local dest = base + C[pc + 1] - 1
                                    local t = S[base + C[pc + 2] - 1]
                                    S[dest] = t[K[C[pc + 3]]]
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 58 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] + S[base + C[pc + 2] - 1]
                                    pc = pc + 12
                                elseif op == 59 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] + K[C[pc + 2]]
                                    pc = pc + 12
                                elseif op == 60 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] - S[base + C[pc + 2] - 1]
                                    pc = pc + 12
                                elseif op == 61 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] - K[C[pc + 2]]
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    else
                        if op < 67 then
                            if op < 64 then
                                if op == 62 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] * S[base + C[pc + 2] - 1]
                                    pc = pc + 12
                                elseif op == 63 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] * K[C[pc + 2]]
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 64 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] / S[base + C[pc + 2] - 1]
                                    pc = pc + 12
                                elseif op == 65 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] / K[C[pc + 2]]
                                    pc = pc + 12
                                elseif op == 66 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] % S[base + C[pc + 2] - 1]
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        else
                            if op < 69 then
                                if op == 67 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] % K[C[pc + 2]]
                                    pc = pc + 12
                                elseif op == 68 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] ^ S[base + C[pc + 2] - 1]
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 69 then
                                    top = top + 1
                                    S[top] = S[base + C[pc + 1] - 1] ^ K[C[pc + 2]]
                                    pc = pc + 12
                                elseif op == 70 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] == S[base + C[pc + 2] - 1])
                                    pc = pc + 12
                                elseif op == 71 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] == K[C[pc + 2]])
                                    pc = pc + 12
                                elseif op == 72 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] ~= S[base + C[pc + 2] - 1])
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    end
                else
                    if op < 83 then
                        if op < 77 then
                            if op == 73 then
                                top = top + 1
                                S[top] = (S[base + C[pc + 1] - 1] ~= K[C[pc + 2]])
                                pc = pc + 12
                            elseif op == 74 then
                                top = top + 1
                                S[top] = (S[base + C[pc + 1] - 1] < S[base + C[pc + 2] - 1])
                                pc = pc + 12
                            elseif op == 75 then
                                top = top + 1
                                S[top] = (S[base + C[pc + 1] - 1] < K[C[pc + 2]])
                                pc = pc + 12
                            elseif op == 76 then
                                top = top + 1
                                S[top] = (S[base + C[pc + 1] - 1] <= S[base + C[pc + 2] - 1])
                                pc = pc + 12
                            else
                                error("bad fused bytecode", 0)
                            end
                        else
                            if op < 79 then
                                if op == 77 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] <= K[C[pc + 2]])
                                    pc = pc + 12
                                elseif op == 78 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] > S[base + C[pc + 2] - 1])
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 79 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] > K[C[pc + 2]])
                                    pc = pc + 12
                                elseif op == 80 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] >= S[base + C[pc + 2] - 1])
                                    pc = pc + 12
                                elseif op == 81 then
                                    top = top + 1
                                    S[top] = (S[base + C[pc + 1] - 1] >= K[C[pc + 2]])
                                    pc = pc + 12
                                elseif op == 82 then
                                    S[top] = (S[top] == K[C[pc + 1]])
                                    pc = pc + 8
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    else
                        if op < 88 then
                            if op < 85 then
                                if op == 83 then
                                    S[top] = (S[top] ~= K[C[pc + 1]])
                                    pc = pc + 8
                                elseif op == 84 then
                                    S[top] = (S[top] < K[C[pc + 1]])
                                    pc = pc + 8
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 85 then
                                    S[top] = (S[top] <= K[C[pc + 1]])
                                    pc = pc + 8
                                elseif op == 86 then
                                    S[top] = (S[top] > K[C[pc + 1]])
                                    pc = pc + 8
                                elseif op == 87 then
                                    S[top] = (S[top] >= K[C[pc + 1]])
                                    pc = pc + 8
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        else
                            if op < 91 then
                                if op == 88 then
                                    local t = S[base + C[pc + 1] - 1]
                                    local k = S[base + C[pc + 2] - 1]
                                    top = top + 1
                                    S[top] = t[k]
                                    pc = pc + 12
                                elseif op == 89 then
                                    local t = S[base + C[pc + 1] - 1]
                                    top = top + 1
                                    S[top] = t[K[C[pc + 2]]]
                                    pc = pc + 12
                                elseif op == 90 then
                                    local t = S[base + C[pc + 1] - 1]
                                    top = top + 1
                                    S[top] = t[K[C[pc + 2]]]
                                    pc = pc + 8
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 91 then
                                    local t = S[base + C[pc + 1] - 1]
                                    local k = S[base + C[pc + 2] - 1]
                                    t[k] = S[base + C[pc + 3] - 1]
                                    pc = pc + 24
                                elseif op == 92 then
                                    local t = S[base + C[pc + 1] - 1]
                                    local k = S[base + C[pc + 2] - 1]
                                    t[k] = K[C[pc + 3]]
                                    pc = pc + 24
                                elseif op == 93 then
                                    local t = S[base + C[pc + 1] - 1]
                                    t[K[C[pc + 2]]] = S[base + C[pc + 3] - 1]
                                    pc = pc + 16
                                elseif op == 94 then
                                    local t = S[base + C[pc + 1] - 1]
                                    t[K[C[pc + 2]]] = K[C[pc + 3]]
                                    pc = pc + 16
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    end
                end
            else
                if op < 141 then
                    if op < 118 then
                        if op < 112 then
                            if op == 102 then
                                if not S[base + C[pc + 1] - 1] then
                                    pc = C[pc + 2]
                                else
                                    pc = pc + 8
                                end
                            elseif op == 103 then
                                if S[base + C[pc + 1] - 1] == nil then
                                    pc = C[pc + 2]
                                else
                                    pc = pc + 8
                                end
                            elseif op == 110 then
                                local r = base + C[pc + 1] - 1
                                local step = S[r + 2]
                                local limit = S[r + 1]
                                local idx = S[r] + step
                                if (step > 0 and idx <= limit) or
                                   (step < 0 and idx >= limit) then
                                    S[r] = idx
                                    S[base + C[pc + 2] - 1] = idx
                                    pc = C[pc + 3]
                                else
                                    pc = pc + 4
                                end
                            elseif op == 111 then
                                local r = base + C[pc + 1] - 1
                                local step = S[r + 2]
                                local limit = S[r + 1]
                                local idx = S[r] + step
                                if (step > 0 and idx <= limit) or
                                   (step < 0 and idx >= limit) then
                                    S[r] = idx
                                    S[base + C[pc + 2] - 1] = { v = idx }
                                    pc = C[pc + 3]
                                else
                                    pc = pc + 4
                                end
                            else
                                error("bad fused bytecode", 0)
                            end
                        else
                            if op < 114 then
                                if op == 112 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        local b = base + C[body + 14] - 1
                                        S[a] = S[a] + S[b]
                                        local nxt = body + 28
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 113 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        S[a] = S[a] + K[C[body + 14]]
                                        local nxt = body + 28
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 114 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        local t = S[base + C[body + 14] - 1]
                                        local k = S[base + C[body + 15] - 1]
                                        S[a] = S[a] + t[k]
                                        local nxt = body + 36
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 115 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local t = S[base + C[body + 13] - 1]
                                        local k = S[base + C[body + 14] - 1]
                                        t[k] = S[base + C[body + 15] - 1]
                                        local nxt = body + 36
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 116 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local t = S[base + C[body + 13] - 1]
                                        local k = S[base + C[body + 14] - 1]
                                        t[k] = K[C[body + 15]]
                                        local nxt = body + 36
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 117 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        local b = base + C[body + 14] - 1
                                        S[a] = S[a] - S[b]
                                        local nxt = body + 28
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    else
                        if op < 135 then
                            if op < 132 then
                                if op == 118 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        S[a] = S[a] - K[C[body + 14]]
                                        local nxt = body + 28
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 119 then
                                    local v = S[base + C[pc + 1] - 1] % K[C[pc + 2]]
                                    if v == K[C[pc + 3]] then
                                        pc = pc + 24
                                    else
                                        pc = C[pc + 14]
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 132 then
                                    local r = base + C[pc + 1] - 1
                                    local f = S[r]
                                    if f == ipairs_iter then
                                        local idx = S[r + 2] + 1
                                        local val = S[r + 1][idx]
                                        if val ~= nil then
                                            S[r + 2] = idx
                                            if C[pc + 2] == 0 then
                                                S[r + 3] = idx
                                                S[r + 4] = val
                                            else
                                                S[r + 3] = C[pc + 36] == CELL and { v = idx } or idx
                                                S[r + 4] = C[pc + 28] == CELL and { v = val } or val
                                            end
                                            pc = pc + 56
                                        else
                                            pc = C[pc + 53]
                                        end
                                    elseif f == next then
                                        local k, val = next(S[r + 1], S[r + 2])
                                        if k ~= nil then
                                            S[r + 2] = k
                                            if C[pc + 2] == 0 then
                                                S[r + 3] = k
                                                S[r + 4] = val
                                            else
                                                S[r + 3] = C[pc + 36] == CELL and { v = k } or k
                                                S[r + 4] = C[pc + 28] == CELL and { v = val } or val
                                            end
                                            pc = pc + 56
                                        else
                                            pc = C[pc + 53]
                                        end
                                    elseif not closure_info[f] and f ~= getfenv and f ~= setfenv then
                                        local k, val = f(S[r + 1], S[r + 2])
                                        if k ~= nil then
                                            S[r + 2] = k
                                            if C[pc + 2] == 0 then
                                                S[r + 3] = k
                                                S[r + 4] = val
                                            else
                                                S[r + 3] = C[pc + 36] == CELL and { v = k } or k
                                                S[r + 4] = C[pc + 28] == CELL and { v = val } or val
                                            end
                                            pc = pc + 56
                                        else
                                            pc = C[pc + 53]
                                        end
                                    else
                                        top = top + 1
                                        S[top] = f
                                        pc = pc + 4
                                    end
                                elseif op == 133 then
                                    local r = base + C[pc + 1] - 1
                                    local f = S[r]
                                    if f == ipairs_iter then
                                        local idx = S[r + 2] + 1
                                        local val = S[r + 1][idx]
                                        if val ~= nil then
                                            S[r + 2] = idx
                                            if C[pc + 2] == 0 then
                                                S[r + 3] = idx
                                            else
                                                S[r + 3] = { v = idx }
                                            end
                                            pc = pc + 48
                                        else
                                            pc = C[pc + 45]
                                        end
                                    elseif f == next then
                                        local k = next(S[r + 1], S[r + 2])
                                        if k ~= nil then
                                            S[r + 2] = k
                                            if C[pc + 2] == 0 then
                                                S[r + 3] = k
                                            else
                                                S[r + 3] = { v = k }
                                            end
                                            pc = pc + 48
                                        else
                                            pc = C[pc + 45]
                                        end
                                    elseif not closure_info[f] and f ~= getfenv and f ~= setfenv then
                                        local k = f(S[r + 1], S[r + 2])
                                        if k ~= nil then
                                            S[r + 2] = k
                                            if C[pc + 2] == 0 then
                                                S[r + 3] = k
                                            else
                                                S[r + 3] = { v = k }
                                            end
                                            pc = pc + 48
                                        else
                                            pc = C[pc + 45]
                                        end
                                    else
                                        top = top + 1
                                        S[top] = f
                                        pc = pc + 4
                                    end
                                elseif op == 134 then
                                    S[base + C[pc + 1] - 1] = {}
                                    pc = pc + 8
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        else
                            if op < 137 then
                                if op == 135 then
                                    local t = S[base + C[pc + 1] - 1]
                                    t[C[pc + 2]] = S[base + C[pc + 3] - 1]
                                    pc = pc + 12
                                elseif op == 136 then
                                    local t = S[base + C[pc + 1] - 1]
                                    t[C[pc + 2]] = K[C[pc + 3]]
                                    pc = pc + 12
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 137 then
                                    local t = S[base + C[pc + 1] - 1]
                                    t[C[pc + 2]] = S[base + C[pc + 3] - 1] + K[C[pc + 9]]
                                    pc = pc + 20
                                elseif op == 138 then
                                    local t = { [K[C[pc + 1]]] = S[base + C[pc + 2] - 1] }
                                    if C[pc + 3] > 0 then
                                        S[base + C[pc + 3] - 1] = t
                                        pc = pc + 24
                                    else
                                        top = top + 1
                                        S[top] = t
                                        pc = pc + 20
                                    end
                                elseif op == 139 then
                                    local t = { [K[C[pc + 1]]] = K[C[pc + 2]] }
                                    if C[pc + 3] > 0 then
                                        S[base + C[pc + 3] - 1] = t
                                        pc = pc + 24
                                    else
                                        top = top + 1
                                        S[top] = t
                                        pc = pc + 20
                                    end
                                elseif op == 140 then
                                    local t = S[base + C[pc + 1] - 1]
                                    local k = S[base + C[pc + 2] - 1]
                                    t[k] = { [K[C[pc + 25]]] = S[base + C[pc + 3] - 1] }
                                    pc = pc + 40
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    end
                else
                    if op < 152 then
                        if op < 146 then
                            if op < 143 then
                                if op == 141 then
                                    local v = S[base + C[pc + 2] - 1]
                                    local t = {
                                        v,
                                        v + K[C[pc + 29]],
                                        v + K[C[pc + 49]],
                                    }
                                    local c = C[pc + 3]
                                    if c > 0 then
                                        local sreg = base + c - 1
                                        S[sreg] = S[sreg] + t[K[C[pc + 77]]]
                                        pc = pc + 96
                                    else
                                        S[base + C[pc + 1] - 1] = t
                                        pc = pc + 72
                                    end
                                elseif op == 142 then
                                    local v = S[base + C[pc + 1] - 1] % S[base + C[pc + 2] - 1]
                                    if v == K[C[pc + 3]] then
                                        pc = pc + 24
                                    else
                                        pc = C[pc + 14]
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 143 then
                                    local dest = base + C[pc + 1] - 1
                                    local a = S[base + C[pc + 2] - 1]
                                    local b = S[base + C[pc + 3] - 1]
                                    local bop = C[pc + 12]
                                    if bop == ADD then
                                        if type(a) == "number" and type(b) == "number" then
                                            S[dest] = S[dest] + (a + b)
                                            pc = pc + 24
                                        elseif getmetatable then
                                            local mt = (type(a) == "table" and getmetatable(a)) or
                                                       (type(b) == "table" and getmetatable(b))
                                            local mm = type(mt) == "table" and mt.__add
                                            local mci = mm and closure_info[mm]
                                            if mci and not mci.p.isvararg then
                                                local cp = mci.p
                                                if limits.maxCallDepth and fi >= limits.maxCallDepth then
                                                    error("call depth limit exceeded", 0)
                                                end
                                                top = top + 1
                                                S[top] = S[dest]
                                                local fpos = top + 1
                                                S[fpos] = a
                                                S[fpos + 1] = b
                                                local cmax = cp.maxreg
                                                for j = 3, cmax do
                                                    S[fpos + j - 1] = nil
                                                end
                                                cur.pc = pc + 16
                                                cur.line = p.lines and p.lines[pc]
                                                frames[fi] = cur
                                                local nfree = free_frame_count
                                                local frame
                                                if nfree > 0 then
                                                    frame = free_frames[nfree]
                                                    free_frames[nfree] = nil
                                                    free_frame_count = nfree - 1
                                                else
                                                    frame = {}
                                                end
                                                frame.p = cp
                                                frame.ups = mci.u
                                                frame.base = fpos
                                                frame.pc = 1
                                                frame.ret_sp = top
                                                frame.wanted = 1
                                                frame.va = nil
                                                frame.env = mci.env
                                                frame.cl = mm
                                                frame.line = nil
                                                cur = frame
                                                fi = fi + 1
                                                frames[fi] = cur
                                                trace.cur = cur
                                                trace.fi = fi
                                                p = cp
                                                C = cp.code
                                                K = cp.consts
                                                U = mci.u
                                                e = mci.env
                                                base = fpos
                                                maxreg = cmax
                                                va = nil
                                                pc = 1
                                                top = fpos + cmax - 1
                                            else
                                                S[dest] = S[dest] + (a + b)
                                                pc = pc + 24
                                            end
                                        else
                                            S[dest] = S[dest] + (a + b)
                                            pc = pc + 24
                                        end
                                    elseif bop == SUB then
                                        S[dest] = S[dest] + (a - b)
                                        pc = pc + 24
                                    else
                                        S[dest] = S[dest] + (a * b)
                                        pc = pc + 24
                                    end
                                elseif op == 144 then
                                    S[base + C[pc + 1] - 1] = (C[pc + 2] == 1)
                                    pc = pc + 8
                                elseif op == 145 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local v = S[base + C[body + 13] - 1] % S[base + C[body + 14] - 1]
                                        if v == K[C[body + 15]] then
                                            pc = body + 36
                                        else
                                            local nxt = C[body + 26]
                                            if nxt ~= pc then pc = nxt end
                                        end
                                    else
                                        pc = pc + 4
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        else
                            if op < 148 then
                                if op == 146 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local t = S[base + C[body + 13] - 1]
                                        local k = S[base + C[body + 14] - 1]
                                        t[k] = { [K[C[body + 37]]] = S[base + C[body + 15] - 1] }
                                        local nxt = body + 52
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 147 then
                                    local cop = C[pc + 4]
                                    local a = S[base + C[pc + 1] - 1]
                                    local b = S[base + C[pc + 2] - 1]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if v then
                                        pc = pc + 16
                                    else
                                        top = top + 1
                                        S[top] = v
                                        pc = C[pc + 3]
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 148 then
                                    local cop = C[pc + 4]
                                    local a = S[base + C[pc + 1] - 1]
                                    local b = K[C[pc + 2]]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if v then
                                        pc = pc + 16
                                    else
                                        top = top + 1
                                        S[top] = v
                                        pc = C[pc + 3]
                                    end
                                elseif op == 149 then
                                    local cop = C[pc + 4]
                                    local a = S[base + C[pc + 1] - 1]
                                    local b = S[base + C[pc + 2] - 1]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if v then
                                        top = top + 1
                                        S[top] = v
                                        pc = C[pc + 3]
                                    else
                                        pc = pc + 16
                                    end
                                elseif op == 150 then
                                    local cop = C[pc + 4]
                                    local a = S[base + C[pc + 1] - 1]
                                    local b = K[C[pc + 2]]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if v then
                                        top = top + 1
                                        S[top] = v
                                        pc = C[pc + 3]
                                    else
                                        pc = pc + 16
                                    end
                                elseif op == 151 then
                                    local cop = C[pc + 4]
                                    local a = S[base + C[pc + 1] - 1]
                                    local b = S[base + C[pc + 2] - 1]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if not v then
                                        pc = C[pc + 3]
                                    else
                                        pc = pc + 16
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    else
                        if op < 157 then
                            if op < 154 then
                                if op == 152 then
                                    local cop = C[pc + 4]
                                    local a = S[base + C[pc + 1] - 1]
                                    local b = K[C[pc + 2]]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if not v then
                                        pc = C[pc + 3]
                                    else
                                        pc = pc + 16
                                    end
                                elseif op == 153 then
                                    local cop = C[pc + 4]
                                    local a = S[top]
                                    S[top] = nil
                                    top = top - 1
                                    local b = K[C[pc + 1]]
                                    local v
                                    if cop == 25 then v = cmp_lt(a, b)
                                    elseif cop == 26 then v = cmp_le(a, b)
                                    elseif cop == 27 then v = cmp_gt(a, b)
                                    elseif cop == 28 then v = cmp_ge(a, b)
                                    elseif cop == 23 then v = a == b
                                    else v = a ~= b end
                                    if not v then
                                        pc = C[pc + 2]
                                    else
                                        pc = pc + 12
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 154 then
                                    local a = base + C[pc + 1] - 1
                                    local b = S[base + C[pc + 2] - 1]
                                    local v = S[a]
                                    local k = C[pc + 4]
                                    if k == 13 then v = v + b
                                    elseif k == 14 then v = v - b
                                    elseif k == 15 then v = v * b
                                    elseif k == 16 then v = v / b
                                    elseif k == 17 then v = v % b
                                    elseif k == 18 then v = v ^ b
                                    else v = v .. b end
                                    S[a] = v
                                    pc = pc + 16
                                elseif op == 155 then
                                    local a = base + C[pc + 1] - 1
                                    local b = K[C[pc + 2]]
                                    local v = S[a]
                                    local k = C[pc + 4]
                                    if k == 13 then v = v + b
                                    elseif k == 14 then v = v - b
                                    elseif k == 15 then v = v * b
                                    elseif k == 16 then v = v / b
                                    elseif k == 17 then v = v % b
                                    elseif k == 18 then v = v ^ b
                                    else v = v .. b end
                                    S[a] = v
                                    pc = pc + 16
                                elseif op == 156 then
                                    local a = base + C[pc + 1] - 1
                                    local b = S[base + C[pc + 2] - 1][S[base + C[pc + 3] - 1]]
                                    local v = S[a]
                                    local k = C[pc + 4]
                                    if k == 13 then v = v + b
                                    elseif k == 14 then v = v - b
                                    elseif k == 15 then v = v * b
                                    elseif k == 16 then v = v / b
                                    elseif k == 17 then v = v % b
                                    elseif k == 18 then v = v ^ b
                                    else v = v .. b end
                                    S[a] = v
                                    pc = pc + 24
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        else
                            if op < 160 then
                                if op == 157 then
                                    local a = base + C[pc + 1] - 1
                                    local b = base + C[pc + 2] - 1
                                    local t = S[a]
                                    S[a] = S[b]
                                    S[b] = t
                                    pc = pc + 16
                                elseif op == 158 then
                                    local a = base + C[pc + 1] - 1
                                    local b = base + C[pc + 2] - 1
                                    S[a] = (S[a] + S[b]) % K[C[pc + 3]]
                                    pc = pc + 24
                                elseif op == 159 then
                                    local t = S[base + C[pc + 1] - 1]
                                    local k = S[base + C[pc + 2] - 1] % K[C[pc + 3]]
                                    t[k] = S[base + C[pc + 4] - 1]
                                    pc = pc + 32
                                else
                                    error("bad fused bytecode", 0)
                                end
                            else
                                if op == 160 then
                                    local cellreg = base + C[pc + 1] - 1
                                    S[cellreg] = { v = S[base + C[pc + 2] - 1] }
                                    local cp = p.protos[C[pc + 4]]
                                    local ud = cp.updesc
                                    local ups = {}
                                    for j = 1, #ud do
                                        local d = ud[j]
                                        if d.instack == 1 then
                                            ups[j] = S[base + d.idx - 1]
                                        else
                                            ups[j] = U[d.idx]
                                        end
                                    end
                                    S[base + C[pc + 3] - 1] = make_closure(cp, ups, e, false)
                                    pc = pc + 20
                                elseif op == 161 then
                                    local cellreg = base + C[pc + 1] - 1
                                    local cell = { v = S[base + C[pc + 2] - 1] }
                                    S[cellreg] = cell
                                    local cp = p.protos[C[pc + 4]]
                                    local ud = cp.updesc
                                    local ups = {}
                                    for j = 1, #ud do
                                        local d = ud[j]
                                        if d.instack == 1 then
                                            ups[j] = S[base + d.idx - 1]
                                        else
                                            ups[j] = U[d.idx]
                                        end
                                    end
                                    local t = S[base + C[pc + 3] - 1]
                                    t[cell.v] = make_closure(cp, ups, e, false)
                                    pc = pc + 36
                                elseif op == 162 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        local b = base + C[body + 14] - 1
                                        local kind = C[body + 16]
                                        if kind == 15 then
                                            S[a] = S[a] * S[b]
                                        elseif kind == 16 then
                                            S[a] = S[a] / S[b]
                                        elseif kind == 17 then
                                            S[a] = S[a] % S[b]
                                        elseif kind == 18 then
                                            S[a] = S[a] ^ S[b]
                                        else
                                            S[a] = S[a] .. S[b]
                                        end
                                        local nxt = body + 28
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                elseif op == 163 then
                                    local r = base + C[pc + 1] - 1
                                    local step = S[r + 2]
                                    local limit = S[r + 1]
                                    local idx = S[r] + step
                                    if (step > 0 and idx <= limit) or
                                       (step < 0 and idx >= limit) then
                                        S[r] = idx
                                        S[base + C[pc + 2] - 1] = idx
                                        local body = C[pc + 3]
                                        trace.pc = body + 12
                                        local a = base + C[body + 13] - 1
                                        local kind = C[body + 16]
                                        if kind == 15 then
                                            S[a] = S[a] * K[C[body + 14]]
                                        elseif kind == 16 then
                                            S[a] = S[a] / K[C[body + 14]]
                                        elseif kind == 17 then
                                            S[a] = S[a] % K[C[body + 14]]
                                        elseif kind == 18 then
                                            S[a] = S[a] ^ K[C[body + 14]]
                                        else
                                            S[a] = S[a] .. K[C[body + 14]]
                                        end
                                        local nxt = body + 28
                                        if nxt ~= pc then pc = nxt end
                                    else
                                        pc = pc + 4
                                    end
                                else
                                    error("bad fused bytecode", 0)
                                end
                            end
                        end
                    end
                end
            end

        else
            if op < 26 then
                if op < 13 then
                    if op < 6 then
                        if op < 3 then
                            if op == 1 then
                            local k = K[C[pc + 1]]
                            top = top + 1
                            S[top] = k
                            pc = pc + 4
                            elseif op == 2 then
                            top = top + 1
                            S[top] = (C[pc + 1] == 1)
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 3 then
                            local n = C[pc + 1]
                            for i = 1, n do
                                top = top + 1
                                S[top] = nil
                            end
                            pc = pc + 4
                            elseif op == 4 then
                            top = top + 1
                            S[top] = S[base + C[pc + 1] - 1]
                            pc = pc + 4
                            elseif op == 5 then
                            S[base + C[pc + 1] - 1] = S[top]
                            S[top] = nil
                            top = top - 1
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    else
                        if op < 9 then
                            if op == 6 then
                            local cell = S[base + C[pc + 1] - 1]
                            top = top + 1
                            S[top] = cell.v
                            pc = pc + 4
                            elseif op == 7 then
                            local cell = S[base + C[pc + 1] - 1]
                            cell.v = S[top]
                            S[top] = nil
                            top = top - 1
                            pc = pc + 4
                            elseif op == 8 then
                            local i = base + C[pc + 1] - 1
                            S[i] = { v = S[i] }
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 9 then
                            top = top + 1
                            S[top] = U[C[pc + 1]].v
                            pc = pc + 4
                            elseif op == 10 then
                            U[C[pc + 1]].v = S[top]
                            S[top] = nil
                            top = top - 1
                            pc = pc + 4
                            elseif op == 11 then
                            top = top + 1
                            S[top] = e[K[C[pc + 1]]]
                            pc = pc + 4
                            elseif op == 12 then
                            e[K[C[pc + 1]]] = S[top]
                            S[top] = nil
                            top = top - 1
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    end
                else
                    if op < 19 then
                        if op < 15 then
                            if op == 13 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a + b
                            pc = pc + 4
                            elseif op == 14 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a - b
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 15 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a * b
                            pc = pc + 4
                            elseif op == 16 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a / b
                            pc = pc + 4
                            elseif op == 17 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a % b
                            pc = pc + 4
                            elseif op == 18 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a ^ b
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    else
                        if op < 22 then
                            if op == 19 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = a .. b
                            pc = pc + 4
                            elseif op == 20 then
                            S[top] = -S[top]
                            pc = pc + 4
                            elseif op == 21 then
                            S[top] = not S[top]
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 22 then
                            S[top] = #S[top]
                            pc = pc + 4
                            elseif op == 23 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = compare_op(op, a, b)
                            pc = pc + 4
                            elseif op == 24 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = compare_op(op, a, b)
                            pc = pc + 4
                            elseif op == 25 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = compare_op(op, a, b)
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    end
                end
            else
                if op < 38 then
                    if op < 31 then
                        if op < 28 then
                            if op == 26 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = compare_op(op, a, b)
                            pc = pc + 4
                            elseif op == 27 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = compare_op(op, a, b)
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 28 then
                            local b = S[top]
                            local a = S[top - 1]
                            S[top] = nil
                            top = top - 1
                            S[top] = compare_op(op, a, b)
                            pc = pc + 4
                            elseif op == 29 then
                            if not S[top] then
                                pc = C[pc + 1]
                            else
                                S[top] = nil
                                top = top - 1
                                pc = pc + 4
                            end
                            elseif op == 30 then
                            if S[top] then
                                pc = C[pc + 1]
                            else
                                S[top] = nil
                                top = top - 1
                                pc = pc + 4
                            end
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    else
                        if op < 34 then
                            if op == 31 then
                            local v = S[top]
                            S[top] = nil
                            top = top - 1
                            if not v then
                                pc = C[pc + 1]
                            else
                                pc = pc + 4
                            end
                            elseif op == 32 then
                            pc = C[pc + 1]
                            elseif op == 33 then
                            local mreg = C[pc + 1]
                            local nres = C[pc + 2]
                            local tail = C[pc + 3] == 1
                            local fpos = S[base + mreg - 1]
                            local f = S[fpos]
                            local nargs = top - fpos
                            local ret_sp = fpos - 1
                            local fci = closure_info[f]

                            if limits.maxArgs and nargs > limits.maxArgs then
                                error("too many arguments", 0)
                            end
                            if limits.maxStack and top > limits.maxStack then
                                error("stack limit exceeded", 0)
                            end

                            if fci then
                                if not tail and limits.maxCallDepth and
                                   fi >= limits.maxCallDepth then
                                    error("call depth limit exceeded", 0)
                                end
                                local cp = fci.p
                                local cpups = fci.u
                                local cva = nil
                                if cp.isvararg then
                                    local nv = nargs - cp.numparams
                                    if nv > 0 then
                                        cva = { n = nv }
                                        for j = 1, nv do
                                            cva[j] = S[fpos + cp.numparams + j]
                                        end
                                    end
                                end

                                -- A tail call reuses the frame, so it must also reuse the
                                -- frame's original stack region. Moving the function and its
                                -- arguments down to `base` keeps `top` bounded; otherwise the
                                -- base creeps upward on every iteration and deep tail
                                -- recursion eventually trips maxStack.
                                if tail and fpos ~= base then
                                    S[base] = f
                                    for j = 1, nargs do
                                        S[base + j] = S[fpos + j]
                                    end
                                    fpos = base
                                end

                                local np = cp.numparams
                                for j = 1, np do
                                    if j <= nargs then
                                        S[fpos + j - 1] = S[fpos + j]
                                    else
                                        S[fpos + j - 1] = nil
                                    end
                                end
                                local cmax = cp.maxreg
                                for j = np + 1, cmax do
                                    S[fpos + j - 1] = nil
                                end

                                local cenv = fci.env
                                if fci.fenv and getfenv then
                                    cenv = getfenv(f)
                                end

                                local call_ret_sp = tail and cur.ret_sp or ret_sp
                                local call_wanted = tail and cur.wanted or nres
                                if tail then
                                    -- Reuse the current frame table for a tail call.
                                    cur.p = cp
                                    cur.ups = cpups
                                    cur.base = fpos
                                    cur.pc = 1
                                    cur.ret_sp = call_ret_sp
                                    cur.wanted = call_wanted
                                    cur.va = cva
                                    cur.env = cenv
                                    cur.cl = f
                                    cur.line = nil
                                    frames[fi] = cur
                                else
                                    cur.pc = pc + 4
                                    cur.line = p.lines and p.lines[pc]
                                    frames[fi] = cur
                                    local nfree = free_frame_count
                                    local frame
                                    if nfree > 0 then
                                        frame = free_frames[nfree]
                                        free_frames[nfree] = nil
                                        free_frame_count = nfree - 1
                                    else
                                        frame = {}
                                    end
                                    frame.p = cp
                                    frame.ups = cpups
                                    frame.base = fpos
                                    frame.pc = 1
                                    frame.ret_sp = call_ret_sp
                                    frame.wanted = call_wanted
                                    frame.va = cva
                                    frame.env = cenv
                                    frame.cl = f
                                    frame.line = nil
                                    cur = frame
                                    fi = fi + 1
                                    frames[fi] = cur
                                end
                                trace.cur = cur
                                trace.fi = fi

                                p = cp
                                C = cp.code
                                K = cp.consts
                                U = cpups
                                e = cenv
                                base = fpos
                                maxreg = cmax
                                va = cva
                                pc = 1
                                top = fpos + cmax - 1
                            else
                                if getfenv and f == getfenv then
                                    local arg = (nargs == 0) and 1 or S[fpos + 1]
                                    local r = sandbox_getfenv(arg, e, frames, fi)
                                    top = ret_sp
                                    if nres ~= 0 then
                                        top = top + 1
                                        S[top] = r
                                        for j = 2, nres do
                                            top = top + 1
                                            S[top] = nil
                                        end
                                    end
                                elseif setfenv and f == setfenv then
                                    if nargs < 2 then
                                        error("bad argument count to 'setfenv'", 0)
                                    end
                                    local r, new_e = sandbox_setfenv(S[fpos + 1], S[fpos + 2], frames, fi)
                                    if new_e then
                                        e = new_e
                                    end
                                    top = ret_sp
                                    if nres ~= 0 then
                                        top = top + 1
                                        S[top] = r
                                        for j = 2, nres do
                                            top = top + 1
                                            S[top] = nil
                                        end
                                    end
                                elseif f == error then
                                    -- Reimplement `error(msg, level)` against interpreted
                                    -- frames so `level` selects the right sandbox location.
                                    local msg = S[fpos + 1]
                                    local level = S[fpos + 2]
                                    if type(msg) ~= "string" then
                                        error(msg, 0)
                                    end
                                    if type(level) ~= "number" then
                                        level = 1
                                    end
                                    if level == 0 then
                                        error(LOCATION_MARK .. msg, 0)
                                    end
                                    local idx = fi - level + 1
                                    local fr = (idx >= 1) and frames[idx] or nil
                                    local fl = fr and (idx == fi and p.lines and p.lines[pc] or fr.line)
                                    if fl then
                                        error(LOCATION_MARK ..
                                            (fr.p.sourceName or "<string>") .. ":" .. fl ..
                                            ": " .. msg, 0)
                                    end
                                    error(LOCATION_MARK .. msg, 0)
                                elseif (f == pcall or (xpcall and f == xpcall)) and
                                       nargs >= 1 then
                                    -- Guest pcall/xpcall must not leak host paths, whether the
                                    -- target is interpreted or a native function that calls
                                    -- back into interpreted callbacks (sort/gsub comparators).
                                    local target = S[fpos + 1]
                                    local tr = {}
                                    local rs = protected_call(f == xpcall, target,
                                        S[fpos + 2], tr, active_trace, S, fpos, top, e, frames, fi)
                                    if rs.new_e then
                                        e = rs.new_e
                                    end
                                    top = ret_sp
                                    if nres == 0 then
                                        -- discard all results
                                    elseif nres == 1 then
                                        top = ret_sp + 1
                                        S[top] = rs[1]
                                    elseif nres < 0 then
                                        for j = 1, rs.n do
                                            S[ret_sp + j] = rs[j]
                                        end
                                        top = ret_sp + rs.n
                                    else
                                        for j = 1, nres do
                                            S[ret_sp + j] = rs[j]
                                        end
                                        top = ret_sp + nres
                                    end
                                else
                                    last_native_fn = f
                                    if nres == 0 then
                                        if nargs == 0 then
                                            f()
                                        elseif nargs == 1 then
                                            f(S[fpos + 1])
                                        elseif nargs == 2 then
                                            f(S[fpos + 1], S[fpos + 2])
                                        else
                                            f(unpack(S, fpos + 1, top))
                                        end
                                        top = ret_sp
                                    elseif nres == 1 then
                                        local r
                                        if nargs == 0 then
                                            r = f()
                                        elseif nargs == 1 then
                                            r = f(S[fpos + 1])
                                        elseif nargs == 2 then
                                            r = f(S[fpos + 1], S[fpos + 2])
                                        else
                                            r = f(unpack(S, fpos + 1, top))
                                        end
                                        top = ret_sp + 1
                                        S[top] = r
                                    else
                                        local rs
                                        if nargs == 0 then
                                            rs = pack(f())
                                        elseif nargs == 1 then
                                            rs = pack(f(S[fpos + 1]))
                                        elseif nargs == 2 then
                                            rs = pack(f(S[fpos + 1], S[fpos + 2]))
                                        else
                                            rs = pack(f(unpack(S, fpos + 1, top)))
                                        end
                                        if limits.maxReturns and rs.n > limits.maxReturns then
                                            error("too many return values", 0)
                                        end
                                        top = ret_sp
                                        if nres < 0 then
                                            for j = 1, rs.n do
                                                S[ret_sp + j] = rs[j]
                                            end
                                            top = ret_sp + rs.n
                                        else
                                            for j = 1, nres do
                                                S[ret_sp + j] = rs[j]
                                            end
                                            top = ret_sp + nres
                                        end
                                    end
                                end
                                if tail then
                                    local exprbase = base + maxreg
                                    local n = top - ret_sp
                                    for j = 1, n do
                                        S[exprbase + j - 1] = S[ret_sp + j]
                                    end
                                    top = exprbase + n - 1
                                end
                                pc = pc + 4
                            end
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 34 then
                            local n = C[pc + 1]
                            local exprbase = base + maxreg
                            local nret
                            if n < 0 then
                                nret = top - (exprbase - 1)
                            else
                                nret = n
                            end
                            if limits.maxReturns and nret > limits.maxReturns then
                                error("too many return values", 0)
                            end
                            local src = top - nret + 1
                            local dret = cur.ret_sp
                            for j = 1, nret do
                                S[dret + j] = S[src + j - 1]
                            end
                            local wanted = cur.wanted
                            local keep = nret
                            if wanted == 0 then
                                keep = 0
                            elseif wanted ~= -1 then
                                keep = wanted
                                for j = nret + 1, keep do
                                    S[dret + j] = nil
                                end
                            end
                            top = dret + keep

                            local finished = cur
                            frames[fi] = nil
                            fi = fi - 1
                            if fi == 0 then
                                active_trace = nil
                                if top == 0 then
                                    return
                                end
                                return unpack(S, 1, top)
                            end
                            if free_frame_count < 64 then
                                free_frame_count = free_frame_count + 1
                                free_frames[free_frame_count] = finished
                            end

                            cur = frames[fi]
                            trace.cur = cur
                            trace.fi = fi
                            p = cur.p
                            C = p.code
                            K = p.consts
                            U = cur.ups
                            e = cur.env
                            base = cur.base
                            maxreg = p.maxreg
                            va = cur.va
                            pc = cur.pc
                            elseif op == 35 then
                            local nres = C[pc + 1]
                            local n = va and va.n or 0
                            local varargCount = nres < 0 and n or nres
                            if limits.maxReturns and varargCount > limits.maxReturns then
                                error("too many return values", 0)
                            end
                            if limits.maxStack and top + varargCount > limits.maxStack then
                                error("stack limit exceeded", 0)
                            end
                            if nres < 0 then
                                for j = 1, n do
                                    top = top + 1
                                    S[top] = va[j]
                                end
                            else
                                for j = 1, nres do
                                    top = top + 1
                                    if j <= n then
                                        S[top] = va[j]
                                    else
                                        S[top] = nil
                                    end
                                end
                            end
                            pc = pc + 4
                            elseif op == 36 then
                            top = top + 1
                            S[top] = {}
                            pc = pc + 4
                            elseif op == 37 then
                            local t = S[top]
                            S[top] = t[K[C[pc + 1]]]
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    end
                else
                    if op < 44 then
                        if op < 40 then
                            if op == 38 then
                            local key = S[top]
                            S[top] = nil
                            top = top - 1
                            local t = S[top]
                            S[top] = t[key]
                            pc = pc + 4
                            elseif op == 39 then
                            local val = S[top]
                            S[top] = nil
                            top = top - 1
                            local t = S[base + C[pc + 1] - 1]
                            t[K[C[pc + 2]]] = val
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op == 40 then
                            local val = S[top]
                            S[top] = nil
                            top = top - 1
                            local t = S[base + C[pc + 1] - 1]
                            local key = S[base + C[pc + 2] - 1]
                            t[key] = val
                            pc = pc + 4
                            elseif op == 41 then
                            local t = S[top]
                            S[top] = t[K[C[pc + 1]]]
                            top = top + 1
                            S[top] = t
                            pc = pc + 4
                            elseif op == 42 then
                            local val = S[top]
                            S[top] = nil
                            top = top - 1
                            local t = S[base + C[pc + 1] - 1]
                            t[C[pc + 2]] = val
                            pc = pc + 4
                            elseif op == 43 then
                            local t = S[base + C[pc + 1] - 1]
                            local idx = C[pc + 2]
                            local marker = S[base + C[pc + 3] - 1]
                            local n = top - marker
                            for j = 1, n do
                                t[idx + j - 1] = S[marker + j]
                            end
                            for j = marker + 1, top do
                                S[j] = nil
                            end
                            top = marker
                            pc = pc + 4
                            else
                                error("bad bytecode", 0)
                            end
                        end
                    else
                        if op < 47 then
                            if op == 44 then
                            S[base + C[pc + 1] - 1] = top - C[pc + 2]
                            pc = pc + 4
                            elseif op == 45 then
                            local n = C[pc + 1]
                            for j = 1, n do
                                S[top] = nil
                                top = top - 1
                            end
                            pc = pc + 4
                            elseif op == 46 then
                            local r = base + C[pc + 1] - 1
                            local idx = tonumber(S[r])
                            local limit = tonumber(S[r + 1])
                            local step = tonumber(S[r + 2])
                            if not idx or not limit or not step then
                                error("'for' values must be numbers", 0)
                            end
                            S[r] = idx
                            S[r + 1] = limit
                            S[r + 2] = step
                            if step == 0 then
                                error("'for' step is zero", 0)
                            end
                            if (step > 0 and idx > limit) or
                               (step < 0 and idx < limit) then
                                pc = C[pc + 2]
                            else
                                pc = pc + 4
                            end
                            else
                                error("bad bytecode", 0)
                            end
                        else
                            if op < 49 then
                                if op == 47 then
                                local r = base + C[pc + 1] - 1
                                local step = S[r + 2]
                                local limit = S[r + 1]
                                local idx = S[r] + step
                                if (step > 0 and idx <= limit) or
                                   (step < 0 and idx >= limit) then
                                    S[r] = idx
                                    pc = C[pc + 2]
                                else
                                    pc = pc + 4
                                end
                                elseif op == 48 then
                                local cp = p.protos[C[pc + 1]]
                                local ud = cp.updesc
                                local ups = {}
                                for j = 1, #ud do
                                    local d = ud[j]
                                    if d.instack == 1 then
                                        ups[j] = S[base + d.idx - 1]
                                    else
                                        ups[j] = U[d.idx]
                                    end
                                end
                                top = top + 1
                                S[top] = make_closure(cp, ups, e, false)
                                pc = pc + 4
                                else
                                    error("bad bytecode", 0)
                                end
                            else
                                if op == 49 then
                                S[base + C[pc + 1] - 1] = S[top - C[pc + 2]]
                                pc = pc + 4
                                elseif op == 50 then
                                pc = pc + 4
                                elseif op == 51 then
                                local v = S[top]
                                S[top] = nil
                                top = top - 1
                                if v == nil then
                                    pc = C[pc + 1]
                                else
                                    pc = pc + 4
                                end
                                else
                                    error("bad bytecode", 0)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- LuaJIT 2.1 has an intermittent miscompile in the fused comparison path
-- (observed as e.g. "0.5 > -1" returning false after a large fuzz run).
-- Keep comparisons on the base opcodes when a LuaJIT runtime is present;
-- plain Lua hosts can still use the fused forms.
local has_jit = type(jit) == "table"

local function custom_loadstring(source, env, opts)
    if type(source) ~= "string" then
        return nil, "script must be a string"
    end
    if env == nil then
        env = {}
    elseif type(env) ~= "table" then
        return nil, "environment must be a table"
    end
    if opts ~= nil and type(opts) ~= "table" then
        return nil, "options must be a table"
    end

    local limits = {}
    for k, v in pairs(DEFAULT_LIMITS) do
        limits[k] = v
    end
    if opts then
        for k, v in pairs(opts) do
            if DEFAULT_LIMITS[k] ~= nil then
                if type(v) ~= "number" or v <= 0 or v ~= v then
                    return nil, "option '" .. tostring(k) ..
                        "' must be a positive number"
                end
                limits[k] = v
            end
        end
    end
    if #source > limits.maxSourceBytes then
        return nil, "source exceeds maxSourceBytes"
    end

    local sourceName = "<string>"
    if opts and opts.sourceName ~= nil then
        if type(opts.sourceName) ~= "string" then
            return nil, "option 'sourceName' must be a string"
        end
        sourceName = opts.sourceName
    end

    local function compile()
        local len = #source
        local pos = 1
        local tk = ""
        local tv = nil
        local tp = 1
        local last_tp = 1

        local line_starts = { 1 }
        local line_pos = 1
        while line_pos <= len do
            local nl = str_find(source, "[\r\n]", line_pos)
            if not nl then
                break
            end
            if str_sub(source, nl, nl) == "\r" and
               str_sub(source, nl + 1, nl + 1) == "\n" then
                line_pos = nl + 2
            else
                line_pos = nl + 1
            end
            line_starts[#line_starts + 1] = line_pos
        end

        local LOADK, LOADBOOL, LOADNIL = 1, 2, 3
        local GETLOCAL, SETLOCAL, GETCELL, SETCELL, CELL = 4, 5, 6, 7, 8
        local GETUPVAL, SETUPVAL, GETGLOBAL, SETGLOBAL = 9, 10, 11, 12
        local ADD, SUB, MUL, DIV, MOD, POW = 13, 14, 15, 16, 17, 18
        local CONCAT, UNM, NOT, LEN = 19, 20, 21, 22
        local EQ, NE, LT, LE, GT, GE = 23, 24, 25, 26, 27, 28
        local TESTF, TESTT, JMPF, JMP, CALLD = 29, 30, 31, 32, 33
        local RET, VARARG, NEWTABLE, FIELD, INDEX = 34, 35, 36, 37, 38
        local SETFIELD, SETINDEX, SELF, SETLIST, SETLISTMULTI = 39, 40, 41, 42, 43
        local MARK, POP, FORPREP, FORLOOP, CLOSURE = 44, 45, 46, 47, 48
        local PEEK, NOP, JMPNIL = 49, 50, 51

        local KWS = {
            ["and"] = true, ["break"] = true, ["do"] = true,
            ["else"] = true, ["elseif"] = true, ["end"] = true,
            ["false"] = true, ["for"] = true, ["function"] = true,
            ["if"] = true, ["in"] = true, ["local"] = true,
            ["nil"] = true, ["not"] = true, ["or"] = true,
            ["repeat"] = true, ["return"] = true, ["then"] = true,
            ["true"] = true, ["until"] = true, ["while"] = true,
        }

        local function line_of(p)
            local lo, hi = 1, #line_starts
            while lo < hi do
                local mid = math.floor((lo + hi + 1) / 2)
                if line_starts[mid] <= p then
                    lo = mid
                else
                    hi = mid - 1
                end
            end
            return lo
        end

        local function near()
            if tk == "eof" then
                return "<eof>"
            end
            local s = tostring(tv or tk)
            if #s > 40 then
                s = str_sub(s, 1, 37) .. "..."
            end
            return s
        end

        local function fail(msg)
            error("syntax error at line " .. line_of(tp) ..
                  " near '" .. near() .. "': " .. msg, 0)
        end

        local function long_open(p)
            local eq = str_match(source, "^%[(=*)%[", p)
            if eq ~= nil then
                return p + #eq + 2, eq
            end
            return nil, nil
        end

        local function skip_space()
            while true do
                local p = str_find(source, "[^ \t\r\n\f\v]", pos)
                if not p then
                    pos = len + 1
                    return
                end
                pos = p
                if str_sub(source, p, p) == "-" and
                   str_sub(source, p + 1, p + 1) == "-" then
                    local q = p + 2
                    local content, eq = long_open(q)
                    if content then
                        local close = str_find(source, "]" .. eq .. "]", content, true)
                        if not close then
                            tp = p
                            tv = "--"
                            fail("unfinished long comment")
                        end
                        pos = close + #eq + 2
                    else
                        local nl = str_find(source, "[\r\n]", q)
                        if not nl then
                            pos = len + 1
                            return
                        end
                        if str_sub(source, nl, nl) == "\r" and
                           str_sub(source, nl + 1, nl + 1) == "\n" then
                            pos = nl + 2
                        else
                            pos = nl + 1
                        end
                    end
                else
                    return
                end
            end
        end

        local esc = {
            a = "\a", b = "\b", f = "\f", n = "\n",
            r = "\r", t = "\t", v = "\v",
            ["\\"] = "\\", ['"'] = '"', ["'"] = "'",
        }

        local function read_string()
            local quote = str_sub(source, pos, pos)
            local p = pos + 1
            local start = p
            local parts = nil
            local pat = quote == '"' and '[\\"\r\n]' or "[\\'\r\n]"
            while true do
                local f = str_find(source, pat, p)
                if not f then
                    tp = pos
                    tv = quote
                    fail("unfinished string")
                end
                local ch = str_sub(source, f, f)
                if ch == quote then
                    local piece = str_sub(source, start, f - 1)
                    if parts then
                        parts[#parts + 1] = piece
                        tv = tconcat(parts)
                    else
                        tv = piece
                    end
                    pos = f + 1
                    tk = "string"
                    return
                elseif ch == "\n" or ch == "\r" then
                    tp = pos
                    tv = quote
                    fail("unfinished string")
                end

                local piece = str_sub(source, start, f - 1)
                if not parts then
                    parts = { piece }
                else
                    parts[#parts + 1] = piece
                end

                local e = str_sub(source, f + 1, f + 1)
                local rep = esc[e]
                if rep ~= nil then
                    parts[#parts + 1] = rep
                    p = f + 2
                elseif e == "\n" then
                    parts[#parts + 1] = "\n"
                    p = f + 2
                elseif e == "\r" then
                    parts[#parts + 1] = "\n"
                    if str_sub(source, f + 2, f + 2) == "\n" then
                        p = f + 3
                    else
                        p = f + 2
                    end
                elseif e >= "0" and e <= "9" then
                    local ds = str_match(source, "^%d%d?%d?", f + 1)
                    local n = tonumber(ds)
                    if n > 255 then
                        tp = f + 1
                        tv = ds
                        fail("decimal escape too large")
                    end
                    parts[#parts + 1] = str_char(n)
                    p = f + 1 + #ds
                else
                    tp = f + 1
                    tv = e
                    fail("invalid escape sequence")
                end
                start = p
            end
        end

        local function read_long_string()
            local start, eq = long_open(pos)
            local close = str_find(source, "]" .. eq .. "]", start, true)
            if not close then
                tp = pos
                tv = "["
                fail("unfinished long string")
            end
            local s = str_sub(source, start, close - 1)
            if str_sub(s, 1, 2) == "\r\n" then
                s = str_sub(s, 3)
            elseif str_sub(s, 1, 1) == "\n" or
                   str_sub(s, 1, 1) == "\r" then
                s = str_sub(s, 2)
            end
            pos = close + #eq + 2
            tk = "string"
            tv = s
        end

        local function read_number()
            local p = pos
            local c = str_sub(source, p, p)
            local q

            if c == "0" then
                local c2 = str_sub(source, p + 1, p + 1)
                if c2 == "x" or c2 == "X" then
                    q = str_find(source, "[^%x]", p + 2) or (len + 1)
                    if str_sub(source, q, q) == "." and
                       str_sub(source, q + 1, q + 1) == "." then
                        tp = p
                        tv = str_sub(source, p, q + 1)
                        fail("malformed number")
                    end
                    local s = str_sub(source, p, q - 1)
                    local n = tonumber(str_sub(s, 3), 16)
                    if not n then
                        tp = p
                        tv = s
                        fail("malformed number")
                    end
                    pos = q
                    tk = "number"
                    tv = n
                    return
                end
            end

            if c == "." then
                q = str_find(source, "[^%d]", p + 1) or (len + 1)
            else
                q = str_find(source, "[^%d]", p) or (len + 1)
                if str_sub(source, q, q) == "." and
                   str_sub(source, q + 1, q + 1) ~= "." then
                    q = str_find(source, "[^%d]", q + 1) or (len + 1)
                end
            end

            if str_sub(source, q, q) == "." and
               str_sub(source, q + 1, q + 1) == "." then
                tp = p
                tv = str_sub(source, p, q + 1)
                fail("malformed number")
            end

            local e = str_sub(source, q, q)
            if e == "e" or e == "E" then
                local ep = q + 1
                local sign = str_sub(source, ep, ep)
                if sign == "+" or sign == "-" then
                    ep = ep + 1
                end
                local d = str_sub(source, ep, ep)
                if d >= "0" and d <= "9" then
                    q = str_find(source, "[^%d]", ep) or (len + 1)
                end
            end

            local s = str_sub(source, p, q - 1)
            local n = tonumber(s)
            if not n then
                tp = p
                tv = s
                fail("malformed number")
            end
            pos = q
            tk = "number"
            tv = n
        end

        local function advance()
            last_tp = tp
            skip_space()
            tp = pos
            if pos > len then
                tk = "eof"
                tv = nil
                return
            end

            local c = str_sub(source, pos, pos)

            if c == "_" or (c >= "a" and c <= "z") or
               (c >= "A" and c <= "Z") then
                local name = str_match(source, "^[%a_][%w_]*", pos)
                pos = pos + #name
                tv = name
                if KWS[name] then
                    tk = name
                else
                    tk = "name"
                end
                return
            end

            local b = str_byte(source, pos)
            if (b >= 48 and b <= 57) or
               (c == "." and str_sub(source, pos + 1, pos + 1) >= "0" and
                str_sub(source, pos + 1, pos + 1) <= "9") then
                read_number()
                return
            end

            if c == '"' or c == "'" then
                read_string()
                return
            end

            if c == "[" then
                local content = long_open(pos)
                if content then
                    read_long_string()
                    return
                end
            end

            local c2 = str_sub(source, pos + 1, pos + 1)
            local c3 = str_sub(source, pos + 2, pos + 2)
            if c == "." and c2 == "." and c3 == "." then
                tk = "..."
                tv = "..."
                pos = pos + 3
                return
            end
            if (c == "=" and c2 == "=") or
               (c == "~" and c2 == "=") or
               (c == "<" and c2 == "=") or
               (c == ">" and c2 == "=") or
               (c == "." and c2 == ".") then
                tk = c .. c2
                tv = tk
                pos = pos + 2
                return
            end

            if c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or
               c == "^" or c == "#" or c == "<" or c == ">" or c == "=" or
               c == "(" or c == ")" or c == "[" or c == "]" or c == "{" or
               c == "}" or c == ";" or c == ":" or c == "," or c == "." then
                tk = c
                tv = c
                pos = pos + 1
                return
            end

            tv = c
            fail("unexpected character")
        end

        local function accept(kind)
            if tk == kind then
                advance()
                return true
            end
            return false
        end

        local function expect(kind)
            if tk ~= kind then
                fail("'" .. kind .. "' expected")
            end
            advance()
        end

        local all_protos = {}
        local fc

        local function new_fc(parent, isvararg, numparams)
            return {
                parent = parent,
                code = {}, lines = {}, ncode = 0,
                consts = {}, cmap = {}, kcount = 0,
                locals = {}, nlocals = 0,
                upvals = {},
                nextreg = 0, maxreg = 0,
                isvararg = isvararg, numparams = numparams,
                loop_depth = 0, loop_breaks = {},
            }
        end

        local function emit(op, a, b, c)
            local i = fc.ncode + 1
            local co = fc.code
            co[i] = op
            co[i + 1] = a or 0
            co[i + 2] = b or 0
            co[i + 3] = c or 0
            fc.lines[i] = line_of(last_tp)
            fc.ncode = i + 3
            return i
        end

        local function here()
            return fc.ncode + 1
        end

        local function patch_target(ins, target)
            fc.code[ins + 1] = target
        end

        local function patch_b(ins, target)
            fc.code[ins + 2] = target
        end

        local function patch_nres(ins, nres)
            if fc.code[ins] == VARARG then
                fc.code[ins + 1] = nres
            else
                fc.code[ins + 2] = nres
            end
        end

        local function addk(v)
            local idx = fc.cmap[v]
            if idx then
                return idx
            end
            idx = fc.kcount + 1
            fc.kcount = idx
            fc.consts[idx] = v
            fc.cmap[v] = idx
            return idx
        end

        local function reserve_reg()
            local r = fc.nextreg + 1
            fc.nextreg = r
            if r > fc.maxreg then
                fc.maxreg = r
            end
            return r
        end

        local function find_local(f, name)
            for i = f.nlocals, 1, -1 do
                local d = f.locals[i]
                if d.name == name then
                    return d
                end
            end
            return nil
        end

        local function mark_captured(desc)
            if desc.captured then
                return
            end
            desc.captured = true
            local f = desc.fc
            local co = f.code
            if desc.cell_pc then
                co[desc.cell_pc] = CELL
            end
            local acc = desc.access
            for i = 1, #acc do
                local p = acc[i]
                local op = co[p]
                if op == GETLOCAL then
                    co[p] = GETCELL
                elseif op == SETLOCAL then
                    co[p] = SETCELL
                end
            end
        end

        local function new_local(name)
            local d = {
                name = name,
                slot = reserve_reg(),
                captured = false,
                cell_pc = nil,
                access = {},
                fc = fc,
            }
            fc.nlocals = fc.nlocals + 1
            fc.locals[fc.nlocals] = d
            return d
        end

        local function emit_cell(desc)
            local p = emit(NOP, desc.slot, 0, 0)
            desc.cell_pc = p
            return p
        end

        local function emit_local_get(desc)
            local p
            if desc.captured then
                p = emit(GETCELL, desc.slot, 0, 0)
            else
                p = emit(GETLOCAL, desc.slot, 0, 0)
            end
            desc.access[#desc.access + 1] = p
            return p
        end

        local function emit_local_set(desc)
            local p
            if desc.captured then
                p = emit(SETCELL, desc.slot, 0, 0)
            else
                p = emit(SETLOCAL, desc.slot, 0, 0)
            end
            desc.access[#desc.access + 1] = p
            return p
        end

        local function find_upval(f, name)
            for i = 1, #f.upvals do
                if f.upvals[i].name == name then
                    return i
                end
            end
            return nil
        end

        local function add_upval(f, name, instack, idx)
            local old = find_upval(f, name)
            if old then
                return old
            end
            local n = #f.upvals + 1
            f.upvals[n] = { name = name, instack = instack, idx = idx }
            return n
        end

        local function resolve_upvalue(f, name)
            local parent = f.parent
            if not parent then
                return nil
            end
            local d = find_local(parent, name)
            if d then
                mark_captured(d)
                return add_upval(f, name, 1, d.slot)
            end
            local ui = find_upval(parent, name)
            if not ui then
                ui = resolve_upvalue(parent, name)
            end
            if ui then
                return add_upval(f, name, 0, ui)
            end
            return nil
        end

        local function resolve_var(name)
            local d = find_local(fc, name)
            if d then
                return "local", d
            end
            local ui = find_upval(fc, name)
            if not ui then
                ui = resolve_upvalue(fc, name)
            end
            if ui then
                return "upval", ui
            end
            return "global", addk(name)
        end

        local function emit_var_get(kind, ref)
            if kind == "local" then
                emit_local_get(ref)
            elseif kind == "upval" then
                emit(GETUPVAL, ref, 0, 0)
            else
                emit(GETGLOBAL, ref, 0, 0)
            end
        end

        local function enter_scope()
            return fc.nlocals, fc.nextreg
        end

        local function leave_scope(n, r)
            fc.nlocals = n
            fc.nextreg = r
        end

        local top_multi = false
        local last_multi_pc = nil

        local compile_expr
        local compile_table
        local parse_stmt
        local compile_funcbody
        local parse_block

        local function set_multi(pc)
            top_multi = true
            last_multi_pc = pc
        end

        local function clear_multi()
            top_multi = false
            last_multi_pc = nil
        end

        local function emit_loadnil(n)
            if n > 0 then
                emit(LOADNIL, n, 0, 0)
            end
        end

        local function emit_pop(n)
            if n > 0 then
                emit(POP, n, 0, 0)
            end
        end

        -- ========================================================
        -- Post-compile peephole optimizer: fuses frequent instruction
        -- sequences into superinstructions without shifting code.
        -- ========================================================
        local function optimize_code(co, n)
            local targets = {}
            local dead = {}

            for pc = 1, n, 4 do
                local op = co[pc]
                if op == JMP or op == JMPF or op == TESTF or
                   op == TESTT or op == JMPNIL then
                    targets[co[pc + 1]] = true
                elseif op == FORPREP or op == FORLOOP then
                    targets[co[pc + 2]] = true
                end
            end

            local function can(pos, len)
                for i = 1, len - 1 do
                    local p = pos + i * 4
                    if dead[p] or targets[p] then
                        return false
                    end
                end
                return true
            end

            -- Like can(), but tolerates a jump target on the final slot.
            -- The last instruction of a fused sequence stays in place and
            -- therefore remains valid for jumps that land on it; only the
            -- fall-through path skips it.
            local function can_tail(pos, len)
                local last = pos + (len - 1) * 4
                for i = 1, len - 1 do
                    local p = pos + i * 4
                    if dead[p] then
                        return false
                    end
                    if p ~= last and targets[p] then
                        return false
                    end
                end
                return true
            end
            local function put(pos, op, a, b, c, len)                co[pos] = op
                co[pos + 1] = a or 0
                co[pos + 2] = b or 0
                co[pos + 3] = c or 0
                for i = 1, len - 1 do
                    dead[pos + i * 4] = true
                end
            end

            local rr = {
                [ADD] = FOP.ADD_RR, [SUB] = FOP.SUB_RR,
                [MUL] = FOP.MUL_RR, [DIV] = FOP.DIV_RR,
                [MOD] = FOP.MOD_RR, [POW] = FOP.POW_RR,
                [EQ] = FOP.EQ_RR, [NE] = FOP.NE_RR,
                [LT] = FOP.LT_RR, [LE] = FOP.LE_RR,
                [GT] = FOP.GT_RR, [GE] = FOP.GE_RR,
            }
            local rk = {
                [ADD] = FOP.ADD_RK, [SUB] = FOP.SUB_RK,
                [MUL] = FOP.MUL_RK, [DIV] = FOP.DIV_RK,
                [MOD] = FOP.MOD_RK, [POW] = FOP.POW_RK,
                [EQ] = FOP.EQ_RK, [NE] = FOP.NE_RK,
                [LT] = FOP.LT_RK, [LE] = FOP.LE_RK,
                [GT] = FOP.GT_RK, [GE] = FOP.GE_RK,
            }
            -- Compound assignment travels as one opcode per shape; the
            -- operator kind is the base arithmetic opcode number.
            local assign_kind = {
                [ADD] = 13, [SUB] = 14, [MUL] = 15,
                [DIV] = 16, [MOD] = 17, [POW] = 18, [CONCAT] = 19,
            }
            local kop = {
                [EQ] = FOP.EQ_K, [NE] = FOP.NE_K,
                [LT] = FOP.LT_K, [LE] = FOP.LE_K,
                [GT] = FOP.GT_K, [GE] = FOP.GE_K,
            }
            if has_jit then
                -- See the LuaJIT note near custom_loadstring. Equality
                -- fusions are safe; only ordering comparisons have the
                -- intermittent upstream miscompile.
                for _, op in ipairs({ LT, LE, GT, GE }) do
                    rr[op] = nil
                    rk[op] = nil
                    kop[op] = nil
                end
            end

            local function try_stmt(pos)
                -- t[i % k] = v
                if co[pos] == GETLOCAL and co[pos + 4] == GETLOCAL and
                   co[pos + 8] == LOADK and co[pos + 12] == MOD and
                   co[pos + 16] == SETLOCAL and co[pos + 20] == SETLOCAL and
                   co[pos + 24] == GETLOCAL and co[pos + 28] == SETINDEX and
                   can(pos, 8) then
                    local t = co[pos + 1]
                    local i = co[pos + 5]
                    local kmod = co[pos + 9]
                    local ktmp = co[pos + 17]
                    local ttmp = co[pos + 21]
                    local v = co[pos + 25]
                    if co[pos + 29] == ttmp and co[pos + 30] == ktmp and
                       t ~= ttmp and t ~= ktmp and v ~= ttmp and v ~= ktmp then
                        put(pos, FOP.SETINDEX_MOD_RK, t, i, kmod, 8)
                        co[pos + 4] = v
                        return pos + 32
                    end
                end

                -- t[K] = V / t[K] = constant
                if co[pos] == GETLOCAL and co[pos + 4] == GETLOCAL and
                   co[pos + 8] == SETLOCAL and co[pos + 12] == SETLOCAL and
                   (co[pos + 16] == GETLOCAL or co[pos + 16] == LOADK) and
                   co[pos + 20] == SETINDEX and can(pos, 6) then
                    local t = co[pos + 1]
                    local k = co[pos + 5]
                    local keytemp = co[pos + 9]
                    local basetemp = co[pos + 13]
                    local v = co[pos + 17]
                    if co[pos + 21] == basetemp and
                       co[pos + 22] == keytemp and
                       t ~= keytemp and t ~= basetemp and
                       k ~= keytemp and k ~= basetemp and
                       v ~= keytemp and v ~= basetemp then
                        if co[pos + 16] == GETLOCAL then
                            put(pos, FOP.SETINDEX_RR, t, k, v, 6)
                        else
                            put(pos, FOP.SETINDEX_RK, t, k, v, 6)
                        end
                        return pos + 24
                    end
                end

                -- t.field = V / t.field = constant
                if co[pos] == GETLOCAL and co[pos + 4] == SETLOCAL and
                   (co[pos + 8] == GETLOCAL or co[pos + 8] == LOADK) and
                   co[pos + 12] == SETFIELD and can(pos, 4) then
                    local t = co[pos + 1]
                    local basetemp = co[pos + 5]
                    local v = co[pos + 9]
                    local key = co[pos + 14]
                    if co[pos + 13] == basetemp and
                       t ~= basetemp and v ~= basetemp then
                        if co[pos + 8] == GETLOCAL then
                            put(pos, FOP.SETFIELD_RV, t, key, v, 4)
                        else
                            put(pos, FOP.SETFIELD_RK, t, key, v, 4)
                        end
                        return pos + 16
                    end
                end

                -- target = target + (a op b)
                if pos + 20 <= n and co[pos] == GETLOCAL and
                   co[pos + 4] == GETLOCAL and co[pos + 8] == GETLOCAL and
                   (co[pos + 12] == ADD or co[pos + 12] == SUB or co[pos + 12] == MUL) and
                   co[pos + 16] == ADD and co[pos + 20] == SETLOCAL and
                   co[pos + 21] == co[pos + 1] and can(pos, 6) then
                    local dest = co[pos + 1]
                    local a = co[pos + 5]
                    local b = co[pos + 9]
                    if dest ~= a and dest ~= b then
                        put(pos, FOP.ADD_ASSIGN_BINOP_RR, dest, a, b, 6)
                        return pos + 24
                    end
                end

                -- target = target + table[key]
                if co[pos] == GETLOCAL and co[pos + 4] == GETLOCAL and
                   co[pos + 8] == GETLOCAL and co[pos + 12] == INDEX and
                   co[pos + 16] == ADD and co[pos + 20] == SETLOCAL and
                   co[pos + 21] == co[pos + 1] and can(pos, 6) then
                    local a = co[pos + 1]
                    local t = co[pos + 5]
                    local k = co[pos + 9]
                    if a ~= t and a ~= k and t ~= k then
                        put(pos, FOP.ASSIGN_INDEX, a, t, k, 6)
                        co[pos + 4] = 13
                        return pos + 24
                    end
                end

                -- a, b = b, a  ->  one swap
                --   GETLOCAL B ; GETLOCAL A ; SETLOCAL B ; SETLOCAL A
                -- Matched on the raw sequence, before the GETLOCAL/SETLOCAL
                -- pairs below are folded into MOVLOCAL.
                if co[pos] == GETLOCAL and co[pos + 4] == GETLOCAL and
                   co[pos + 8] == SETLOCAL and co[pos + 12] == SETLOCAL and
                   co[pos + 9] == co[pos + 1] and co[pos + 13] == co[pos + 5] and
                   co[pos + 1] ~= co[pos + 5] and
                   can(pos, 4) then
                    put(pos, FOP.SWAP, co[pos + 1], co[pos + 5], 0, 4)
                    return pos + 16
                end

                -- s = (s + i) % k  ->  one fused op
                if pos + 20 <= n and co[pos] == GETLOCAL and
                   co[pos + 4] == GETLOCAL and co[pos + 8] == ADD and
                   co[pos + 12] == LOADK and co[pos + 16] == MOD and
                   co[pos + 20] == SETLOCAL and co[pos + 21] == co[pos + 1] and
                   can(pos, 6) then
                    put(pos, FOP.ASSIGN_MOD_ADD_RK, co[pos + 1], co[pos + 5], co[pos + 13], 6)
                    return pos + 24
                end

                -- target = target op operand, operand = local/constant
                if co[pos] == GETLOCAL and
                   (co[pos + 4] == GETLOCAL or co[pos + 4] == LOADK) and
                   co[pos + 12] == SETLOCAL and
                   co[pos + 13] == co[pos + 1] and can(pos, 4) then
                    local op = co[pos + 8]
                    local kind = assign_kind[op]
                    if kind then
                        if co[pos + 4] == GETLOCAL then
                            put(pos, FOP.ASSIGN_RR, co[pos + 1], co[pos + 5], 0, 4)
                        else
                            put(pos, FOP.ASSIGN_RK, co[pos + 1], co[pos + 5], 0, 4)
                        end
                        co[pos + 4] = kind
                        return pos + 16
                    end
                end

                -- target = table[key]
                if co[pos] == GETLOCAL and co[pos + 4] == GETLOCAL and
                   co[pos + 8] == INDEX and co[pos + 12] == SETLOCAL and
                   can(pos, 4) then
                    local dest = co[pos + 13]
                    local t = co[pos + 1]
                    local k = co[pos + 5]
                    if dest ~= t and dest ~= k and t ~= k then
                        put(pos, FOP.SETLOCAL_INDEX, dest, t, k, 4)
                        return pos + 16
                    end
                end

                -- target = table.field
                if co[pos] == GETLOCAL and co[pos + 4] == FIELD and
                   co[pos + 8] == SETLOCAL and can(pos, 3) then
                    local dest = co[pos + 9]
                    local t = co[pos + 1]
                    local key = co[pos + 5]
                    if dest ~= t then
                        put(pos, FOP.SETLOCAL_FIELD, dest, t, key, 3)
                        return pos + 12
                    end
                end

                -- target = constant
                if co[pos] == LOADK and co[pos + 4] == SETLOCAL and
                   can(pos, 2) then
                    put(pos, FOP.SETLOCAL_K, co[pos + 5], co[pos + 1], 0, 2)
                    return pos + 8
                end

                -- target = boolean
                if co[pos] == LOADBOOL and co[pos + 4] == SETLOCAL and
                   can(pos, 2) then
                    put(pos, FOP.SETLOCAL_BOOL, co[pos + 5], co[pos + 1], 0, 2)
                    return pos + 8
                end

                -- local cell = { v = x }; local f = function() ... end
                --   GETLOCAL src ; SETLOCAL cellreg ; CELL cellreg ; CLOSURE proto ; SETLOCAL dest
                if co[pos] == GETLOCAL and co[pos + 4] == SETLOCAL and
                   co[pos + 8] == CELL and co[pos + 12] == CLOSURE and
                   co[pos + 16] == SETLOCAL and
                   co[pos + 5] == co[pos + 9] and
                   co[pos + 1] ~= co[pos + 5] and
                   co[pos + 17] ~= co[pos + 5] and
                   co[pos + 17] ~= co[pos + 1] and
                   can(pos, 5) then
                    put(pos, FOP.CLOSURE_CELL, co[pos + 5], co[pos + 1], co[pos + 17], 5)
                    co[pos + 4] = co[pos + 13]
                    return pos + 20
                end

                -- t[cell.v] = function() ... end
                --   GETLOCAL src ; SETLOCAL cellreg ; CELL cellreg ; GETLOCAL t ;
                --   GETCELL cellreg ; SETLOCAL ktmp ; SETLOCAL ttmp ; CLOSURE proto ;
                --   SETINDEX ttmp ktmp
                if co[pos] == GETLOCAL and co[pos + 4] == SETLOCAL and
                   co[pos + 8] == CELL and co[pos + 12] == GETLOCAL and
                   co[pos + 16] == GETCELL and co[pos + 20] == SETLOCAL and
                   co[pos + 24] == SETLOCAL and co[pos + 28] == CLOSURE and
                   co[pos + 32] == SETINDEX and
                   co[pos + 5] == co[pos + 9] and co[pos + 5] == co[pos + 17] and
                   co[pos + 33] == co[pos + 25] and
                   co[pos + 34] == co[pos + 21] and
                   co[pos + 21] ~= co[pos + 13] and
                   co[pos + 25] ~= co[pos + 13] and
                   co[pos + 13] ~= co[pos + 5] and
                   co[pos + 13] ~= co[pos + 1] and
                   can(pos, 9) then
                    put(pos, FOP.SETINDEX_CLOSURE_CELL,
                        co[pos + 5], co[pos + 1], co[pos + 13], 9)
                    co[pos + 4] = co[pos + 29]
                    return pos + 36
                end

                -- loop variable: GETLOCAL; SETLOCAL raw; CELL/NOP
                if co[pos] == GETLOCAL and co[pos + 4] == SETLOCAL and
                   (co[pos + 8] == NOP or co[pos + 8] == CELL) and
                   can(pos, 3) then
                    local dest = co[pos + 5]
                    local src = co[pos + 1]
                    if dest ~= src then
                        if co[pos + 8] == CELL then
                            put(pos, FOP.MOVLOCAL_CELL, dest, src, 0, 3)
                        else
                            put(pos, FOP.MOVLOCAL_NOP, dest, src, 0, 3)
                        end
                        return pos + 12
                    end
                end

                -- target = source
                if co[pos] == GETLOCAL and co[pos + 4] == SETLOCAL and
                   can(pos, 2) then
                    local dest = co[pos + 5]
                    local src = co[pos + 1]
                    if dest ~= src then
                        put(pos, FOP.MOVLOCAL, dest, src, 0, 2)
                        return pos + 8
                    end
                end

                return nil
            end

            local function try_expr(pos)
                -- generic for (2 variables): GETLOCAL freg .. JMPNIL_LOCAL creg
                if pos + 52 <= n and co[pos] == GETLOCAL and
                   co[pos + 4] == MARK and co[pos + 8] == GETLOCAL and
                   co[pos + 12] == GETLOCAL and co[pos + 16] == CALLD and
                   co[pos + 18] == 2 and co[pos + 20] == PEEK and
                   co[pos + 24] == SETLOCAL and
                   (co[pos + 28] == NOP or co[pos + 28] == CELL) and
                   co[pos + 32] == SETLOCAL and
                   (co[pos + 36] == NOP or co[pos + 36] == CELL) and
                   co[pos + 40] == FOP.MOVLOCAL and
                   co[pos + 48] == GETLOCAL and co[pos + 52] == JMPNIL and
                   can(pos, 11) and not targets[pos + 48] and not targets[pos + 52] then
                    local freg = co[pos + 1]
                    if co[pos + 9] == freg + 1 and co[pos + 13] == freg + 2 and
                       co[pos + 33] == freg + 3 and co[pos + 25] == freg + 4 and
                       co[pos + 41] == freg + 2 and co[pos + 49] == freg + 2 then
                        put(pos + 48, FOP.JMPNIL_LOCAL, freg + 2, co[pos + 53], 0, 2)
                        co[pos] = FOP.TFOR_2
                        co[pos + 1] = freg
                        co[pos + 2] = (co[pos + 28] == CELL or co[pos + 36] == CELL) and 1 or 0
                        co[pos + 3] = 0
                        return pos + 56
                    end
                end

                -- generic for (1 variable): GETLOCAL freg .. JMPNIL_LOCAL creg
                if pos + 44 <= n and co[pos] == GETLOCAL and
                   co[pos + 4] == MARK and co[pos + 8] == GETLOCAL and
                   co[pos + 12] == GETLOCAL and co[pos + 16] == CALLD and
                   co[pos + 18] == 1 and co[pos + 20] == PEEK and
                   co[pos + 24] == SETLOCAL and
                   (co[pos + 28] == NOP or co[pos + 28] == CELL) and
                   co[pos + 32] == FOP.MOVLOCAL and
                   co[pos + 40] == GETLOCAL and co[pos + 44] == JMPNIL and
                   can(pos, 9) and not targets[pos + 40] and not targets[pos + 44] then
                    local freg = co[pos + 1]
                    if co[pos + 9] == freg + 1 and co[pos + 13] == freg + 2 and
                       co[pos + 25] == freg + 3 and
                       co[pos + 33] == freg + 2 and co[pos + 41] == freg + 2 then
                        put(pos + 40, FOP.JMPNIL_LOCAL, freg + 2, co[pos + 45], 0, 2)
                        co[pos] = FOP.TFOR_1
                        co[pos + 1] = freg
                        co[pos + 2] = (co[pos + 28] == CELL) and 1 or 0
                        co[pos + 3] = 0
                        return pos + 48
                    end
                end

                -- local/local and local/constant comparison directly followed by JMPF
                if co[pos] == GETLOCAL and
                   (co[pos + 4] == GETLOCAL or co[pos + 4] == LOADK) and
                   co[pos + 8] >= EQ and co[pos + 8] <= GE and
                   co[pos + 12] == JMPF and
                   can_tail(pos, 4) then
                    local kind = co[pos + 8]
                    local fused
                    if co[pos + 4] == GETLOCAL then
                        fused = FOP.JMPF_CMP_RR
                    else
                        fused = FOP.JMPF_CMP_RK
                    end
                    put(pos, fused, co[pos + 1], co[pos + 5], co[pos + 13], 4)
                    co[pos + 4] = kind
                    return pos + 16
                end

                -- local/local and local/constant comparison directly followed by TESTF/TESTT
                if co[pos] == GETLOCAL and
                   (co[pos + 4] == GETLOCAL or co[pos + 4] == LOADK) and
                   co[pos + 8] >= EQ and co[pos + 8] <= GE and
                   (co[pos + 12] == TESTF or co[pos + 12] == TESTT) and
                   can_tail(pos, 4) then
                    local cop = co[pos + 8]
                    local op2
                    if co[pos + 12] == TESTF then
                        op2 = (co[pos + 4] == GETLOCAL) and FOP.TESTF_CMP_RR or FOP.TESTF_CMP_RK
                    else
                        op2 = (co[pos + 4] == GETLOCAL) and FOP.TESTT_CMP_RR or FOP.TESTT_CMP_RK
                    end
                    put(pos, op2, co[pos + 1], co[pos + 5], co[pos + 13], 4)
                    co[pos + 4] = cop
                    return pos + 16
                end

                -- t[k] = { field = local }
                if pos + 36 <= n and co[pos] == GETLOCAL and
                   co[pos + 4] == FOP.MOVLOCAL and co[pos + 12] == SETLOCAL and
                   co[pos + 16] == NEWTABLE and co[pos + 20] == SETLOCAL and
                   (co[pos + 24] == GETLOCAL or co[pos + 24] == LOADK) and
                   co[pos + 28] == SETFIELD and co[pos + 29] == co[pos + 21] and
                   co[pos + 32] == GETLOCAL and co[pos + 33] == co[pos + 21] and
                   co[pos + 36] == SETINDEX and
                   not targets[pos + 4] and not targets[pos + 12] and
                   not targets[pos + 16] and not targets[pos + 20] and
                   not targets[pos + 24] and not targets[pos + 28] and
                   not targets[pos + 32] and not targets[pos + 36] then
                    local t = co[pos + 1]
                    local keytemp = co[pos + 5]
                    local k = co[pos + 6]
                    local basetemp = co[pos + 13]
                    local treg = co[pos + 21]
                    local v = co[pos + 25]
                    local fkey = co[pos + 30]
                    if co[pos + 24] == GETLOCAL and
                       co[pos + 37] == basetemp and co[pos + 38] == keytemp and
                       t ~= keytemp and t ~= basetemp and
                       k ~= keytemp and k ~= basetemp and
                       v ~= keytemp and v ~= basetemp and v ~= treg then
                        co[pos + 25] = fkey
                        put(pos, FOP.NEWTABLE_SETINDEX_R, t, k, v, 10)
                        return pos + 40
                    end
                end

                -- single-field table constructor: { field = local/const }
                if pos + 16 <= n and co[pos] == NEWTABLE and
                   co[pos + 4] == SETLOCAL and
                   (co[pos + 8] == GETLOCAL or co[pos + 8] == LOADK) and
                   co[pos + 12] == SETFIELD and co[pos + 13] == co[pos + 5] and
                   not targets[pos + 4] and not targets[pos + 8] and
                   not targets[pos + 12] and not targets[pos + 16] then
                    local treg = co[pos + 5]
                    local v = co[pos + 9]
                    local k = co[pos + 14]
                    if co[pos + 8] ~= GETLOCAL or v ~= treg then
                        local op = co[pos + 8] == GETLOCAL and FOP.NEWTABLE_FIELD_R or FOP.NEWTABLE_FIELD_K
                        if co[pos + 16] == FOP.MOVLOCAL and co[pos + 18] == treg and
                           pos + 20 <= n and not targets[pos + 20] then
                            put(pos, op, k, v, co[pos + 17], 6)
                            return pos + 24
                        elseif co[pos + 16] == GETLOCAL and co[pos + 17] == treg then
                            put(pos, op, k, v, 0, 5)
                            return pos + 20
                        end
                    end
                end

                -- table allocation directly into local register
                if pos + 68 <= n and co[pos] == NEWTABLE and
                   co[pos + 4] == SETLOCAL and
                   co[pos + 8] == MARK and co[pos + 12] == GETLOCAL and
                   co[pos + 16] == SETLIST and co[pos + 18] == 1 and
                   co[pos + 20] == MARK and co[pos + 24] == GETLOCAL and
                   co[pos + 28] == LOADK and co[pos + 32] == ADD and
                   co[pos + 36] == SETLIST and co[pos + 38] == 2 and
                   co[pos + 40] == MARK and co[pos + 44] == GETLOCAL and
                   co[pos + 48] == LOADK and co[pos + 52] == ADD and
                   co[pos + 56] == SETLIST and co[pos + 58] == 3 and
                   co[pos + 60] == FOP.MOVLOCAL_NOP and
                   co[pos + 62] == co[pos + 5] and
                   not targets[pos + 4] and not targets[pos + 8] and
                   not targets[pos + 12] and not targets[pos + 16] and
                   not targets[pos + 20] and not targets[pos + 24] and
                   not targets[pos + 28] and not targets[pos + 32] and
                   not targets[pos + 36] and not targets[pos + 40] and
                   not targets[pos + 44] and not targets[pos + 48] and
                   not targets[pos + 52] and not targets[pos + 56] and
                   not targets[pos + 60] then
                    local treg = co[pos + 5]
                    local mreg = co[pos + 9]
                    local v = co[pos + 13]
                    local dest = co[pos + 61]
                    if co[pos + 17] == treg and co[pos + 37] == treg and
                       co[pos + 57] == treg and co[pos + 25] == v and
                       co[pos + 45] == v and v ~= treg and v ~= mreg then
                        if pos + 92 <= n and co[pos + 72] == GETLOCAL and
                           co[pos + 76] == GETLOCAL and co[pos + 77] == dest and
                           co[pos + 80] == LOADK and co[pos + 84] == INDEX and
                           co[pos + 88] == ADD and co[pos + 92] == SETLOCAL and
                           co[pos + 93] == co[pos + 73] and
                           co[pos + 96] == FOP.FORLOOP_MOV and
                           co[pos + 73] ~= dest and
                           not targets[pos + 72] and not targets[pos + 76] and
                           not targets[pos + 80] and not targets[pos + 84] and
                           not targets[pos + 88] and not targets[pos + 92] then
                            co[pos + 77] = co[pos + 81]
                            put(pos, FOP.NEWTABLE_LIST3_ADD_RK, dest, v, co[pos + 73], 24)
                            return pos + 96
                        end
                        put(pos, FOP.NEWTABLE_LIST3_ADD_RK, dest, v, 0, 18)
                        return pos + 72
                    end
                end

                if co[pos] == NEWTABLE and co[pos + 4] == SETLOCAL and
                   can(pos, 2) then
                    put(pos, FOP.NEWTABLE_LOCAL, co[pos + 5], 0, 0, 2)
                    return pos + 8
                end

                -- list constructor elements: MARK + (GETLOCAL | LOADK) + SETLIST
                if pos + 8 <= n and co[pos] == MARK and
                   (co[pos + 4] == GETLOCAL or co[pos + 4] == LOADK) and
                   co[pos + 8] == SETLIST and can(pos, 3) then
                    local mreg = co[pos + 1]
                    local treg = co[pos + 9]
                    local idx = co[pos + 10]
                    local v = co[pos + 5]
                    if co[pos + 4] == GETLOCAL then
                        if v ~= mreg then
                            put(pos, FOP.SETLIST_R, treg, idx, v, 3)
                            return pos + 12
                        end
                    else
                        put(pos, FOP.SETLIST_K, treg, idx, v, 3)
                        return pos + 12
                    end
                end

                -- list constructor elements: MARK + GETLOCAL + LOADK + ADD + SETLIST
                if pos + 16 <= n and co[pos] == MARK and
                   co[pos + 4] == GETLOCAL and
                   co[pos + 8] == LOADK and
                   co[pos + 12] == ADD and co[pos + 16] == SETLIST and
                   can(pos, 5) then
                    local mreg = co[pos + 1]
                    local treg = co[pos + 17]
                    local idx = co[pos + 18]
                    local a = co[pos + 5]
                    if a ~= mreg then
                        put(pos, FOP.SETLIST_ADD_RK, treg, idx, a, 5)
                        return pos + 20
                    end
                end

                -- constant comparison directly followed by JMPF
                if co[pos] == LOADK and co[pos + 4] >= EQ and co[pos + 4] <= GE and
                   co[pos + 8] == JMPF and can(pos, 3) then
                    local kind = co[pos + 4]
                    put(pos, FOP.JMPF_CMP_K, co[pos + 1], co[pos + 9], 0, 3)
                    co[pos + 4] = kind
                    return pos + 12
                end

                -- local/global condition
                if co[pos] == GETLOCAL and co[pos + 4] == JMPF and
                   can(pos, 2) then
                    put(pos, FOP.JMPF_LOCAL, co[pos + 1], co[pos + 5], 0, 2)
                    return pos + 8
                end
                if co[pos] == GETLOCAL and co[pos + 4] == JMPNIL and
                   can(pos, 2) then
                    put(pos, FOP.JMPNIL_LOCAL, co[pos + 1], co[pos + 5], 0, 2)
                    return pos + 8
                end

                -- table[key]
                if co[pos] == GETLOCAL and
                   (co[pos + 4] == GETLOCAL or co[pos + 4] == LOADK) and
                   co[pos + 8] == INDEX and can(pos, 3) then
                    if co[pos + 4] == GETLOCAL then
                        put(pos, FOP.INDEX_RR, co[pos + 1], co[pos + 5], 0, 3)
                    else
                        put(pos, FOP.INDEX_RK, co[pos + 1], co[pos + 5], 0, 3)
                    end
                    return pos + 12
                end

                -- table.field
                if co[pos] == GETLOCAL and co[pos + 4] == FIELD and
                   can(pos, 2) then
                    put(pos, FOP.FIELD_R, co[pos + 1], co[pos + 5], 0, 2)
                    return pos + 8
                end

                -- local/local and local/constant arithmetic/comparison
                if co[pos] == GETLOCAL and
                   (co[pos + 4] == GETLOCAL or co[pos + 4] == LOADK) and
                   rr[co[pos + 8]] and can(pos, 3) then
                    if co[pos + 4] == GETLOCAL then
                        put(pos, rr[co[pos + 8]], co[pos + 1], co[pos + 5], 0, 3)
                    else
                        put(pos, rk[co[pos + 8]], co[pos + 1], co[pos + 5], 0, 3)
                    end
                    return pos + 12
                end

                -- stack value op constant
                if co[pos] == LOADK and kop[co[pos + 4]] and can(pos, 2) then
                    put(pos, kop[co[pos + 4]], co[pos + 1], 0, 0, 2)
                    return pos + 8
                end

                return nil
            end

            local pos = 1
            while pos <= n do
                if dead[pos] then
                    pos = pos + 4
                else
                    local np = try_stmt(pos)
                    if np then pos = np else pos = pos + 4 end
                end
            end

            -- Fold the per-iteration loop-variable copy into FORLOOP.
            -- The first iteration still uses the MOV instruction after FORPREP;
            -- every following iteration is copied by FORLOOP itself.
            for pc = 1, n, 4 do
                if co[pc] == FORLOOP then
                    local ctrl = co[pc + 1]
                    local body = co[pc + 2]
                    if body >= 1 and body <= n and
                       body + 12 <= n and not dead[body] then
                        local mop = co[body]
                        if (mop == FOP.MOVLOCAL_NOP or
                            mop == FOP.MOVLOCAL_CELL) and
                           co[body + 2] == ctrl then
                            local dest = co[body + 1]
                            if mop == FOP.MOVLOCAL_CELL then
                                co[pc] = FOP.FORLOOP_CELL
                            else
                                co[pc] = FOP.FORLOOP_MOV
                            end
                            co[pc + 1] = ctrl
                            co[pc + 2] = dest
                            co[pc + 3] = body + 12
                            targets[body + 12] = true
                        end
                    end
                end
            end

            pos = 1
            while pos <= n do
                if dead[pos] then
                    pos = pos + 4
                else
                    local np = try_expr(pos)
                    if np then pos = np else pos = pos + 4 end
                end
            end

            -- Fold `(value % K) == K2` and `(value % reg) == K2` + JMPF into one branch.
            for pc = 1, n, 4 do
                local jop = co[pc + 12]
                if (co[pc] == FOP.MOD_RK or co[pc] == FOP.MOD_RR) and
                   pc + 20 <= n and
                   (jop == FOP.JMPF_CMP_K and co[pc + 16] == EQ) and
                   not dead[pc] and not targets[pc + 4] and
                   not targets[pc + 8] and not targets[pc + 12] and
                   not targets[pc + 20] then
                    local r = co[pc + 1]
                    local kmod = co[pc + 2]
                    local keq = co[pc + 13]
                    co[pc] = co[pc] == FOP.MOD_RK and FOP.JMPF_MOD_EQ_K or FOP.JMPF_MOD_RR_EQ_K
                    co[pc + 1] = r
                    co[pc + 2] = kmod
                    co[pc + 3] = keq
                    for i = 1, 5 do
                        dead[pc + i * 4] = true
                    end
                end
            end

            -- Fold the first body operation into FORLOOP as well. This
            -- removes one dispatch per iteration for the hot numeric-loop
            -- patterns `sum = sum + i`, `t[i] = i`, and similar.
            for pc = 1, n, 4 do
                if co[pc] == FOP.FORLOOP_MOV then
                    local ctrl = co[pc + 1]
                    local dest = co[pc + 2]
                    local body = co[pc + 3] - 12
                    if body >= 1 and body + 28 <= n and
                       not dead[body] and not dead[body + 12] and
                       co[body + 2] == ctrl then
                        local bop = co[body + 12]
                        local fused, nxt
                        if bop == FOP.ASSIGN_RR and co[body + 16] == 13 then
                            fused, nxt = FOP.FORLOOP_ADD_RR, body + 28
                        elseif bop == FOP.ASSIGN_RK and co[body + 16] == 13 then
                            fused, nxt = FOP.FORLOOP_ADD_RK, body + 28
                        elseif bop == FOP.ASSIGN_INDEX and co[body + 16] == 13 and
                               body + 36 <= n then
                            fused, nxt = FOP.FORLOOP_ADD_INDEX, body + 36
                        elseif bop == FOP.SETINDEX_RR and
                               body + 36 <= n then
                            fused, nxt = FOP.FORLOOP_SETINDEX_RR, body + 36
                        elseif bop == FOP.SETINDEX_RK and
                               body + 36 <= n then
                            fused, nxt = FOP.FORLOOP_SETINDEX_RK, body + 36
                        elseif bop == FOP.ASSIGN_RR and co[body + 16] == 14 then
                            fused, nxt = FOP.FORLOOP_SUB_RR, body + 28
                        elseif bop == FOP.ASSIGN_RK and co[body + 16] == 14 then
                            fused, nxt = FOP.FORLOOP_SUB_RK, body + 28
                        elseif bop == FOP.ASSIGN_RR and co[body + 16] >= 15 and
                               co[body + 16] <= 19 then
                            fused, nxt = FOP.FORLOOP_ASSIGN_RR, body + 28
                        elseif bop == FOP.ASSIGN_RK and co[body + 16] >= 15 and
                               co[body + 16] <= 19 then
                            fused, nxt = FOP.FORLOOP_ASSIGN_RK, body + 28
                        elseif bop == FOP.JMPF_MOD_RR_EQ_K and
                               body + 36 <= n then
                            fused, nxt = FOP.FORLOOP_MOD_RR_EQ_K, body + 36
                        elseif bop == FOP.NEWTABLE_SETINDEX_R and
                               body + 52 <= n then
                            fused, nxt = FOP.FORLOOP_NEWTABLE_SETINDEX_R, body + 52
                        end
                        if fused then
                            co[pc] = fused
                            co[pc + 1] = ctrl
                            co[pc + 2] = dest
                            co[pc + 3] = body
                            targets[nxt] = true
                        end
                    end
                end
            end
        end

        local function parse_call_args(offset)
            local oldreg = fc.nextreg
            local mreg = reserve_reg()
            emit(MARK, mreg, offset, 0)

            if tk == "(" then
                advance()
                if tk ~= ")" then
                    while true do
                        compile_expr()
                        if tk == "," then
                            advance()
                        else
                            if top_multi then
                                patch_nres(last_multi_pc, -1)
                            end
                            break
                        end
                    end
                end
                expect(")")
            elseif tk == "{" then
                compile_table()
            elseif tk == "string" then
                local k = addk(tv)
                advance()
                emit(LOADK, k, 0, 0)
            else
                fail("function arguments expected")
            end

            local callpc = emit(CALLD, mreg, 1, 0)
            fc.nextreg = oldreg
            set_multi(callpc)
            return callpc
        end

        local function compile_suffix()
            while true do
                if tk == "." then
                    advance()
                    if tk ~= "name" then
                        fail("field name expected")
                    end
                    local k = addk(tv)
                    advance()
                    emit(FIELD, k, 0, 0)
                    clear_multi()
                elseif tk == "[" then
                    advance()
                    compile_expr()
                    expect("]")
                    emit(INDEX, 0, 0, 0)
                    clear_multi()
                elseif tk == "(" or tk == "{" or tk == "string" then
                    parse_call_args(0)
                elseif tk == ":" then
                    advance()
                    if tk ~= "name" then
                        fail("method name expected")
                    end
                    local k = addk(tv)
                    advance()
                    emit(SELF, k, 0, 0)
                    parse_call_args(1)
                else
                    return
                end
            end
        end

        local function compile_primary()
            if tk == "number" or tk == "string" then
                local k = addk(tv)
                advance()
                emit(LOADK, k, 0, 0)
                clear_multi()
            elseif tk == "nil" then
                advance()
                emit(LOADNIL, 1, 0, 0)
                clear_multi()
            elseif tk == "true" then
                advance()
                emit(LOADBOOL, 1, 0, 0)
                clear_multi()
            elseif tk == "false" then
                advance()
                emit(LOADBOOL, 0, 0, 0)
                clear_multi()
            elseif tk == "..." then
                if not fc.isvararg then
                    fail("cannot use '...' outside a vararg function")
                end
                advance()
                local p = emit(VARARG, 1, 0, 0)
                set_multi(p)
            elseif tk == "function" then
                advance()
                local idx = compile_funcbody(false)
                emit(CLOSURE, idx, 0, 0)
                clear_multi()
            elseif tk == "{" then
                compile_table()
                clear_multi()
            elseif tk == "name" then
                local name = tv
                advance()
                local kind, ref = resolve_var(name)
                emit_var_get(kind, ref)
                compile_suffix()
            elseif tk == "(" then
                advance()
                compile_expr()
                expect(")")
                clear_multi()
                compile_suffix()
            else
                fail("expression expected")
            end
        end

        local compile_unary

        local function compile_pow()
            compile_primary()
            if tk == "^" then
                advance()
                compile_unary()
                emit(POW, 0, 0, 0)
                clear_multi()
            end
        end

        compile_unary = function()
            if tk == "-" then
                advance()
                compile_unary()
                emit(UNM, 0, 0, 0)
                clear_multi()
            elseif tk == "not" then
                advance()
                compile_unary()
                emit(NOT, 0, 0, 0)
                clear_multi()
            elseif tk == "#" then
                advance()
                compile_unary()
                emit(LEN, 0, 0, 0)
                clear_multi()
            else
                compile_pow()
            end
        end

        local function compile_mul()
            compile_unary()
            while tk == "*" or tk == "/" or tk == "%" do
                local op = tk
                advance()
                compile_unary()
                if op == "*" then
                    emit(MUL, 0, 0, 0)
                elseif op == "/" then
                    emit(DIV, 0, 0, 0)
                else
                    emit(MOD, 0, 0, 0)
                end
                clear_multi()
            end
        end

        local function compile_add()
            compile_mul()
            while tk == "+" or tk == "-" do
                local op = tk
                advance()
                compile_mul()
                if op == "+" then
                    emit(ADD, 0, 0, 0)
                else
                    emit(SUB, 0, 0, 0)
                end
                clear_multi()
            end
        end

        local function compile_concat()
            compile_add()
            if tk == ".." then
                advance()
                compile_concat()
                emit(CONCAT, 0, 0, 0)
                clear_multi()
            end
        end

        local function compile_compare()
            compile_concat()
            while tk == "==" or tk == "~=" or tk == "<" or tk == "<=" or
                  tk == ">" or tk == ">=" do
                local op = tk
                advance()
                compile_concat()
                if op == "==" then
                    emit(EQ, 0, 0, 0)
                elseif op == "~=" then
                    emit(NE, 0, 0, 0)
                elseif op == "<" then
                    emit(LT, 0, 0, 0)
                elseif op == "<=" then
                    emit(LE, 0, 0, 0)
                elseif op == ">" then
                    emit(GT, 0, 0, 0)
                else
                    emit(GE, 0, 0, 0)
                end
                clear_multi()
            end
        end

        local function compile_and()
            compile_compare()
            local jumps = nil
            while tk == "and" do
                local j = emit(TESTF, 0, 0, 0)
                if not jumps then
                    jumps = {}
                end
                jumps[#jumps + 1] = j
                advance()
                compile_compare()
            end
            if jumps then
                local target = here()
                for i = 1, #jumps do
                    patch_target(jumps[i], target)
                end
                clear_multi()
            end
        end

        local function compile_or()
            compile_and()
            local jumps = nil
            while tk == "or" do
                local j = emit(TESTT, 0, 0, 0)
                if not jumps then
                    jumps = {}
                end
                jumps[#jumps + 1] = j
                advance()
                compile_and()
            end
            if jumps then
                local target = here()
                for i = 1, #jumps do
                    patch_target(jumps[i], target)
                end
                clear_multi()
            end
        end

        compile_expr = function()
            clear_multi()
            compile_or()
        end

        -- ========================================================
        -- Table constructors
        -- ========================================================
        compile_table = function()
            local oldreg = fc.nextreg
            local treg = reserve_reg()
            local mreg = reserve_reg()
            emit(NEWTABLE, 0, 0, 0)
            emit(SETLOCAL, treg, 0, 0)

            expect("{")
            local idx = 0

            local function is_named_field()
                if tk ~= "name" then
                    return false
                end
                local sp = pos
                local stk = tk
                local stv = tv
                local stp = tp
                advance()
                local named = (tk == "=")
                pos = sp
                tk = stk
                tv = stv
                tp = stp
                return named
            end

            local function finish_separator()
                if tk == "," or tk == ";" then
                    advance()
                elseif tk ~= "}" then
                    fail("',' or '}' expected")
                end
            end

            while tk ~= "}" do
                if tk == "[" then
                    advance()
                    local keyold = fc.nextreg
                    local keyreg = reserve_reg()
                    compile_expr()
                    expect("]")
                    emit(SETLOCAL, keyreg, 0, 0)
                    expect("=")
                    compile_expr()
                    emit(SETINDEX, treg, keyreg, 0)
                    fc.nextreg = keyold
                    finish_separator()
                elseif is_named_field() then
                    local key = addk(tv)
                    advance()
                    expect("=")
                    compile_expr()
                    emit(SETFIELD, treg, key, 0)
                    finish_separator()
                else
                    emit(MARK, mreg, 0, 0)
                    compile_expr()
                    idx = idx + 1

                    local last = false
                    if tk == "}" then
                        last = true
                    elseif tk == "," or tk == ";" then
                        advance()
                        last = (tk == "}")
                    else
                        fail("',' or '}' expected")
                    end

                    if last then
                        if top_multi then
                            patch_nres(last_multi_pc, -1)
                            emit(SETLISTMULTI, treg, idx, mreg)
                        else
                            emit(SETLIST, treg, idx, 0)
                        end
                        break
                    else
                        emit(SETLIST, treg, idx, 0)
                    end
                end
            end

            expect("}")
            emit(GETLOCAL, treg, 0, 0)
            fc.nextreg = oldreg
            clear_multi()
        end

        -- ========================================================
        -- Functions
        -- ========================================================
        compile_funcbody = function(implicit_self)
            local parent_fc = fc
            local child = new_fc(parent_fc, false, 0)
            fc = child

            local params = {}
            expect("(")
            if implicit_self then
                local d = new_local("self")
                child.numparams = 1
                params[#params + 1] = d
            end

            local vararg = false
            if tk ~= ")" then
                while true do
                    if tk == "..." then
                        vararg = true
                        advance()
                        break
                    elseif tk == "name" then
                        local d = new_local(tv)
                        child.numparams = child.numparams + 1
                        params[#params + 1] = d
                        advance()
                    else
                        fail("parameter name or '...' expected")
                    end
                    if tk == "," then
                        advance()
                        if tk == ")" then
                            fail("parameter expected after ','")
                        end
                    else
                        break
                    end
                end
            end
            expect(")")
            child.isvararg = vararg

            for i = 1, #params do
                emit_cell(params[i])
            end

            parse_block("end")
            expect("end")
            emit(RET, 0, 0, 0)
            optimize_code(child.code, child.ncode)
            if child.ncode > limits.maxCodeSlots then
                error("code exceeds maxCodeSlots", 0)
            end

            local proto = {
                code = child.code,
                lines = child.lines,
                consts = child.consts,
                updesc = child.upvals,
                numparams = child.numparams,
                isvararg = child.isvararg,
                maxreg = child.maxreg,
                env = env,
                sourceName = sourceName,
                protos = all_protos,
                limits = limits,
            }
            all_protos[#all_protos + 1] = proto
            local idx = #all_protos

            fc = parent_fc
            return idx
        end

        -- ========================================================
        -- Expression lists
        -- ========================================================
        local function compile_exprlist_assign(n)
            clear_multi()
            local count = 0
            while true do
                compile_expr()
                count = count + 1
                if tk == "," then
                    advance()
                else
                    break
                end
            end

            if count <= n and top_multi then
                patch_nres(last_multi_pc, n - count + 1)
            elseif count < n then
                emit_loadnil(n - count)
            elseif count > n then
                emit_pop(count - n)
            end
            clear_multi()
        end

        local function compile_exprlist_all()
            clear_multi()
            local count = 0
            if tk == "eof" or tk == "end" or tk == "else" or
               tk == "elseif" or tk == "until" or tk == ";" then
                return 0
            end
            while true do
                compile_expr()
                count = count + 1
                if tk == "," then
                    advance()
                else
                    break
                end
            end
            if top_multi then
                local multi_pc = last_multi_pc
                patch_nres(multi_pc, -1)
                clear_multi()
                return -1, count, multi_pc
            end
            clear_multi()
            return count
        end

        -- ========================================================
        -- Statement-level expressions: assignment or call
        -- ========================================================
        local function make_field_target(base_reg, key)
            return { kind = "field", base = base_reg, key = key }
        end

        local function make_index_target(base_reg, key_reg)
            return { kind = "index", base = base_reg, key = key_reg }
        end

        local function parse_prefix_stmt()
            local final_call_pc = nil

            if tk == "name" then
                local name = tv
                advance()
                local kind, ref = resolve_var(name)
                if tk == "=" or tk == "," then
                    return "target", { kind = kind, ref = ref }
                end
                emit_var_get(kind, ref)
            elseif tk == "(" then
                advance()
                compile_expr()
                expect(")")
                clear_multi()
            else
                fail("statement expected")
            end

            while true do
                if tk == "." then
                    advance()
                    if tk ~= "name" then
                        fail("field name expected")
                    end
                    local key = addk(tv)
                    advance()
                    if tk == "=" or tk == "," then
                        local breg = reserve_reg()
                        emit(SETLOCAL, breg, 0, 0)
                        return "target", make_field_target(breg, key)
                    end
                    emit(FIELD, key, 0, 0)
                    clear_multi()
                    final_call_pc = nil
                elseif tk == "[" then
                    advance()
                    compile_expr()
                    expect("]")
                    if tk == "=" or tk == "," then
                        local breg = reserve_reg()
                        local kreg = reserve_reg()
                        emit(SETLOCAL, kreg, 0, 0)
                        emit(SETLOCAL, breg, 0, 0)
                        return "target", make_index_target(breg, kreg)
                    end
                    emit(INDEX, 0, 0, 0)
                    clear_multi()
                    final_call_pc = nil
                elseif tk == "(" or tk == "{" or tk == "string" then
                    final_call_pc = parse_call_args(0)
                elseif tk == ":" then
                    advance()
                    if tk ~= "name" then
                        fail("method name expected")
                    end
                    local key = addk(tv)
                    advance()
                    emit(SELF, key, 0, 0)
                    final_call_pc = parse_call_args(1)
                else
                    break
                end
            end

            if final_call_pc then
                return "call", final_call_pc
            end
            fail("function call expected")
        end

        local function emit_store_target(target)
            local k = target.kind
            if k == "local" then
                emit_local_set(target.ref)
            elseif k == "upval" then
                emit(SETUPVAL, target.ref, 0, 0)
            elseif k == "global" then
                emit(SETGLOBAL, target.ref, 0, 0)
            elseif k == "field" then
                emit(SETFIELD, target.base, target.key, 0)
            elseif k == "index" then
                emit(SETINDEX, target.base, target.key, 0)
            else
                error("bad lvalue", 0)
            end
        end

        local function parse_assignment_or_call()
            local oldreg = fc.nextreg
            local kind, data = parse_prefix_stmt()

            if kind == "call" then
                if tk == "=" or tk == "," then
                    fail("cannot assign to a function call")
                end
                patch_nres(data, 0)
                clear_multi()
                fc.nextreg = oldreg
                return
            end

            local targets = { data }
            while tk == "," do
                advance()
                local k2, d2 = parse_prefix_stmt()
                if k2 ~= "target" then
                    fail("variable expected")
                end
                targets[#targets + 1] = d2
            end

            expect("=")
            compile_exprlist_assign(#targets)
            for i = #targets, 1, -1 do
                emit_store_target(targets[i])
            end
            fc.nextreg = oldreg
            clear_multi()
        end

        -- ========================================================
        -- Blocks and statements
        -- ========================================================
        local function is_block_end()
            return tk == "eof" or tk == "end" or tk == "else" or
                   tk == "elseif" or tk == "until"
        end

        parse_block = function(stop1, stop2, stop3)
            while tk ~= "eof" and tk ~= stop1 and
                  (not stop2 or tk ~= stop2) and
                  (not stop3 or tk ~= stop3) do
                parse_stmt()
            end
        end

        local function parse_local()
            advance() -- local
            if tk == "function" then
                advance()
                if tk ~= "name" then
                    fail("local function name expected")
                end
                local desc = new_local(tv)
                advance()
                emit(LOADNIL, 1, 0, 0)
                emit(SETLOCAL, desc.slot, 0, 0)
                emit_cell(desc)
                local idx = compile_funcbody(false)
                emit(CLOSURE, idx, 0, 0)
                emit_local_set(desc)
                clear_multi()
                return
            end

            local names = {}
            local n = 0
            while true do
                if tk ~= "name" then
                    fail("local variable name expected")
                end
                n = n + 1
                names[n] = tv
                advance()
                if not accept(",") then
                    break
                end
            end

            local has_init = accept("=")
            if has_init then
                compile_exprlist_assign(n)
            else
                emit_loadnil(n)
            end

            local descs = {}
            for i = 1, n do
                descs[i] = new_local(names[i])
            end
            for i = n, 1, -1 do
                emit(SETLOCAL, descs[i].slot, 0, 0)
            end
            for i = 1, n do
                emit_cell(descs[i])
            end
        end

        local function parse_return()
            advance()
            local n, count, multi_pc = compile_exprlist_all()
            while accept(";") do end
            if not is_block_end() then
                fail("'end' expected after return")
            end
            if n == -1 and count == 1 and multi_pc and
               fc.code[multi_pc] == CALLD then
                -- Mark this CALLD as a tail call. The VM reuses the current
                -- frame for interpreted targets; native targets are called
                -- normally and fall through to the RET below.
                fc.code[multi_pc + 3] = 1
            end
            emit(RET, n, 0, 0)
        end

        local function parse_break()
            advance()
            if fc.loop_depth == 0 then
                fail("break outside loop")
            end
            while accept(";") do end
            if not is_block_end() then
                fail("'end' expected after break")
            end
            local j = emit(JMP, 0, 0, 0)
            local br = fc.loop_breaks[fc.loop_depth]
            br[#br + 1] = j
        end

        local function parse_while()
            advance()
            local start = here()
            compile_expr()
            expect("do")
            local jf = emit(JMPF, 0, 0, 0)
            local mn, mr = enter_scope()
            fc.loop_depth = fc.loop_depth + 1
            local br = {}
            fc.loop_breaks[fc.loop_depth] = br
            parse_block("end")
            fc.loop_breaks[fc.loop_depth] = nil
            fc.loop_depth = fc.loop_depth - 1
            leave_scope(mn, mr)
            emit(JMP, start, 0, 0)
            expect("end")
            local target = here()
            patch_target(jf, target)
            for i = 1, #br do
                patch_target(br[i], target)
            end
        end

        local function parse_repeat()
            advance()
            local start = here()
            local mn, mr = enter_scope()
            fc.loop_depth = fc.loop_depth + 1
            local br = {}
            fc.loop_breaks[fc.loop_depth] = br
            parse_block("until")
            expect("until")
            compile_expr()
            emit(JMPF, start, 0, 0)
            fc.loop_breaks[fc.loop_depth] = nil
            fc.loop_depth = fc.loop_depth - 1
            local target = here()
            for i = 1, #br do
                patch_target(br[i], target)
            end
            leave_scope(mn, mr)
        end

        local function parse_numeric_for(name)
            expect("=")
            local mn, mr = enter_scope()
            local ctrl = reserve_reg()
            local limit = reserve_reg()
            local step = reserve_reg()

            compile_expr()
            emit(SETLOCAL, ctrl, 0, 0)
            expect(",")
            compile_expr()
            emit(SETLOCAL, limit, 0, 0)
            if accept(",") then
                compile_expr()
            else
                emit(LOADK, addk(1), 0, 0)
            end
            emit(SETLOCAL, step, 0, 0)

            local desc = new_local(name)
            expect("do")
            local prep = emit(FORPREP, ctrl, 0, 0)
            local body = here()

            emit(GETLOCAL, ctrl, 0, 0)
            emit(SETLOCAL, desc.slot, 0, 0)
            emit_cell(desc)

            fc.loop_depth = fc.loop_depth + 1
            local br = {}
            fc.loop_breaks[fc.loop_depth] = br
            parse_block("end")
            fc.loop_breaks[fc.loop_depth] = nil
            fc.loop_depth = fc.loop_depth - 1
            expect("end")

            emit(FORLOOP, ctrl, body, 0)
            local target = here()
            patch_b(prep, target)
            for i = 1, #br do
                patch_target(br[i], target)
            end
            leave_scope(mn, mr)
        end

        local function parse_generic_for(names, nnames)
            expect("in")
            local mn, mr = enter_scope()
            local freg = reserve_reg()
            local sreg = reserve_reg()
            local creg = reserve_reg()

            compile_exprlist_assign(3)
            emit(SETLOCAL, creg, 0, 0)
            emit(SETLOCAL, sreg, 0, 0)
            emit(SETLOCAL, freg, 0, 0)

            local descs = {}
            for i = 1, nnames do
                descs[i] = new_local(names[i])
            end
            expect("do")

            local start = here()
            local mreg = reserve_reg()
            local preg = reserve_reg()

            emit(GETLOCAL, freg, 0, 0)
            emit(MARK, mreg, 0, 0)
            emit(GETLOCAL, sreg, 0, 0)
            emit(GETLOCAL, creg, 0, 0)
            emit(CALLD, mreg, nnames, 0)
            emit(PEEK, preg, nnames - 1, 0)
            for i = nnames, 1, -1 do
                emit(SETLOCAL, descs[i].slot, 0, 0)
                emit_cell(descs[i])
            end
            emit(GETLOCAL, preg, 0, 0)
            emit(SETLOCAL, creg, 0, 0)
            emit(GETLOCAL, creg, 0, 0)
            local jf = emit(JMPNIL, 0, 0, 0)

            fc.loop_depth = fc.loop_depth + 1
            local br = {}
            fc.loop_breaks[fc.loop_depth] = br
            parse_block("end")
            fc.loop_breaks[fc.loop_depth] = nil
            fc.loop_depth = fc.loop_depth - 1
            expect("end")

            emit(JMP, start, 0, 0)
            local target = here()
            patch_target(jf, target)
            for i = 1, #br do
                patch_target(br[i], target)
            end
            leave_scope(mn, mr)
        end

        local function parse_for()
            advance()
            if tk ~= "name" then
                fail("for variable name expected")
            end
            local first = tv
            advance()
            if tk == "=" then
                parse_numeric_for(first)
                return
            end

            local names = { first }
            local nnames = 1
            while tk == "," do
                advance()
                if tk ~= "name" then
                    fail("for variable name expected")
                end
                nnames = nnames + 1
                names[nnames] = tv
                advance()
            end
            parse_generic_for(names, nnames)
        end

        local function parse_if()
            advance()
            local endjumps = nil
            while true do
                compile_expr()
                expect("then")
                local jf = emit(JMPF, 0, 0, 0)
                local mn, mr = enter_scope()
                parse_block("end", "elseif", "else")
                leave_scope(mn, mr)

                if tk == "elseif" then
                    local j = emit(JMP, 0, 0, 0)
                    if not endjumps then endjumps = {} end
                    endjumps[#endjumps + 1] = j
                    patch_target(jf, here())
                    advance()
                elseif tk == "else" then
                    local j = emit(JMP, 0, 0, 0)
                    if not endjumps then endjumps = {} end
                    endjumps[#endjumps + 1] = j
                    patch_target(jf, here())
                    advance()
                    local mn2, mr2 = enter_scope()
                    parse_block("end")
                    leave_scope(mn2, mr2)
                    expect("end")
                    local target = here()
                    for i = 1, #endjumps do
                        patch_target(endjumps[i], target)
                    end
                    return
                else
                    expect("end")
                    local target = here()
                    patch_target(jf, target)
                    if endjumps then
                        for i = 1, #endjumps do
                            patch_target(endjumps[i], target)
                        end
                    end
                    return
                end
            end
        end

        local function parse_do()
            advance()
            local mn, mr = enter_scope()
            parse_block("end")
            expect("end")
            leave_scope(mn, mr)
        end

        local function parse_function_stmt()
            advance()
            if tk ~= "name" then
                fail("function name expected")
            end
            local oldreg = fc.nextreg
            local name = tv
            advance()
            local kind, ref = resolve_var(name)
            local target
            local method = false

            if tk == "." or tk == ":" then
                emit_var_get(kind, ref)
                while true do
                    if tk == "." then
                        advance()
                        if tk ~= "name" then
                            fail("field name expected")
                        end
                        local key = addk(tv)
                        advance()
                        if tk == "." or tk == ":" then
                            emit(FIELD, key, 0, 0)
                        elseif tk == "(" then
                            local breg = reserve_reg()
                            emit(SETLOCAL, breg, 0, 0)
                            target = make_field_target(breg, key)
                            break
                        else
                            fail("'(' expected")
                        end
                    elseif tk == ":" then
                        advance()
                        if tk ~= "name" then
                            fail("method name expected")
                        end
                        local key = addk(tv)
                        advance()
                        if tk ~= "(" then
                            fail("'(' expected")
                        end
                        local breg = reserve_reg()
                        emit(SETLOCAL, breg, 0, 0)
                        target = make_field_target(breg, key)
                        method = true
                        break
                    else
                        fail("'(' expected")
                    end
                end
            else
                target = { kind = kind, ref = ref }
            end

            local idx = compile_funcbody(method)
            emit(CLOSURE, idx, 0, 0)
            emit_store_target(target)
            fc.nextreg = oldreg
            clear_multi()
        end

        parse_stmt = function()
            if tk == ";" then
                advance()
                return
            elseif tk == "local" then
                parse_local()
            elseif tk == "function" then
                parse_function_stmt()
            elseif tk == "if" then
                parse_if()
            elseif tk == "while" then
                parse_while()
            elseif tk == "repeat" then
                parse_repeat()
            elseif tk == "for" then
                parse_for()
            elseif tk == "do" then
                parse_do()
            elseif tk == "break" then
                parse_break()
            elseif tk == "return" then
                parse_return()
            elseif tk == "name" or tk == "(" then
                parse_assignment_or_call()
            else
                fail("statement expected")
            end
        end

        fc = new_fc(nil, true, 0)
        advance()
        while tk ~= "eof" do
            parse_stmt()
        end
        emit(RET, 0, 0, 0)
        optimize_code(fc.code, fc.ncode)
        if fc.ncode > limits.maxCodeSlots then
            error("code exceeds maxCodeSlots", 0)
        end

        local proto = {
            code = fc.code,
            lines = fc.lines,
            consts = fc.consts,
            updesc = fc.upvals,
            numparams = 0,
            isvararg = true,
            maxreg = fc.maxreg,
            env = env,
            sourceName = sourceName,
            protos = all_protos,
            limits = limits,
        }
        all_protos[#all_protos + 1] = proto
        return proto
    end

    local ok, proto = pcall(compile)
    if not ok then
        return nil, tostring(proto)
    end
    return make_closure(proto, {}, env, true)
end

return custom_loadstring
