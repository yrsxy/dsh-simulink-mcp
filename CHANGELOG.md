# Changelog

## 1.6.2

Security fix, reported by the plugin-market reviewer while reviewing the entry.

The four HTTP routes this plugin registers on the host (`/status`, `/snapshot`,
`/act`, `/debug`) were reachable by any page open in the browser: they answered
whoever asked, with no Host/Origin fence and no login check. They drive a real
MATLAB session, so that was a genuine hole.

Every route now asks the host first:

```js
const rejection = ctx.get('connection').requestRejection(req)
if (rejection !== undefined) { /* 401 or 403 */ }
```

Exit paths and why they are fail-closed:

- the fence returns a status → answered with 401 `unauthorized` or 403
  `forbidden`, before any MATLAB work.
- the fence throws → treated as 403. A fence that breaks is not a pass.
- the host has no `connection` service at all (older DSH) → a local stand-in
  checks that Host is a loopback authority and, when an Origin is present, that
  it matches Host. Narrower than the host fence, but still closed to another
  page.


## 1.6.1

The package was renamed from the local `@local/dsh-simulink-mcp` to
`dsh-simulink-mcp` for the npm release, but two places still carried the old
name and the app refused to boot the web UI:

- `client.js` registered its factory under `@local/dsh-simulink-mcp`. With the
  old link still present in the profile's `node_modules`, the loader saw the same
  bundle twice and aborted with `duplicate factory registration`, which surfaced
  as `web boot: 1 entry did not activate`.
- the skill marker file `.installed-by` still said `@local/…`, so uninstalling
  the plugin would have left the four skills behind. The marker now records the
  real package name and both spellings are accepted when cleaning up.


## 1.5.2

Two build-path improvements found while shooting the demo material for the plugin market:

- `sl_build` resolved block types against a fixed alias table only, so a spec
  written the way the block browser shows it (`"PID Controller"`,
  `"Transfer Function"`) failed with `needs "lib" or a known "type"`. The alias
  table gained those spellings, and an unknown type now falls back to a name
  lookup in the Simulink library before giving up.
- `sl_build` created lines without autorouting, which left diagonal wires across
  blocks as soon as the spec carried its own positions. Lines are now added with
  `autorouting on`, matching `sl_add_line`.

## 1.5.1

A diagnostic fix found while shooting the demo material: `sl_update` reported
"compiled: false" with an empty `blocks` list and no `hint` whenever MATLAB ran
with a Chinese UI.

- Simulink wraps block names in `<a href="matlab:open_and_hilite_hyperlink…">`
  markup, and the path was only recognised when quoted as plain text, so
  `blocks` came back empty. The markup is stripped before parsing now, so
  `sl_update` names the offending block again.
- The hint table matched English wording only, which never appears on a
  localised MATLAB. Every class now has both wordings (unconnected / dimension /
  algebraic loop / undefined / sample time / invalid setting / cannot propagate),
  plus a fallback that points at `sl_block_params` when a block is named but the
  error is unfamiliar.

## 1.5.0

Second Windows round. The tools were fine this time; the *panel* was not, and
the runtime mirror could break `apply()` on a machine where the server held its
own files open.

- The panel called tools with the batch `tools.execute({calls:[…]})` shape,
  which some Harness builds reject with "tool execution arguments must be
  losslessly JSON-serializable" - every panel field then read "no tool result"
  while the same tool worked from the chat. Both shapes are now tried at
  runtime (object first for single-call builds, then the batch shape) and the
  winner is remembered, so neither build is broken by supporting the other.
- `syncRuntime` overlays files instead of deleting the mirror: the running
  `matlab-mcp-server` holds its own `.exe` and `.logs`, so a wholesale delete
  fails with EPERM on Windows - and that single failure used to skip skill
  installation and `startup.m` as well, leaving the panel stuck on the error.
  Locked files are reported and the stamp stays unwritten so the next boot
  retries; only files the package no longer ships are removed (never `.logs`).
- `apply()` isolates runtime / skills / `startup.m`, so one failure no longer
  cancels the others; skill installation retries briefly on EPERM because a
  bundle reload races the old instance's cleanup.
- New panel switch "auto-start MATLAB": preference in
  `$DSH_HOME/simulink-mcp/settings.json`, `POST /plugin-simulink/settings`
  answers immediately with `launch.state = starting` and a single-flight
  background task polls `sl_env` (20 x 3 s) until the session answers, so a slow
  desktop start no longer looks like a failure. The panel polls while starting,
  and every state also has text, not just a colour.
- Opening the panel never starts MATLAB: a plain `/status` reads the cache and
  only probes when a MATLAB process already exists (attach is then harmless) or
  when the Refresh button asks for it (`?probe=1`).
- `launcher.cjs` deletes session folders left by a dead MATLAB before starting,
  so the server stops attaching to a port nothing listens on (that cost up to
  three minutes per launch and made startup look broken).

## 1.4.1

Everything here came from running 1.4.0 on a real Windows machine (Windows 11,
MATLAB R2022b installed portably in `F:\matlab`, Smart App Control enforcing
code signing). Five of the fixes are startup- or session-blocking there.

