---
name: simulink-debugging
description: Use when a Simulink model fails to compile, fails to simulate, or produces a wrong-looking result through the simulink MCP tools. Maps each common error message to the tool that diagnoses it and the fix.
---

# Diagnosing a broken Simulink model

## Always start here

1. `sl_update(model)` — compile without simulating. Most wiring, port, dimension and
   data-type errors surface here in a fraction of the time a simulation takes.
2. `sl_last_error(false)` — the full message plus the stack that raised it.
3. `sl_snapshot(model, "", 150)` — read the diagram. Wrong-port connections and
   dangling lines are visible immediately and are invisible in JSON summaries.

## Message → cause → fix

| Symptom | Cause | Fix |
|---|---|---|
| `Block diagram has no blocks` | blocks were never added, or all removed | `sl_blocks(model, 1, "")` to confirm |
| `Invalid Simulink object name: 'X/1'` | block `X` does not exist at that path | `sl_blocks` and use the exact path |
| `Port width mismatch` / dimension error | vector into a scalar port, or vice versa | `sl_block_params` on the source; insert Mux/Demux/Selector |
| `Algebraic loop` | direct feedthrough path with no state | add a Unit Delay / Integrator in the loop, or enable `SolverType` handling |
| `Unconnected input port` | missing `sl_add_line` | `sl_ports(path)` shows which inputs have no line |
| `solver failed / step size too small` | stiff dynamics on a non-stiff solver | `set_param Solver=ode15s` via `sl_sim(model, "", "ode15s")` |
| `PID failed to evaluate mask initialisation` | IC outside saturation limits | set `LowerSaturationLimit` and `InitialConditionForIntegrator` together |
| `Undefined variable` | block references a workspace variable | define it via `evaluate_matlab_code`, or inline a numeric value |
| shadowing warning about `.slx` | two files with the same model name on the path | save models into one folder; check `sl_list_models` and the file paths |

## Wrong result, no error

The model runs but the numbers are wrong. In this order:

1. `sl_lines(model, 1)` — verify port-level wiring. A gain feeding `Sum/2` instead of
   `Sum/1` silently flips the feedback sign.
2. `sl_block_params(path, "")` — defaults are rarely what you assumed (Step time is
   usually 1 s, not 0; Sum is `"++"`).
3. Check signal signs at the summing junction against the equation you wrote down.
4. Re-derive the expected steady state by hand for **this** topology before concluding
   the model is wrong. Sign errors and "gain in the reference path vs loop" mistakes
   are far more common than engine bugs.

## Reading a snapshot

- All blocks stacked vertically in one column: `sl_layout` was run before wiring, or
  not run at all. Wire first, then lay out.
- A line entering a block from the side/back that crosses other lines: the ports are
  wrong even if the diagram "looks connected".
- Feedback line taking a long detour: normal when the signal flows right-to-left;
  check it still reaches the intended input port.
