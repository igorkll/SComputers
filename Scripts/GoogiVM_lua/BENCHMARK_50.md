# 50 head-to-head benchmarks: GoogiVM vs FiOne vs LuaJIT native

Date: 2026-10-29
Host: Lua 5.1 (LuaJIT 2.1.1720049189)
Owner: current `custom_loadstring_full.lua`
FiOne: `SovereignSatellite/FiOne` @ `18cf0113dcef568b6b679096e372c7bbf7ac6d27`
Bytecode compiler for FiOne: `luac5.1` (Lua 5.1.5)

## Methodology

- 50 distinct Lua 5.1 workloads; each was run on all three engines.
- All engines received the same source and the same standard-library environment.
- Timed region is execution only: FiOne bytecode loading and GoogiVM compilation are outside the timer.
- Per run: 3 warm-up iterations, 7 measured iterations; JIT traces are flushed before each engine/case measurement.
- Every number in this report is the **mean of 3 consecutive full runs** of the suite on the same machine.
- `reps` and `result` are taken from the first run; they are identical across runs.
- `bench50_actual.lua` also writes an untracked `BENCHMARK_50_raw.csv` with every individual sample of a single run.
- Native LuaJIT is a reference baseline, not a pure-Lua competitor.

## Results

| # | Case | GoogiVM (s) | FiOne (s) | LuaJIT native (s) | FiOne / GoogiVM | Native / GoogiVM | Reps O/F/N | Result |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 1 | `loop_sum_100k` | 0.001521 | 0.003458 | 0.000083 | 2.27x | 0.05x | 16/8/256 | `5000050000` |
| 2 | `loop_sum_1m` | 0.014333 | 0.033667 | 0.000812 | 2.35x | 0.06x | 2/1/32 | `500000500000` |
| 3 | `loop_add_const_1m` | 0.014667 | 0.031000 | 0.000812 | 2.11x | 0.06x | 2/1/32 | `2000000` |
| 4 | `loop_sub_1m` | 0.014667 | 0.032333 | 0.000812 | 2.20x | 0.06x | 2/1/32 | `-1000000` |
| 5 | `loop_mul_100k` | 0.001708 | 0.003167 | 0.000164 | 1.85x | 0.10x | 16/8/128 | `1.1051708628081` |
| 6 | `loop_mod_100k` | 0.003250 | 0.005083 | 0.001250 | 1.56x | 0.38x | 8/4/16 | `1` |
| 7 | `nested_loop_100x100` | 0.000161 | 0.000333 | 0.000008 | 2.06x | 0.05x | 128/64/4096 | `10000` |
| 8 | `while_sum_100k` | 0.005667 | 0.006083 | 0.000082 | 1.07x | 0.01x | 4/4/256 | `5000050000` |
| 9 | `repeat_sum_100k` | 0.004792 | 0.005208 | 0.000082 | 1.09x | 0.02x | 8/4/256 | `5000050000` |
| 10 | `loop_break_100k` | 0.002500 | 0.002833 | 0.000041 | 1.13x | 0.02x | 8/8/512 | `1249975000` |
| 11 | `branch_if_1m` | 0.058333 | 0.074667 | 0.003917 | 1.28x | 0.07x | 1/1/8 | `250000000000` |
| 12 | `branch_and_or_100k` | 0.008750 | 0.008333 | 0.000750 | 0.95x | 0.09x | 4/4/32 | `99949` |
| 13 | `branch_mod3_100k` | 0.007417 | 0.010500 | 0.000578 | 1.42x | 0.08x | 4/2/64 | `1666716665` |
| 14 | `branch_nested_100k` | 0.007333 | 0.008833 | 0.000562 | 1.20x | 0.08x | 4/4/64 | `25000` |
| 15 | `calls_simple_1m` | 0.217000 | 1.218667 | 0.000812 | 5.62x | 0.00x | 1/1/32 | `1000000` |
| 16 | `calls_twoarg_1m` | 0.242667 | 1.288667 | 0.000812 | 5.31x | 0.00x | 1/1/32 | `1000000` |
| 17 | `calls_threearg_500k` | 0.148000 | 0.730667 | 0.000812 | 4.94x | 0.01x | 1/1/32 | `1500000` |
| 18 | `recursion_fib_20` | 0.004708 | 0.032000 | 0.000234 | 6.80x | 0.05x | 8/1/128 | `6765` |
| 19 | `recursion_fact_10` | 0.000017 | 0.000016 | 0.000000 | 0.92x | 0.01x | 2048/2048/8192 | `3628800` |
| 20 | `mutual_recursion_1000` | 0.000141 | 0.001625 | 0.000012 | 11.56x | 0.09x | 256/16/2048 | `true` |
| 21 | `tail_recursion_1000` | 0.000164 | 0.001208 | 0.000013 | 7.37x | 0.08x | 256/4/2048 | `500500` |
| 22 | `closures_create_100k` | 0.133000 | 0.093667 | 0.009333 | 0.70x | 0.07x | 1/1/2 | `100000` |
| 23 | `closure_upvalue_1m` | 0.243000 | 1.688667 | 0.000812 | 6.95x | 0.00x | 1/1/32 | `1000000` |
| 24 | `closure_factory_100k` | 0.140000 | 0.464333 | 0.010833 | 3.32x | 0.08x | 1/1/2 | `5000150000` |
| 25 | `closure_loop_capture_100k` | 0.119667 | 0.061000 | 0.009208 | 0.51x | 0.08x | 1/1/1 | `100000` |
| 26 | `table_write_200k` | 0.004375 | 0.008417 | 0.000932 | 1.92x | 0.21x | 8/4/32 | `200000` |
| 27 | `table_read_200k` | 0.010500 | 0.019667 | 0.001125 | 1.87x | 0.11x | 2/2/32 | `20000100000` |
| 28 | `table_mixed_100k` | 0.005417 | 0.008583 | 0.000526 | 1.58x | 0.10x | 4/4/64 | `5000050000` |
| 29 | `table_string_keys_50k` | 0.001896 | 0.003167 | 0.000139 | 1.67x | 0.07x | 16/8/128 | `4945050` |
| 30 | `table_constructor_100k` | 0.028000 | 0.038000 | 0.000082 | 1.36x | 0.00x | 1/1/256 | `5000050000` |
| 31 | `table_nested_50k` | 0.007833 | 0.010000 | 0.005167 | 1.28x | 0.66x | 2/1/8 | `1250025000` |
| 32 | `ipairs_100k` | 0.006667 | 0.025667 | 0.000380 | 3.85x | 0.06x | 4/1/64 | `5000050000` |
| 33 | `pairs_20k` | 0.001417 | 0.004333 | 0.000115 | 3.06x | 0.08x | 16/2/256 | `200010000` |
| 34 | `generic_next_100k` | 0.031000 | 0.047000 | 0.001479 | 1.52x | 0.05x | 1/1/16 | `5000050000` |
| 35 | `generic_ipairs_50k` | 0.003333 | 0.010833 | 0.000180 | 3.25x | 0.05x | 8/2/128 | `1250025000` |
| 36 | `string_concat_10k` | 0.022333 | 0.027667 | 0.023500 | 1.24x | 1.05x | 1/1/2 | `10000` |
| 37 | `string_sub_50k` | 0.012667 | 0.015000 | 0.000041 | 1.18x | 0.00x | 2/2/512 | `150000` |
| 38 | `string_byte_100k` | 0.015167 | 0.024667 | 0.000081 | 1.63x | 0.01x | 2/1/256 | `9700000` |
| 39 | `string_format_50k` | 0.012333 | 0.020333 | 0.004583 | 1.65x | 0.37x | 2/2/8 | `238894` |
| 40 | `string_gsub_10k` | 0.003500 | 0.004500 | 0.001260 | 1.29x | 0.36x | 8/8/32 | `30000` |
| 41 | `math_sqrt_100k` | 0.014500 | 0.024333 | 0.000719 | 1.68x | 0.05x | 2/1/32 | `21082008.973918` |
| 42 | `math_sin_100k` | 0.015667 | 0.026333 | 0.000812 | 1.68x | 0.05x | 2/1/32 | `1.8477771036304` |
| 43 | `math_floor_100k` | 0.015500 | 0.024667 | 0.000164 | 1.59x | 0.01x | 2/1/128 | `1666650000` |
| 44 | `varargs_count_100k` | 0.077333 | 0.204333 | 0.000082 | 2.64x | 0.00x | 1/1/256 | `200000` |
| 45 | `varargs_sum_100k` | 0.042333 | 0.205000 | 0.000104 | 4.84x | 0.00x | 1/1/256 | `10000200000` |
| 46 | `multiret_100k` | 0.039333 | 0.181667 | 0.000242 | 4.62x | 0.01x | 1/1/128 | `15000450000` |
| 47 | `multi_assign_100k` | 0.005750 | 0.007917 | 0.000082 | 1.38x | 0.01x | 4/4/256 | `300000` |
| 48 | `method_call_100k` | 0.034333 | 0.177333 | 0.000082 | 5.17x | 0.00x | 1/1/256 | `100000` |
| 49 | `metatable_add_100k` | 0.022667 | 0.173000 | 0.000082 | 7.63x | 0.00x | 1/1/256 | `300000` |
| 50 | `prime_count_10k` | 0.008417 | 0.013833 | 0.000401 | 1.64x | 0.05x | 4/2/64 | `1229` |

## Aggregate (mean execution times)

- Cases: **50** (failures: 0).
- GoogiVM faster than FiOne (>5%): **46**; slower (<-5%): **3**; within 5%: **1**.
- Geometric mean FiOne/GoogiVM speed ratio: **2.14x**.
- Sum of means: GoogiVM **1.8357 s**, FiOne **7.1123 s** (**3.87x**).

## Limitations

- These are 50 project-local microbenchmarks, not a standardized suite.
- Execution only: FiOne bytecode compilation and GoogiVM compilation are excluded.
- FiOne is a Lua 5.1 bytecode interpreter; it needs an external Lua 5.1 compiler.
- LuaJIT native uses `loadstring` and JIT; it is not a pure-Lua competitor.
- Single machine; absolute seconds drift with host load, so the ratios are the stable metric.
- Averaging 3 runs smooths per-run noise but is not a statistically rigorous treatment.
