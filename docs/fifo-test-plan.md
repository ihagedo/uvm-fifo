# `socetlib_fifo` test plan

| | |
|---|---|
| RTL | `rtl/socetlib_fifo.sv` |
| Spec | `fifo-spec.md` version 1.1 |
| CSV | `fifo-test-plan.csv`: configurations, test items, coverage and assertions, one row each |

## 1. Scope

In scope: `socetlib_fifo`, requirements R01–R16.

| Out of scope | Covered by |
|---|---|
| Clock-domain crossing | `cdc-fifo` |
| Timing, area, gate level | Synthesis and STA |

## 2. Configurations

| Config | Parameters | Why |
|---|---|---|
| C1 | `SIZE`=8, `DEPTH`=8 | Defaults |
| C2 | `SIZE`=32, `DEPTH`=32 | Wide |
| C3 | `SIZE`=1, `DEPTH`=2 | Smallest legal |
| C4 | `SIZE`=8, `DEPTH`=16 | `SIZE` ≠ `DEPTH` |
| C5 | `SIZE`=8, `DEPTH`=1 | Smallest depth |

## 3. Testbench architecture

```
fifo_test
 └─ fifo_env
     ├─ fifo_agent: sequencer → driver → DUT → monitor
     ├─ fifo_predictor → fifo_scoreboard
     └─ fifo_coverage
fifo_sva bound to the DUT
```

## 4. Test items

| ID | Req | Scenario | Expected | Test | Status |
|---|---|---|---|---|---|
| T01 | R01–R03 R05 | Write one word, pop it | Word on `rdata`; `empty`, `count` correct | `fifo_smoke_test` | Passing |
| T02 | R01 R05 | Fill, then drain | `full` after `DEPTH` writes; data in order | `fifo_fill_drain_test` | Passing |
| T03 | R04 | Idle cycles at several occupancies | Outputs stable | `fifo_smoke_test` | Passing |
| T04 | R10 | `WEN` + `REN` at every partial occupancy | `count` unchanged; data in order | `fifo_boundary_test` | Passing |
| T05 | R16 | Inputs toggle mid-cycle | Outputs change only at edges | `fifo_glitch_test` | Passing |
| T06 | R06 | Write while full | Dropped; `overrun` set | `fifo_flags_test` | Passing |
| T07 | R07 | Read while empty | `underrun` set; nothing else changes | `fifo_flags_test` | Passing |
| T08 | R08 | `WEN` + `REN` while full | No write, no pop; `overrun` set | `fifo_boundary_test` | Passing |
| T09 | R09 | `WEN` + `REN` while empty | No write, no pop; `underrun` set | `fifo_boundary_test` | Passing |
| T10 | R05 | Every operation at 0, 1, `DEPTH`−1, `DEPTH` | Matches model | `fifo_boundary_test` | Passing |
| T11 | R11 | Traffic after `overrun` | Flag stays set; data correct | `fifo_flags_test` | Passing |
| T12 | R11 | Both flags set | Both stay set until `clear` | `fifo_flags_test` | Passing |
| T13 | R12 | `clear` at several occupancies with each `WEN`/`REN` | Empty, flags clear, no write | `fifo_clear_reset_test` | Passing |
| T14 | R12 | `clear` with both flags set | Flags clear | `fifo_clear_reset_test` | Passing |
| T15 | R13 | `nRST` mid-cycle during traffic | Immediately empty, `rdata` = 0 | `fifo_clear_reset_test` | Passing |
| T16 | R15 | Many fill/drain rounds | Order correct across wraparound | `fifo_fill_drain_test` | Passing |
| T17 | all | Biased random traffic | No mismatches | `fifo_random_test` | Passing |
| T18 | R14 | T01–T17 in C1–C5 | Same results | `make regress` | Passing |
| T19 | R14 | `DEPTH` = 6 and 0 | Elaboration stops | `regress.py` | Passing |
| T20 | R14 | `DEPTH` = 1 | Same results as C1 | `make regress` (C5) | Passing |
| T21 | R01 | Data patterns: 0s, 1s, `0101…`, `1010…`, walking 1 | Patterns come out exactly | `fifo_fill_drain_test` | Passing |

## 5. Coverage

| Covergroup | Bins | Rows |
|---|---|---|
| `cg_ops::occ_x_op` | Occupancy (empty, one, mid, almost full, full) × operation (idle, write, read, both) | T04, T06–T10, T17 |
| `cg_clear::clear_x_occ_x_op` | Occupancy × operation, when `clear` = 1 | T13 |
| `cg_flags` | Each flag rising, both set, cleared by `clear`, cleared by `nRST` | T06, T07, T11–T15 |
| `cg_data` | 0s, 1s, `0101…`, `1010…`, other | T21 |
| `C_WRAP` | Write at the last slot | T16 |

Code coverage target: 100% line, branch, expression and port toggle. At `DEPTH` = 1, points that need a FIFO neither empty nor full do not apply.

### 5.1 Covergroup definitions

The covergroups are in `environment/fifo_coverage.svh`. They sample the monitor's observation at each rising edge, where `occ` is `count` before the edge and `op` is {`REN`, `WEN`}. Goal: every bin hit at least once in every configuration.

