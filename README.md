# uvm-fifo

Worked example 3 of the [SiliconBadgers UVM training](https://github.com/ihagedo/uvm-training). A complete UVM testbench for a synchronous FIFO, built from a spec and a test plan: one agent, a reference model, a scoreboard that compares every cycle, assertions, coverage, and a regression that must catch eight planted bugs.

![FIFO block diagram](./docs/fifo.png)

## Run it

From a `uvm-training` checkout (`git clone --recurse-submodules git@github.com:ihagedo/uvm-training.git`):

```bash
cd examples/fifo
make run                       # Verilator (default), CONFIG=C1: SIZE=8, DEPTH=8
make run SIM=questa            # or xcelium, vcs
make run CONFIG=C5 TEST=fifo_random_test SEED=3
make run BUG=4                 # planted bug M4: full one entry early
make waves                     # FST waves; open with gtkwave
make regress                   # Verilator: 7 tests x 20 seeds x C1-C5, with coverage
make mutants                   # Verilator: every planted bug must be caught
```

Set up the tools first; see the `uvm-training` README. Outside `uvm-training`, point `UVM_HOME` at the `src/` directory of a UVM 1.2 checkout.

A passing run ends with `*** TEST PASSED ***` and `PASS fifo_smoke_test`.

## Layout

| Path | Contents |
|---|---|
| `rtl/` | The DUT, `socetlib_fifo.sv` (see `rtl/README.md`) |
| `docs/` | Spec, test plan, block diagram |
| `agent/` | Interface, input item, observation, driver, monitor, agent |
| `environment/` | Reference model, scoreboard, coverage, environment, assertions |
| `test/` | Sequences, tests, package |
| `top_tb/` | Top module: clock, DUT, assertions, `run_test()` |
| `mutants/` | Planted bugs M1–M8 as `sed` scripts |
| `scripts/` | Regression and mutant runner |
| `results/` | Last `make regress` and `make mutants` reports |
| `probes/` | Directed checks behind the spec, in Verilator and iverilog (`probes/run.sh`) |

## Walkthrough

Read the files in this order. Each step answers one question.

1. **What must the FIFO do?** `docs/fifo-spec.md`: ports, protocol rules P1–P5, requirements R01–R16, and a cycle table.
2. **What will be checked, and how?** `docs/fifo-test-plan.md`: configurations C1–C5, test items, coverage, assertions, and a traceability table back to the requirements.
3. **How does the testbench reach the DUT?** `agent/fifo_if.sv` and `top_tb/tb_top.sv`. The driver writes through one clocking block; the monitor samples through another, one step before each edge.
4. **What is a transaction?** `agent/fifo_item.svh` is one cycle of inputs, or a reset. `agent/fifo_obs.svh` is one cycle of outputs.
5. **How does stimulus reach the pins?** `agent/fifo_driver.svh`: one item per clock, and resets that fall in the middle of a cycle.
6. **How are the outputs observed?** `agent/fifo_monitor.svh`: an observation at every edge, plus a check that outputs never change between edges.
7. **What should have happened?** `environment/fifo_predictor.svh`, a reference model written from the spec, not from the RTL.
8. **How is it checked?** `environment/fifo_scoreboard.svh` compares every cycle and names the requirement behind each mismatch. `environment/fifo_sva.sv` adds assertions bound into the DUT.
9. **What was exercised?** `environment/fifo_coverage.svh`. `make regress` reports every bin and every line of RTL that was missed.
10. **How is a test put together?** `test/fifo_seqs.svh` and `test/fifo_tests.svh`, one sequence per test-plan row.
11. **How do we know the testbench works?** `mutants/` and `make mutants`: each planted bug must fail at least one test.

## Exercises

1. Run `make run BUG=5`. It passes. Which tests catch M5 (`results/mutants.txt`), and why does the smoke test miss it?
2. Delete the `bind` of `fifo_sva` in `top_tb/tb_top.sv` and run `make mutants`. Is every bug still caught? What did the assertions add?
3. Add a test that fills the FIFO, clears it while full, and fills it again. Add a row for it to the test plan and run it on C1 and C5.
4. Run `make regress CONFIGS=C5`. Which coverage points do not apply at `DEPTH` = 1, and why?

## Results

`results/regress.txt`: 7 tests × 20 seeds × 5 configurations, all passing.

| Config | Runs passed | Functional coverage | Code coverage |
|---|---|---|---|
| C1 | 140/140 | 58/58 | 100% |
| C2 | 140/140 | 58/58 | 100% |
| C3 | 140/140 | 50/50 | 100% |
| C4 | 140/140 | 58/58 | 100% |
| C5 | 140/140 | 48/48 | 100% |

`results/mutants.txt`: all 8 planted bugs caught.

## History

Moved here from `examples/fifo` of `ihagedo/uvm-onboarding`. The RTL is by the `digital-lib` contributors, with `DEPTH` = 1 fixed (spec 1.1).
