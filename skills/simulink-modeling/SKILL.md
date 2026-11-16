---
name: simulink-modeling
description: Use when building or editing a Simulink model through the simulink MCP tools — adding blocks, setting parameters, wiring ports, laying out the diagram. Covers the build order that avoids overlapping blocks, wrong library paths and mis-wired ports.
---

# Building a Simulink model with the MCP tools

## Build order

1. `sl_env("")` — confirm which MATLAB session is in use before touching anything.
2. `sl_new(name, "")` — create the model, or `sl_open(path)` for an existing one.
3. For every block you need, `sl_lib_search(query, limit)` first. Never type a library
   path from memory; the library tree differs between releases.
4. `sl_add_block(source, destination, position)` — pass `""` for position and let the
   tool place it; you will run `sl_layout` later anyway.
5. `sl_set_param(target, param, value)` for every non-default value.
6. Wire with `sl_add_line(model, src, srcPort, dst, dstPort)`. Call `sl_ports(path)`
   first for any block with more than one output (Demux, Bus Creator, Mux, Subsystem).
7. `sl_layout(model, "right", 80)` — **after** wiring, never before. Layout needs the
   signal graph; run too early and every block lands in one column.
8. `sl_update(model)` — compile check. Fix errors here, before simulating.
9. `sl_snapshot(model, "", 150)` and look at the PNG. Do not claim a model is correct
   from the JSON alone.

## Conventions that make a model readable

- Block names describe role, not type: `ref`, `err`, `plant`, `u_cmd` — not `Gain1`.
  Rename by adding with the final name: `sl_add_block(src, "model/err", "")`.
- Sum blocks: set `Inputs` explicitly (`"+-"`, `"++"`, `"|+-"`). The default `"++"` is
  almost never what a control loop wants.
- Give every signal a destination: Scope, Outport, or a logged signal. A model that
  only terminates in Scope still simulates, but `simOut` will hold no data for it.
- Prefer one Outport per quantity you intend to read back.

## Block-specific notes

- **Transfer Fcn**: `Numerator` / `Denominator` take bracketed text, e.g. `"[1]"`,
  `"[1 1]"`. Read them back with `sl_block_params(path, "Numerator|Denominator")`.
- **PID Controller** (R2024a): set `LowerSaturationLimit` and
  `InitialConditionForIntegrator` together; leaving the default IC outside the
  saturation limits fails mask initialisation at compile time.
- **Subsystems**: `sl_add_block("simulink/Ports & Subsystems/Subsystem", ...)` gives an
  empty shell. Its contents are at `model/Sub/<inner>`; pass `depth = -1` to
  `sl_blocks` / `sl_lines` to see through it.

## Verifying the result

`sl_snapshot` is the fastest correctness check for wiring. A diagram where lines enter
the wrong port or loop around the canvas is a modelling bug, not a rendering quirk.
For the signal path itself, `sl_lines(model, 1)` returns the port-level truth; compare
it against what you intended to build.
