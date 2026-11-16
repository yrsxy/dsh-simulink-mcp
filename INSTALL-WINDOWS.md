# 在 Windows 上安装并验证 · Simulink MCP 插件

这份说明对应 `@local/dsh-simulink-mcp` 1.4.1。包里已经带了两个平台的 MCP 服务器
（`runtime/bin/darwin-arm64`、`runtime/bin/win32-x64`），所以**不需要**再联网下载任何东西。
启动器 `runtime/launcher.cjs` 会自己挑当前平台的二进制、找 MATLAB、拼好参数，
`cordis.patch.yml` 里没有任何绝对路径。

---

## 0. 前提

| 项 | 要求 |
|---|---|
| 系统 | Windows 10/11 x64 |
| MATLAB | R2022b 或更新（实测 R2022b 与 R2024a），**含 Simulink** |
| DSH | 桌面版已装好并能正常对话 |
| Node | 不用单独装：启动器用的是 DSH 自带的 Electron（`ELECTRON_RUN_AS_NODE`） |

MATLAB 的位置**不用手填**。启动器按这个顺序找，取第一个含 `bin\matlab.exe` 的：

1. 环境变量 `MATLAB_ROOT` / `MATLAB_INSTALL_DIR`（要显式指定时用，**不要**带 `\bin`）；
2. 注册表 `HKLM|HKCU\SOFTWARE\MathWorks\MATLAB`（含 WOW6432Node）；
3. `C:\Program Files\MATLAB\R20xxx`；
4. **逐个盘符扫便携安装**，例如 `F:\matlab`、`D:\MATLAB\R2022b`。

扫过哪些路径写在 `runtime\.matlab-search.json`（`runtime` 包目录里同一份也会被镜像到
`%USERPROFILE%\.dsh\simulink-mcp\runtime\`），日志里也会重复一遍。找不到时先看这个文件，
再设 `MATLAB_ROOT`。

---

## 1. 解压

建议放在纯英文、无空格的路径，例如：

```
C:\dsh-plugins\dsh-simulink-mcp
```

不要放在 `Program Files` 下（插件运行时要写 `runtime\.logs` 和镜像目录）。

---

## 2. 一次性准备 MATLAB 会话（推荐）

在 PowerShell 里执行（路径按实际改）：

```powershell
& "C:\dsh-plugins\dsh-simulink-mcp\runtime\bin\win32-x64\matlab-mcp-server.exe" `
  --setup-matlab --matlab-root="C:\Program Files\MATLAB\R2024a"
```

这一步会装一个 `MATLAB MCP Server Toolbox`，并在
`%USERPROFILE%\Documents\MATLAB\startup.m` 里加入 `shareMATLABSession`。
之后**每次启动 MATLAB 都会自动共享会话**，插件就能接管你眼前那个 MATLAB 桌面。

> 跳过这一步也能用：插件默认 `--matlab-session-mode=auto`，找不到共享会话时会自己
> 起一个 MATLAB。只是那样一来，`sl_show`、`sl_snapshot` 看到的是后台会话，
> 不是你自己开的那个窗口。

---

## 3. 安装插件

在 DSH 的对话框里让 agent 安装（把路径换成你的）：

> 把这个目录安装成插件：`C:\dsh-plugins\dsh-simulink-mcp`

它内部执行的是 `plugin_manager install_bundle`。装好后：

- `Settings → 插件` 里会出现 **Simulink 建模工具**，图标是源块+增益+示波器；
- 组合树里多出两行：`include:simulink-bundle`、`include:mcp-simulink`；
- 工具列表里多出 32 个 `mcp__simulink__sl_*`，外加官方 5 个（`evaluate_matlab_code` 等）。

---

## 4. 启动 MATLAB，然后验证

先打开 MATLAB 桌面（等它完全起来），再按顺序让 agent 跑：

| 步骤 | 期望结果 |
|---|---|
| `sl_env` | `desktop: true`、`matlabVersion` 是你的版本、`simulink: true` |
| `sl_list_models` | `ok: true`，`models` 是你当前打开的模型（没有就是空数组） |
| `sl_selftest` | `passed: 14, failed: 0`，约 0.5 秒 |
| `sl_build` + `sl_sim` + `sl_metrics` | 能建模型、跑仿真、给出超调/上升时间等指标 |
| 设置面板 → Simulink | 显示 pid、版本、模型列表、最近错误 |

