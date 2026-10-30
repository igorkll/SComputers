# GoogiVM Technical Guide

This document explains how **GoogiVM** (`custom_loadstring_full.lua`) compiles and executes Lua 5.1 source code. For public API usage and benchmarks, see [`README.md`](README.md).

---

## 1. Execution Pipeline

Everything lives in a single file (`custom_loadstring_full.lua`) with five logical stages:

```text
Lua 5.1 Source String
  -> 1. Streaming Lexer (`advance`, `read_number`, `read_string`)
  -> 2. Single-Pass Recursive-Descent Compiler (`parse_stmt`, `compile_expr`)
  -> 3. Per-Function Bytecode Prototype (`code`, `consts`, `updesc`, `lines`)
  -> 4. Peephole Superinstruction Optimizer (`optimize_code`)
  -> 5. Explicit-Frame Stack/Register Virtual Machine (`run_closure`)
```

There is no intermediate AST. Bytecode is emitted directly during parsing.

---

## 2. Lexer & Source Line Mapping

- The scanner maintains only the current token (`tk`), its semantic value (`tv`), its byte offset (`tp`), the previous token's byte offset (`last_tp`), and the cursor (`pos`).
- Before scanning, `compile()` builds an array of newline offsets (`line_starts`).
- Whenever `emit()` writes an instruction, it records `line_of(last_tp)` (via binary search over `line_starts`) into `fc.lines[pc]`.
- Number scanning validates adjacent dots (`1..2`, `0x1..2`) as syntax errors while allowing string concatenation (`1 .. 2`).

---

## 3. Compiler & Function Prototypes

Each function (including the top-level chunk, which is compiled as an implicit `...` vararg function) has a compilation context `fc`:

- `code` — flat 1-based numeric array; every base instruction occupies 4 numbers: `[OPCODE, A, B, C]`.
- `consts` / `cmap` — deduplicated constant pool (`K`).
- `locals` — active local variable descriptors (`name`, `slot`, `captured`, `cell_pc`, `access`).
- `upvals` — upvalue descriptors (`name`, `instack`, `idx`).
- `nextreg` / `maxreg` — frame-relative register allocator for locals and temporaries.
- `loop_breaks` — per-loop lists of pending `break` jump addresses to patch at loop exit.

### Upvalues and Heap-Cell Backpatching

Un-captured local variables live directly in frame registers `S[base + slot - 1]` and are read/written with `GETLOCAL`/`SETLOCAL`.

When a local variable is declared, the compiler emits a `NOP` placeholder (`cell_pc`) and records every `GETLOCAL`/`SETLOCAL` PC in `desc.access`. If an inner function captures that local:
1. `mark_captured(desc)` patches `co[desc.cell_pc]` from `NOP` to `CELL` (which wraps the register value in `{ v = value }`).
2. All previously emitted `GETLOCAL`/`SETLOCAL` instructions for that variable are backpatched to `GETCELL`/`SETCELL`, and future accesses emit `GETCELL`/`SETCELL` directly.
3. Both outer and inner closures share the same `{ v = value }` table cell.

---

## 4. Bytecode & Superinstructions (Opcodes 1–163)

### Base Opcodes (`1–51`)

| Range | Opcodes | Purpose |
|---:|---|---|
| `1–3` | `LOADK`, `LOADBOOL`, `LOADNIL` | Push constants, booleans, and `nil`s |
| `4–8` | `GETLOCAL`, `SETLOCAL`, `GETCELL`, `SETCELL`, `CELL` | Local register and captured-cell access |
| `9–12` | `GETUPVAL`, `SETUPVAL`, `GETGLOBAL`, `SETGLOBAL` | Upvalues and `env` table globals |
| `13–22` | `ADD`..`POW`, `CONCAT`, `UNM`, `NOT`, `LEN` | Arithmetic, string concat, and unary operators |
| `23–28` | `EQ`, `NE`, `LT`, `LE`, `GT`, `GE` | Relational operators |
| `29–32`, `51` | `TESTF`, `TESTT`, `JMPF`, `JMP`, `JMPNIL` | Short-circuit logical tests and jumps |
| `33–35` | `CALLD`, `RET`, `VARARG` | Function calls (including tail calls), returns, and `...` |
| `36–43` | `NEWTABLE`, `FIELD`, `INDEX`, `SETFIELD`, `SETINDEX`, `SELF`, `SETLIST`, `SETLISTMULTI` | Table creation, reads, writes, methods, and array initializers |
| `44–50` | `MARK`, `POP`, `FORPREP`, `FORLOOP`, `CLOSURE`, `PEEK`, `NOP` | Multi-return markers, numeric `for`, closures, and stack helpers |

### Fused Superinstructions (`52–163`)

