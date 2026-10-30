# Test Suite (`tests/`)

This directory contains the automated verification suite for **GoogiVM** (`custom_loadstring_full.lua`).

## Running the Tests

From the repository root:

```bash
luajit run_all_tests.lua
lua run_all_tests.lua
```

- **LuaJIT 2.1.1720049189 (primary target):** `18,711 checks, 0 failed`
- **Lua 5.4.6 (compatibility target):** `18,687 checks, 0 failed` (24 checks that depend on Lua 5.1 `getfenv`/`setfenv` or LuaJIT `__len` table semantics are skipped automatically when those features are absent).

Of the 18,711 LuaJIT checks, **18,000 (96.3%) are differential fuzz
generations** from `test_fuzz.lua` (15,000 expressions + 3,000 programs); the
remaining ~705 are hand-written assertions across the other 16 modules. The
headline number therefore measures fuzz volume, not 18k independent claims
about behaviour.

---

## Test Modules (17 Suites)

| Module | Checks (LuaJIT) | Coverage |
|---|---:|---|
| `test_lexer.lua` | 77 | Decimal/hex/scientific numbers, malformed numbers (`1..2`, `0x1..2`), short/long strings, escapes, comments, operators, line tracking |
| `test_syntax.lua` | 154 | Valid and invalid Lua 5.1 grammar, rejection of Lua 5.2+ features (`goto`, `::label::`, `//`) |
| `test_expressions.lua` | 83 | Arithmetic, relational, logical short-circuit (`and`/`or`), concatenation, unary ops, precedence |
| `test_statements.lua` | 53 | Locals, globals, multiple assignment, `if`/`elseif`/`else`, `while`, `repeat`/`until`, numeric & generic `for`, `break`, `do`, `return` |
| `test_functions.lua` | 30 | Parameters, recursion, closures, mutable shared upvalues, method definitions & calls (`:`) |
| `test_tables.lua` | 41 | List, hash, and mixed table constructors, nested tables, multi-return tail expansion (`{1, f()}`) |
| `test_varargs_multiret.lua` | 47 | `...`, `select`, multi-return adjustment, `(f())` truncation, varargs in calls/returns/tables |
| `test_metatables.lua` | 23 | `__index`, `__newindex`, `__add`..`__pow`, `__unm`, `__concat`, `__eq`, `__lt`, `__le`, `__call`, `__len`, `__tostring` |
| `test_environment.lua` | 28 | Sandbox isolation, empty default `env`, `env` metatables, `getfenv`/`setfenv` across stack levels and closures |
| `test_errors.lua` | 57 | API argument validation, syntax errors with line numbers, runtime error propagation through `pcall`/`xpcall`, sandbox-formatted errors caught by guest `pcall` (no host paths) |
| `test_host_interop.lua` | 17 | Interop with host `pcall`, `table.sort`, `string.gsub`, `coroutine.create`/`resume`/`wrap`, and C callbacks |
| `test_regressions.lua` | 18 | Edge cases: `false` iterator keys, per-iteration captured loop cells, upvalue backpatching, evaluation order, 100 upvalues |
| `test_superinstructions.lua` | 24 | Peephole fusions: arithmetic/compound assignments, table reads/writes, `while`/`for` branches, `ipairs` cells, metamethod preservation |
| `test_fuzz.lua` | 18,000 | Differential fuzzing against native `loadstring`/`load`: 15,000 random expressions + 3,000 random multi-statement programs |
| `test_stress.lua` | 14 | 5,000-deep recursion, 150 locals, 1,000-element table constructors, 120 parameters, 100 return values, 100 KB strings |
| `test_limits.lua` | 24 | `maxSourceBytes`, `maxCodeSlots`, `maxInstructions`, `maxCallDepth`, `maxStack`, `maxArgs`, `maxReturns`, native `getfenv`/`setfenv` rejection, source-line tracebacks |
| `test_tailcalls.lua` | 21 | Frame-reusing tail calls (`return f(...)`), 600,000-step tail recursion under `maxCallDepth = 10` and the default `maxStack` (constant stack footprint), argument-order preservation, vararg/method/native tail calls |
| **Total** | **18,711** | **All modules pass with 0 failures** |
