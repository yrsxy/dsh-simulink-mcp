---
name: simulink-simulation
description: Use when running a Simulink simulation through the simulink MCP tools and reading results back — solver and stop time choices, why simOut is empty, extracting and interpreting signal data, and plotting it.
---

# Running a simulation and reading the result

## Checklist before `sl_sim`

- The model **compiles**: `sl_update(model)` returns `ok: true`.
- The signal you want to inspect reaches an **Outport** or is marked for logging.
  `simOut` only contains Outport data and logged signals; a Scope wired to nothing
  else produces no data, and `sl_sim_data("yout", ...)` will fail.
- `StopTime` is long enough to show the behaviour you claim. For a first-order system
  with time constant τ, simulate at least 5–7 τ; 1 s is not enough to see a settle.

## Driving the run

- `sl_sim(model, stop_time, solver)` — `""` keeps the model's own value.
  - `ode45` is the default choice for smooth continuous dynamics.
  - Use `ode15s` for stiff plants (electrical, thermal, hydraulic).
  - Use a fixed-step solver when sample time matters, or before code generation.
- The output stays in the base workspace as `simOut`, so several `sl_sim_data` calls
  read the same run. A new `sl_sim` overwrites it.

## Reading data

- `sl_sim_data("yout", 200)` returns `{time, data}` for a single-output model; for a
  multi-output model `yout` is a Dataset and the reply lists element names — pass a
  name back in to read that element.
- `sl_sim_data("tout", 50)` gives the actual solver time vector (useful when the
  solver took variable steps).
- Downsample for reading; do not pull 100k points into context. `max_points <= 0`
  means 500.

## Interpreting it honestly

Compute the expected value **before** looking at the curve, and state the topology you
are computing for. A gain placed on the reference input is not loop gain: for
`ref -> Gain(K) -> Sum(+/-) -> Plant(1/(s+a))` with unity feedback the closed loop is
`K/(s+a+1)`, so the DC gain is `K/(a+1)` — not `K/(1+K)`. Getting this wrong is the
most common way to "find a bug" that is not there.

Then check:
- DC / final value against the analytic value (tolerance a few percent, not exact).
- Time constant against expectation (`τ = 1/pole`).
- No NaN, no integrator wind-up to an absurd value, no chatter at the step edge.

## Plotting

`sl_plot("yout", "")` writes a PNG and returns its path. Look at it — a curve that
"settled" can be oscillating or clipped and the numbers will not say so.