`optimize_code(co, n)` runs after a function is compiled. **It never shifts instruction addresses:** it overwrites the first instruction of a matched pattern and marks the remaining `len - 1` instruction slots in `dead[]`. The VM advances `pc` by `4 * len` (e.g., `+8`, `+12`, `+16`, `+20`, `+24`, `+32`, `+36`, `+40`, `+48`, `+56`, `+72`, or `+96`).

A fusion is only applied if `can(pos, len)` confirms that none of the interior slots is a jump target (`targets[]`) or already dead. `can_tail(pos, len)` relaxes this for the last slot only: it may stay a jump target because the instruction itself remains physically present and valid, while the fall-through path skips it.

Several opcode families share one opcode and carry a **kind** in a dead slot (`C[pc + 4]`):

| Range | Superinstructions | What They Fuse |
|---:|---|---|
| `52–57` | `MOVLOCAL`, `MOVLOCAL_NOP`, `MOVLOCAL_CELL`, `SETLOCAL_K`, `SETLOCAL_INDEX`, `SETLOCAL_FIELD` | Direct local-to-local moves, constant stores, and `dest = t[k]` / `dest = t.field` without stack push/pop |
| `58–87` | `ADD_RR`/`RK` .. `POW_RR`/`RK`, `EQ_RR`/`RK` .. `GE_RR`/`RK`, `EQ_K` .. `GE_K` | Binary arithmetic and comparisons directly from local registers and constants |
| `88–94` | `INDEX_RR`, `INDEX_RK`, `FIELD_R`, `SETINDEX_RR`, `SETINDEX_RK`, `SETFIELD_RV`, `SETFIELD_RK` | Single-dispatch table reads and writes (`t[k] = v`, `t.f = v`) |
| `102–103` | `JMPF_LOCAL`, `JMPNIL_LOCAL` | Zero-stack local tests |
| `110–119`, `142`, `145–146` | `FORLOOP_MOV`, `FORLOOP_CELL`, `FORLOOP_ADD_RR`/`RK`/`INDEX`, `FORLOOP_SETINDEX_RR`/`RK`, `FORLOOP_SUB_RR`/`RK`, `JMPF_MOD_EQ_K`, `JMPF_MOD_RR_EQ_K`, `FORLOOP_MOD_RR_EQ_K`, `FORLOOP_NEWTABLE_SETINDEX_R` | Numeric `for` step fused with loop-variable copy and the first loop-body statement/branch, plus `x % d == k` branches |
| `132–133` | `TFOR_2`, `TFOR_1` | Full generic `for` header fused into 1 dispatch; runs `ipairs` and `pairs`/`next` directly in-VM without per-iteration function call overhead |
| `134–141` | `NEWTABLE_LOCAL`, `SETLIST_R`, `SETLIST_K`, `SETLIST_ADD_RK`, `NEWTABLE_FIELD_R`/`K`, `NEWTABLE_SETINDEX_R`, `NEWTABLE_LIST3_ADD_RK` | Fast table allocation and inline array/hash constructor population |
| `143–144` | `ADD_ASSIGN_BINOP_RR`, `SETLOCAL_BOOL` | In-place update with an in-VM `__add` frame push; `dest = true/false` |
| `147–150` | `TESTF_CMP_RR`/`RK`, `TESTT_CMP_RR`/`RK` | Comparison fused with the short-circuit test of `and`/`or`; the comparison kind (23–28) rides in the dead slot |
| `151–153` | `JMPF_CMP_RR`, `JMPF_CMP_RK`, `JMPF_CMP_K` | Comparison fused with `JMPF` for `if`/`while`/`until`; the kind replaces 18 separate opcodes |
| `154–156` | `ASSIGN_RR`, `ASSIGN_RK`, `ASSIGN_INDEX` | Compound assignment for all seven arithmetic operators; the operator (ADD=13 .. CONCAT=19) rides in the dead slot, replacing 7 separate opcodes |
| `157` | `SWAP` | `a, b = b, a` |
| `158–159` | `ASSIGN_MOD_ADD_RK`, `SETINDEX_MOD_RK` | `s = (s + i) % k` and `t[i % k] = v` |
| `160–161` | `CLOSURE_CELL`, `SETINDEX_CLOSURE_CELL` | Per-iteration boxed loop variable plus closure creation, and `t[i] = function() return i end` |
| `162–163` | `FORLOOP_ASSIGN_RR`, `FORLOOP_ASSIGN_RK` | Numeric `for` step fused with a loop-body assignment for `*`, `/`, `%`, `^` and `..`; the operator rides in the dead slot (`13`–`19` encoding) |

Ranges `95–101`, `104–109` and `120–131` are retired: they were folded into `ASSIGN_*` (154–156) and `JMPF_CMP_*` (151–153).

