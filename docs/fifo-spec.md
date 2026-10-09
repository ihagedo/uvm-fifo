# `socetlib_fifo` specification

| | |
|---|---|
| RTL | `rtl/socetlib_fifo.sv` |
| Design owner | Silicon Badgers |
| Version | 1.1 |

## 1. Summary

A single-clock, flip-flop FIFO with `DEPTH` entries of `SIZE` bits. The oldest entry is always on `rdata`. A write when full or a read when empty is dropped and sets a sticky flag. Not for clock-domain crossing.

## 2. Block diagram

![FIFO RTL diagram](fifo.png)

A `DEPTH × SIZE` register file with read and write pointers. `count`, `full` and `empty` come from an occupancy register. Every output comes from a register.

## 3. Parameters

| Parameter | Default | Valid range | Description |
|---|---|---|---|
| `SIZE` | 8 | ≥ 1 | Entry width |
| `DEPTH` | 8 | Power of 2, ≥ 1 | Number of entries |

Out-of-range values: a `DEPTH` of 0 or a non-power of 2 stops elaboration, unless `QUARTUS` is defined.

## 4. Clocks and resets

| Signal | Description |
|---|---|
| `CLK` | Rising edge. The only clock. |
| `nRST` | Active low, asynchronous assert, synchronous deassert. Resets pointers, `count`, flags and every storage entry to 0. |

## 5. Ports

| Port | Dir | Width | Reset value | Description |
|---|---|---|---|---|
| `CLK` | in | 1 | — | Clock |
| `nRST` | in | 1 | — | Reset |
| `WEN` | in | 1 | — | Write enable |
| `REN` | in | 1 | — | Read enable (pop) |
| `clear` | in | 1 | — | Synchronous clear |
| `wdata` | in | `SIZE` | — | Write data |
| `full` | out | 1 | 0 | `count` = `DEPTH` |
| `empty` | out | 1 | 1 | `count` = 0 |
| `underrun` | out | 1 | 0 | Sticky: read while empty |
| `overrun` | out | 1 | 0 | Sticky: write while full |
| `count` | out | `$clog2(DEPTH+1)` | 0 | Entries stored |
| `rdata` | out | `SIZE` | 0 | Oldest entry |

Protocol rules:

- P1. Inputs are sampled on the rising edge of `CLK`. No output depends combinationally on an input.
- P2. A write is accepted when `WEN` = 1, `clear` = 0, `full` = 0, and not (`empty` = 1 and `REN` = 1).
- P3. A pop happens when `REN` = 1, `clear` = 0, `empty` = 0, and not (`full` = 1 and `WEN` = 1).
- P4. `rdata` is valid in the same cycle `REN` is raised. The pop takes effect at the next edge.
- P5. There is no back-pressure. Dropped operations are flagged, not stalled.

## 6. Register map

None.

## 7. Functional description

### 7.1 Programming model

None.

### 7.2 Operation

- `clear` has priority over `WEN` and `REN`. It resets pointers, `count` and flags, but not storage.
- `overrun` and `underrun` stay set until `clear` or `nRST`. The FIFO keeps working while they are set.
- There is no forwarding: when empty, `WEN` + `REN` does neither; when full, `WEN` + `REN` does neither.

### 7.3 Timing

| Operation | Latency | Throughput |
|---|---|---|
| Write | Visible on `rdata` and `count` after the write edge | 1 per cycle |
| Pop | Next entry on `rdata` after the pop edge | 1 per cycle |
| Flags | Set after the edge that sampled the dropped operation | — |
| `nRST` | Immediate | — |

Cycle table (`DEPTH` = 2), from `probes/wave.sv`. Each row's inputs take effect in the next row. `rdata` in parentheses is not valid.

| Cycle | `WEN` | `REN` | `clear` | `wdata` | `full` | `empty` | `count` | `overrun` | `underrun` | `rdata` |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | - | 0 | 1 | 0 | 0 | 0 | (`00`) |
| 1 | 1 | 0 | 0 | `a1` | 0 | 1 | 0 | 0 | 0 | (`00`) |
| 2 | 1 | 0 | 0 | `b2` | 0 | 0 | 1 | 0 | 0 | `a1` |
| 3 | 1 | 1 | 0 | `c3` | 1 | 0 | 2 | 0 | 0 | `a1` |
| 4 | 0 | 1 | 0 | - | 1 | 0 | 2 | 1 | 0 | `a1` |
| 5 | 0 | 1 | 0 | - | 0 | 0 | 1 | 1 | 0 | `b2` |
| 6 | 0 | 1 | 0 | - | 0 | 1 | 0 | 1 | 0 | (`a1`) |
| 7 | 1 | 0 | 1 | `d4` | 0 | 1 | 0 | 1 | 1 | (`a1`) |
| 8 | 1 | 0 | 0 | `e5` | 0 | 1 | 0 | 0 | 0 | (`a1`) |
| 9 | 0 | 0 | 0 | - | 0 | 0 | 1 | 0 | 0 | `e5` |