`sl_selftest` 是随包自带的冒烟测试：它在 MATLAB 临时目录里建模型、连线、编译、仿真、
取数、截图、存盘，跑完清理干净。**它过了，说明这条链路在你这台机器上是通的。**

---

## 5. 出问题时看哪里

| 现象 | 先看 | 常见原因 |
|---|---|---|
| 工具调用报 “server not started” | `%USERPROFILE%\.dsh\simulink-mcp\apply.json` | 插件没加载；或运行时没镜像成功 |
| 启动器报 `no server binary for win32-x64` | `runtime\bin\` 目录 | 压缩包没解全 |
| 报找不到 MATLAB | `%USERPROFILE%\.dsh\simulink-mcp\runtime\.logs\` | MATLAB 不在默认路径且没设 `MATLAB_ROOT` |
| `sl_env` 的 `desktop` 是 `false` | 见第 2 节 | 共享会话没起来，用的是后台 MATLAB |
| 面板一直“未连接” | `http://127.0.0.1:<端口>/plugin-simulink/status` | 浏览器侧没加载；刷新页面 |

调试接口（面板自己用的就是它）：

```
GET /plugin-simulink/status            环境、模型、最近错误
GET /plugin-simulink/debug?tool=sl_env 原始返回，用来定位解析问题
```

端口取 `%USERPROFILE%\.dsh\simulink-mcp\apply.json` 里的 `origin`。

---

---

## 5.5 设置面板里的「自动打开 MATLAB」

- 面板默认不探测：打开设置页**不会**把 MATLAB 拉起来（这是刻意的，早期版本会）。
- 需要它在 DSH 启动时自动拉起会话，打开「自动打开 MATLAB」开关；偏好存在
  `%USERPROFILE%\.dsh\simulink-mcp\settings.json`。
- 首次启动桌面会话可能需要 1–3 分钟，面板会显示「正在启动」并每 2 秒轮询，最长 5 分钟。
- 如果日志里出现 `Attaching to existing session` 然后 `timeout waiting for matlab to be ready`，
  说明有**死会话残留**：1.5.0 的启动器会在没有 MATLAB 进程时自动清掉
  `runtime\.logs\matlab-session-*`；仍不行就手动删掉这些目录再重启 DSH。

## 6. Windows 应用控制（Smart App Control / WDAC）拦截 MATLAB DLL

**症状**：`sl_env` 本身正常，但一仿真就报
`SimulinkHMI:observers:SignalObserverCreateFailure`，之后整个会话都失败；
`sl_save` 写 `.slx` 报 `Failed to load bundle #308: glee2_mi.dll`；
`load_system('simulink')` 直接失败。事件查看器
`Microsoft-Windows-CodeIntegrity/Operational` 事件 ID **3077** 一大片，
文件名多为 `sl_async_adaptors.dll`、`glee2_mi.dll`、`sse_datamodel.dll`、`_asyncio.pyd`。

这是 Windows 在拦截**未签名**的 MathWorks DLL，不是插件的问题。1.4.1 已经绕开了能绕的部分：

- `sl_sim` / `sl_new` 用 `SaveFormat='Array'`，不碰 signal observer；
- `sl_save` 写 `.slx` 失败时自动改存 `.mdl`（`.mdl` 写入不需要 `glee2_mi.dll`），并返回 `warning` 说明原因；
- `sl_selftest` 用 `add_block` 探测库，不再用 `get_param('simulink/...')` 强行加载整个库。

彻底解决要在系统侧放行 MATLAB 安装目录（需管理员，且属系统安全策略，请自行评估）：
把 `F:\matlab`（或实际的 `matlabroot`）加入受信任位置，或关闭 Smart App Control
（`设置 → 隐私和安全性 → Windows 安全中心 → 应用和浏览器控制 → 智能应用控制`）。

---

## 7. 已知差异（R2022b）

- `get_param('simulink/Math Operations/Gain')` 在 R2022b 上需要先加载库才会成功；
  `sl_selftest` 已改为 `add_block` 探测，不受影响。
- `Dataset` 输出在 R2022b 上同样依赖 signal observer，因此 1.4.1 一律用 `Array`。

## 8. 卸载

`plugin_manager` → `remove_bundle`，目标 `@local/dsh-simulink-mcp`。
它同时会删掉镜像的运行时和随包安装的四个技能（技能目录里带 `.installed-by` 标记的才删）。
`startup.m` 里那行 `addpath(...runtime\matlab)` 会留一条失效路径，可以手动删掉，无副作用。