**`cg_ops`**: every edge with `nRST` = 1 and `clear` = 0.

| Item | Bins |
|---|---|
| `cp_occ` | `EMPTY` 0; `ONE` 1; `MID` 2 to `DEPTH`−2; `ALMOST_FULL` `DEPTH`−1; `FULL` `DEPTH` |
| `cp_op` | `IDLE` neither; `WRITE` `WEN` only; `READ` `REN` only; `BOTH` `WEN` and `REN` |
| `occ_x_op` | `cp_occ` × `cp_op` |

**`cg_clear`**: every edge with `nRST` = 1 and `clear` = 1.

| Item | Bins |
|---|---|
| `cp_occ` | `EMPTY` 0; `MID` 1 to `DEPTH`−1; `FULL` `DEPTH` |
| `cp_op` | As in `cg_ops` |
| `clear_x_occ_x_op` | `cp_occ` × `cp_op` |

**`cg_flags`**: each flag event, found by comparing an edge with the one before.

| Item | Bins |
|---|---|
| `cp_evt` | `OVERRUN_RISE` `overrun` 0 → 1; `UNDERRUN_RISE` `underrun` 0 → 1; `BOTH_SET` both flags set, not both set before; `CLEARED_BY_CLEAR` `clear` = 1 at the previous edge with a flag set; `CLEARED_BY_RESET` `nRST` falls with a flag set |

**`cg_data`**: every edge with `nRST` = 1 and `WEN` = 1, `clear` or not.

| Item | Bins |
|---|---|
| `cp_wdata` | `ZEROS` all 0s; `ONES` all 1s; `H55` `0101…`; `HAA` `1010…`; `OTHER` any other value |

**`C_WRAP`**: a cover property in `environment/fifo_sva.sv` for a write into the last slot: `WEN`, no `clear`, not full, not (empty with `REN`), and `write_ptr` = `DEPTH`−1. Goal: at least 2 hits per configuration.

## 6. Assertions

| ID | Property | Spec rule |
|---|---|---|
| SVA01 | `count <= DEPTH` | R05 |
| SVA02 | `full` and `empty` match `count` | R05 |
| SVA03 | Idle cycle keeps `rdata` and `count` stable | R04 |
| SVA04 | `overrun` rises only after a write while full | R06 |
| SVA05 | `underrun` rises only after a read while empty | R07 |
| SVA06 | Flags stay set until `clear` | R11 |
| SVA07 | `clear` empties the FIFO and clears flags | R12 |
| SVA08 | Full + `WEN` + `REN`: stays full, `rdata` stable | R08 |
| SVA09 | Empty + `WEN` + `REN`: stays empty | R09 |
| SVA10 | Inputs are never X | AS3 |

## 7. Traceability

| Requirement | Tests | Coverage | Assertions |
|---|---|---|---|
| R01 | T01 T02 T16 T17 T21 | `cg_data` | — |
| R02 | T01 T02 T13 | `occ_x_op` | — |
| R03 | T01 T02 | `occ_x_op` | — |
| R04 | T03 | — | SVA03 |
| R05 | T01 T02 T10 | `occ_x_op` | SVA01 SVA02 |
| R06 | T06 | `occ_x_op` | SVA04 |
| R07 | T07 | `occ_x_op` | SVA05 |
| R08 | T08 | `occ_x_op` | SVA08 |
| R09 | T09 | `occ_x_op` | SVA09 |
| R10 | T04 | `occ_x_op` | — |
| R11 | T11 T12 | `cg_flags` | SVA06 |
| R12 | T13 T14 | `clear_x_occ_x_op` | SVA07 |
| R13 | T15 | `cg_flags` | — |
| R14 | T18 T19 T20 | — | — |
| R15 | T16 | `C_WRAP` | — |
| R16 | T05 | — | — |

## 8. Exit criteria

- [x] Every row passing in C1–C5.
- [x] 20 seeds per test per configuration, all passing.
- [x] 100% functional coverage.
- [x] 100% code coverage.
- [x] Every mutant caught.
- [x] No open bugs.

## 9. Bugs, questions and waivers

| ID | Found by | Description | Owner | Status |
|---|---|---|---|---|
| B1 | `probes/d1.sv` | `DEPTH` = 1 gives X on `rdata` (Q1) | Design | Fixed (spec 1.1) |
| B5 | Coverage | `dist` in inline `randomize() with` is ignored by Verilator | Verification | Fixed |
| B6 | Coverage | Data patterns never hit at `SIZE` = 32 | Verification | Fixed (T21) |

## 10. Revision history

| Version | Date | Spec version | Change |
|---|---|---|---|
| 0.1 | 2026-10-06 | 1.0 | First draft |
| 0.2 | 2026-10-06 | 1.0 | Bench built; B5 |
| 0.3 | 2026-10-06 | 1.0 | T21 added (B6) |
| 0.4 | 2026-10-08 | 1.1 | `DEPTH` = 1 fixed; C5 and T20 enabled |
| 0.5 | 2026-10-12 | 1.1 | Covergroup definitions (5.1); CSV version |
