# Add dsh-simulink-mcp

Entry file: `data/plugins/yrsxy__dsh-simulink-mcp.yml`

```yaml
url: https://github.com/yrsxy/dsh-simulink-mcp
name: yrsxy/dsh-simulink-mcp
category: dev
description:
  en: Builds, wires, compiles and simulates Simulink models inside the MATLAB session you already have open.
  zh: 在你已经开着的 MATLAB 会话里建 Simulink 模型、连线、编译与仿真。
icon: https://raw.githubusercontent.com/yrsxy/dsh-simulink-mcp/main/assets/icon-180.png
```

What the plugin is: a DSH bundle that registers the MathWorks MCP server plus 32
`sl_*` Simulink tools, ships both platform binaries, installs four agent skills
and adds a Simulink settings page. It attaches to a MATLAB desktop session that
is already running instead of starting its own headless one.

Self-contained: the only machine-specific value in `cordis.patch.yml` is the
`$DSH_HOME` prefix; `runtime/launcher.cjs` picks the binary for the current
platform and locates MATLAB. Verified on macOS (R2024a) and Windows 11 (R2022b).

Repo is 24h+ old as required. Seven screenshots are declared in
`screenshots.json`.