## 8. Requirements

| ID | Requirement |
|---|---|
| R01 | Entries shall leave in the order they were written. |
| R02 | A write shall store `wdata` as the newest entry when `WEN` = 1, `clear` = 0 and `full` = 0, except as in R09. |
| R03 | A pop shall remove the oldest entry when `REN` = 1, `clear` = 0 and `empty` = 0, except as in R08. |
| R04 | While `empty` = 0, `rdata` shall equal the oldest entry. A cycle with no `WEN`, `REN` or `clear` shall change no output. |
| R05 | `count` shall equal the entries stored; `full` = 1 exactly when `count` = `DEPTH`; `empty` = 1 exactly when `count` = 0. |
| R06 | A write while full shall be dropped and set `overrun`. |
| R07 | A read while empty shall change nothing except setting `underrun`. |
| R08 | While full, `WEN` = `REN` = 1 shall do neither operation and set `overrun`. |
| R09 | While empty, `WEN` = `REN` = 1 shall do neither operation and set `underrun`. |
| R10 | While 0 < `count` < `DEPTH`, `WEN` = `REN` = 1 shall write and pop at the same edge. |
| R11 | `overrun` and `underrun` shall stay 1 until `clear` or `nRST`, and the FIFO shall keep working. |
| R12 | `clear` shall empty the FIFO and clear both flags, whatever `WEN` and `REN` are. |
| R13 | `nRST` = 0 shall immediately empty the FIFO, clear both flags and zero the storage. |
| R14 | R01–R13 shall hold for every `SIZE` ≥ 1 and power-of-2 `DEPTH` ≥ 1. Other `DEPTH` values shall stop elaboration. |
| R15 | R01–R13 shall hold across pointer wraparound. |
| R16 | Outputs shall change only after a rising edge of `CLK` or when `nRST` falls. |

## 9. Corner cases

| Condition | Behaviour | Req |
|---|---|---|
| Write while full | Dropped, `overrun` set | R06 |
| Read while empty | `underrun` set | R07 |
| `WEN` + `REN` while full | Neither happens, `overrun` set | R08 |
| `WEN` + `REN` while empty | Neither happens, `underrun` set | R09 |
| `clear` with `WEN` or `REN` | `clear` wins | R12 |
| `rdata` while empty | Stale: 0 after `nRST`, old data after `clear` | R04 |
| `DEPTH` = 1 | One entry; same rules | R14 |

## 10. Assumptions

| ID | Assumption |
|---|---|
| AS1 | Inputs are synchronous to `CLK`. |
| AS2 | `nRST` deasserts synchronously to `CLK`. |
| AS3 | `WEN`, `REN` and `clear` are never X while `nRST` = 1. |
| AS4 | `rdata` is used only while `empty` = 0. |
| AS5 | After a flag is set, the user issues `clear`. |

## 11. Known limitations

| ID | Limitation |
|---|---|
| L1 | No forwarding (R08, R09). |
| L2 | `clear` does not erase storage. |
| L3 | `DEPTH` must be a power of 2. |
| L4 | Flip-flop storage only. |
| L5 | Single clock domain. |

## 12. Open questions

| ID | Question | Owner | Answer |
|---|---|---|---|
| Q1 | Is `DEPTH` = 1 supported? The pointers were 2 bits wide for one slot, and `rdata` went X in 4-state simulators (`probes/d1.sv`). | Design | Yes. Fixed in 1.1. |
| Q2 | While full, should `WEN` + `REN` push and pop? | Design | No. Neither happens. |
| Q3 | Is `SIZE` = 1 supported? | Design | Yes (`probes/s1.sv`). |

## 13. Revision history

| Version | Date | RTL commit | Change |
|---|---|---|---|
| 1.0 | 2026-10-06 | `375f643` | First version, from digital-lib `fifo/doc/fifo.md` |
| 1.1 | 2026-10-08 | — | `DEPTH` = 1 fixed (Q1); `SIZE` = 1 confirmed (Q3); lint-clean RTL |