---

## 5. Virtual Machine (`run_closure`)

- **Shared Stack (`S`) & Explicit Frames (`frames`):**
  All active interpreted functions share a single Lua table `S`. Frame `fi` has its local registers at `S[base .. base + maxreg - 1]` and its expression stack above `base + maxreg - 1`.
- **Frame Pooling (`free_frames`):**
  Returning from an interpreted call recycles the frame table into `free_frames` (up to 64 entries), eliminating table allocations on hot call paths (`fib`, recursion, closures).
- **Tail-Call Optimization (`CALLD` with `C = 1`):**
  `parse_return` marks `return f(...)` calls with `C = 1`. When `f` is an interpreted closure, `CALLD` overwrites `cur` in place and jumps to `pc = 1` without growing `fi` or consuming `maxCallDepth`.
- **Balanced Dispatch Tree:**
  `run_closure` does not walk a linear `if/elseif` opcode chain. Both the base chain (1–51) and the fused chain (52–161) are generated as balanced range trees over the opcode number, with leaves of at most four exact comparisons. A hot instruction such as `ASSIGN_RK` or `JMPF_CMP_RK` is reached in about seven `op <` tests instead of sixty to ninety `elseif` tests, which keeps LuaJIT side traces short. Adding an opcode only lengthens one leaf.
- **Fast Callback Entry (`info.fast`):**
  Root chunks wrap `run_closure` in `pcall` to format runtime errors with `format_runtime_error(err, trace)`. Inner closures (such as `__add` metamethods or `table.sort` comparators) set `info.fast = true` and invoke `run_closure` directly when called from the host.

### 5.1 Error reporting, guest `pcall`, and sandbox hygiene

`format_runtime_error(err, trace)` builds `<sourceName>:<line>: <message>` and
appends one `at <sourceName>:<line>` line per interpreted frame.

Two details keep host information out of the sandbox:

1. Host operator errors arrive with a host prefix such as
   `C:\mods\vm.lua:1771: attempt to perform arithmetic on a nil value`. The
   prefix is stripped with a greedy-safe pattern (`^.-:%d+: ([^\n]*)`) so both
   POSIX and Windows paths are removed before the sandbox location is added.
2. `pcall`/`xpcall` are special-cased in `CALLD`. When the first argument is an
   interpreted closure, the VM runs the target through `run_closure` under a
   fresh trace instead of letting the host `pcall` capture a raw error. The
   guest therefore sees `<string>:1: attempt to perform arithmetic ...` inside
   `pcall`, with no `custom_loadstring_full.lua:NNNN` in the message.

### 5.2 Tail-call stack reuse

A tail call reuses the current frame **and** relocates the function plus its
arguments down to the frame's original `base` before rebinding `p`, `C`, `K`,
`base`, and `top`. Without that relocation the base drifted upward on every
iteration, so a 600k-iteration tail-recursive loop eventually tripped
`maxStack`. With relocation the stack footprint is constant, and
`tests/test_tailcalls.lua` covers 600,000 iterations under the default
`maxStack` and `maxCallDepth = 10`.
- **LuaJIT 2.1 Comparison Workaround:**
  LuaJIT 2.1 has an upstream JIT compiler bug that can intermittently miscompile ordered relational comparisons inside large dispatch functions. GoogiVM isolates ordered comparisons in a small `compare_op` helper marked with `jit.off(compare_op)` when `jit` is present, while keeping equality/inequality fusions and arithmetic loops fully JIT-compiled.

---

## 6. Host-dependent semantics

GoogiVM implements the Lua 5.1 language itself; the following behaviors are
inherited from the host and are intentionally not emulated:

| Area | Where it comes from |
|---|---|
| `#` on tables with holes | `luaH_getn` of the host; not "highest integer key". |
| `__len` on tables | Only if the host honors it (LuaJIT, Lua 5.2+); plain Lua 5.1 ignores it. |
| `getfenv` / `setfenv` | Host availability. Interpreted closures and numeric levels are supported; `setfenv(0, ...)` and native function environments are rejected. |
| Number formatting | Host `tostring`. |
| Operator error text | Host message body; only the location prefix is rewritten. |
| Standard libraries | Whatever the embedder supplies in `env`. |
| Metamethod dispatch | Host operators (`__eq`, `__lt`, `__le`, `__concat`, `__len`, ...). |
| Restricted sandboxes | Missing `setmetatable`/`getmetatable`/`rawget`/`rawset` are tolerated; the VM uses only the helpers it needs (`getmetatable` is optional). |

These are documented in [`README.md`](README.md) so that "Lua 5.1 compatible"
is not read as "host-independent standard library".
