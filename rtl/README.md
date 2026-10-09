# `rtl/`: the design under test

`socetlib_fifo.sv` is by the `digital-lib` contributors.

| Local change | Why |
|---|---|
| Storage index is 0 when `DEPTH` = 1 | The pointers indexed past a one-entry array (spec Q1) |
| `FULL` constant and a named parameter-check block | Lint-clean at every `DEPTH` |

## What the testbench needs to know

- Every output comes from a register. `rdata` shows the oldest entry while `empty` = 0.
- A write while full, or a read while empty, is dropped and sets a sticky flag; nothing stalls.
- `clear` beats `WEN` and `REN`. It empties the FIFO and clears both flags, but not the storage.
- `DEPTH` must be a power of 2; anything else stops elaboration.