- `launcher.cjs` searches much wider for MATLAB: `MATLAB_ROOT` /
  `MATLAB_INSTALL_DIR`, the `MathWorks\MATLAB` registry keys (HKLM, WOW6432,
  HKCU), the standard install folders, then every drive for a portable copy
  such as `F:\matlab` or `D:\MATLAB\R2022b`. A portable install used to start
  the server with no MATLAB at all. What was searched is written to
  `runtime/.matlab-search.json` and repeated in the log.
- `sl_sim` switches a model to `SaveFormat='Array'` before simulating and
  retries once on `SimulinkHMI:observers:SignalObserverCreateFailure`. Dataset
  output needs the Simulink signal observer; when a Windows application-control
  policy blocks that DLL, every later simulation in the session fails too.
  Array output needs no observer and loses no data.
- `sl_new` creates models with `SaveFormat='Array'` for the same reason.
- `sl_series`, `sl_plot` and `sl_metrics` read Array output: raw samples with
  `simOut.tout` as the time vector. Before this they only understood
  timeseries/Dataset, which is also why `sl_plot` drew sample indices as
  "time (s)" for numeric signals - that is fixed, and numeric data without a
  matching `tout` is labelled `sample` instead of pretending to be seconds.
- `sl_save` falls back to `.mdl` when writing `.slx` fails, and says why: the
  `.slx` writer loads MathWorks DLLs that application control can block
  (`glee2_mi.dll`), while the `.mdl` writer does not.
- `sl_selftest` proves a library path by adding a block instead of
  `get_param('simulink/...')`, which force-loads the whole Simulink library and
  turns a healthy session into a broken one on such machines. Its save check
  accepts the `.mdl` fallback and reports the reason.
- `sl_env` now reports `matlabRoot`, the active `saveFormat`, and what the
  launcher found (`launcher.found`, `launcher.searched`).
- `sl_build` understands more plain types: `out1`, `in1`, `tf`, `sat`,
  `sinewave`, `ground`, `toworkspace`, `stop`, `unitdelay`, `memory`,
  `relational`, `switch`, `lookuptable`. Type keys keep their digits, so `Out1`
  no longer needs a full library path.
- Verified on R2022b (111 toolboxes) and R2024a; `sl_selftest` 14/14 on both.

## 1.4.0

Cross-platform, so the same package can be validated on Windows before it
goes anywhere near a catalog.

- The MCP server binary now lives under `runtime/bin/<platform>-<arch>/`;
  macOS arm64 and Windows x64 are both bundled.
- `runtime/launcher.cjs` picks the binary for the running platform, finds
  MATLAB, puts its `bin` on PATH, and fills in `--matlab-root`,
  `--extension-file` and `--log-folder`.
- `cordis.patch.yml` no longer contains a single absolute path: the mcp-client
  row runs the app's own Node (`ELECTRON_RUN_AS_NODE=1`) on the launcher.
- Server binaries updated to v0.16.1.
- `INSTALL-WINDOWS.md` documents setup, the verification checklist and where
  to look when something does not start.

## 1.3.0

Two tools that change how a model is assembled rather than poked at block by
block.

- `sl_build(model, spec, layout)` builds or extends a model from a JSON spec:
  blocks by library path or plain type, parameters, positions and connections,
  inline or from a file. Rerunning a spec is safe - existing blocks keep their
  place and only their parameters are updated, and a connection that is already
  there is reported as existing, not failed.
- `sl_subsystem(model, blocks, name, mode)` packs a list of blocks into one
  subsystem, or expands a subsystem back. Simulink creates the ports and keeps
  the inner wiring, so a diagram that grew unreadable can be folded without
  rebuilding it.

Fixes found while testing them: a mixed `blocks` list comes back from
jsondecode as a cell array rather than a struct array, renaming a subsystem
invalidates its path string, and `createSubsystem` only accepts handles (it
returns nothing and rejects paths). Expanding a subsystem also leaves an area
annotation outlining where it was; it is now removed, including one left by an
earlier expand of the same name.

## 1.2.0

- Add `sl_trace`: follow one signal upstream or downstream instead of listing
  every line, with port-to-port edges and a hop-by-hop chain.
- Add `sl_metrics`: overshoot, rise time, settling time, steady state and
  steady-state error for the last simulated signal.
- Add `sl_highlight`: mark a block in red so the next snapshot shows where the
  problem is.
- Add `sl_selftest`: end-to-end proof of the toolchain in a throwaway model.
- `sl_update` now reports the blocks named in a compile diagnostic plus a hint
  for the next call, instead of only an error string.
- Fix `sl_open`: `exist(path,'file')` reports 4 for a `.slx` model, so every
  `.slx` open was rejected as "model file not found". Now uses `isfile`.
- Fix `sl_last_error`: `MException.last` only works at the command prompt, so
  the tool always failed. Failures are now recorded in root appdata by
  `sl_fail` and read back by `sl_last_error`.
- Add `/plugin-simulink/debug` route and an apply-time trace file
  (`$DSH_HOME/simulink-mcp/apply.json`) for install diagnosis.

## 1.1.0

- Ship the MCP runtime inside the package and mirror it to `$DSH_HOME`.
- Install the four Simulink skills into `$DSH_HOME/skills`.
- Add the settings panel, its `/plugin-simulink` routes and the client bundle.

## 1.0.0

- Configuration-only bundle registering the MathWorks MCP server with 26
  Simulink tools.
