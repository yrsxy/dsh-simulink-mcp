---
name: simulink-testing
description: Use when verifying a Simulink model's behaviour with evidence through the simulink MCP tools — analytic checks against simulation, regression after edits, and MATLAB unit tests for the model's helper functions.
---

# Verifying a Simulink model with evidence

## Decide the claim first

Write down what the model should do, as a number: "DC gain 2.0", "settles within 5 %
by 2 s", "overshoot under 10 %". A simulation without a predicted value is an
observation, not a test.

## Analytic check per run

1. `sl_update(model)` compiles.
2. `sl_sim(model, stop_time, solver)` returns `samples > 0`.
3. `sl_sim_data("yout", 200)` and compare: final value, first peak, time to peak.
4. `sl_plot("yout", "")` — look at it. Numbers hide chatter, clipping and NaN tails.

For a first-order plant `1/(s+a)` with reference gain `K` and unity feedback, the
closed loop is `K/(s+a+1)`: DC gain `K/(a+1)`, time constant `1/(a+1)`. Derive the
expression for the topology you actually wired, and say it out loud before comparing.

## Regression after an edit

Simulation output is deterministic for a fixed model and solver, so the cheapest
regression is a numeric one:

1. Before the change, record `sl_sim_data("yout", 50)` into a file.
2. After the change, read it again and compare final value and a few sampled points.
3. `sl_snapshot` before/after and diff the PNGs — a structural change should show up
   visually (this also catches accidental block deletion).

For structural regressions, `sl_blocks` + `sl_lines` give a stable textual signature
of the model: sorted block paths, and the sorted `src/port -> dst/port` edge list.

## MATLAB-level tests

For helper functions and scripts that surround the model (parameter sweeps, post-
processing), write a MATLAB unit test and run it with the built-in tool
`run_matlab_test_file` — it returns structured pass/fail per test, which is stronger
evidence than a printed number. Static checks of the script itself go through
`check_matlab_code`.

## What not to claim

- Do not claim a model "works" from a compile check alone; compilation says nothing
  about correctness.
- Do not claim stability from a short run; simulate long enough for the slowest pole.
- Do not claim equivalence to a reference implementation from one operating point.
