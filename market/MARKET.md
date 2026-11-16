# 上架素材包

DSH 插件市场用的图文素材。文案可以直接粘，图在 `assets/`，模型在 `models/mkt_servo.slx`（能复跑）。

---

## 一、列表页信息

**标题**　Simulink MCP

**副标题**　让 agent 直接建模型、跑仿真、读结果

**简介**（约 120 字）

> 把 Simulink 交给 agent，但 MATLAB 还是你自己那个。32 个工具覆盖建块、连线、改参数、排版、编译排错、仿真取数、指标计算、结构图截图；连的是你桌面上正开着的 MATLAB 会话，模型就开在你的编辑器里。附带 4 个技能，讲清建模顺序、仿真选型、报错归因和验收方法。

**亮点**

1. **接的是你的桌面 MATLAB**——不另起隐形实例，模型窗口、Workspace、断点都还在你眼前
2. **一句 JSON 建一张图**——`sl_build` 幂等，重复跑只更新参数；`sl_subsystem` 一键分组/展开
3. **编译失败能定位到块**——包括藏在子系统里的参数，`sl_update` 返回 `mkt_servo/plant/spr` 这种全路径
4. **结果不只是一堆数**——`sl_metrics` 给超调/上升/调节/稳态误差，`sl_snapshot` 出结构图 PNG
5. **自查随包**——`sl_selftest` 14 项冒烟，装完先跑它

**标签**　`simulink` `matlab` `控制系统` `仿真` `建模` `MCP`

**分类**　开发工具 / 工程仿真

**主图**　`assets/hero.png`（1600×800）

---

## 二、三组展示案例

演示模型是一个**位置伺服**：`ref`（1 m 阶跃）→ `err`（Σ）→ `PID`（Kp 60 / Ki 40）→ `sat`（±40 N）→ `plant`（子系统）→ `out`；`dist` 在 6 s 加 12 N 负载。`plant` 里是 `1/m`、两个积分器（速度、位置）和弹簧/阻尼反馈——物理上就是「质量-弹簧-阻尼」。

```
mkt_servo（顶层 7 块）          mkt_servo/plant（内部 10 块）
ref ─┬─> err ─> PID ─> sat ─┬─> plant ─┬─> out
     │                      │          │
     └──────────────────────┴──────────┘        plant: ΣF ─> 1/m ─> ∫v ─> ∫x ─┬─> out
                                                                               └── 阻尼 6v、弹簧 20x 回 ΣF
```

### 案例 1　建：一句 JSON 搭出带闭环的伺服

![顶层](assets/case1-model.png)

![子系统内部](assets/case1-inside.png)

```python
sl_build(model="mkt_servo", spec="/path/to/servo.json")
# → added 13, linesAdded 15, failed []
```

一次调用把 13 个块、15 根线全建好（含 PID、饱和、两个积分器、弹簧阻尼反馈、负载阶跃），再 `sl_subsystem` 把机械环节收进 `plant`。**幂等**：同样的 spec 再跑一次，已存在的块只更新参数、已连的线报 `linesExisting`。

**跑完的数**（`sl_sim` + `sl_metrics`）：上升 0.26 s，峰值 1.149（**+14.9%**），约 3 s 收敛；6 s 加载后跌到 **0.791 m**（下陷 0.21 m），**4.1 s** 回到 2% 带内。

![阶跃](assets/case1-step.png)

> 文案：块名、库路径、坐标、连线方向、子系统边界——以前最费人的是这些，现在是一条 JSON 加一次分组。

### 案例 2　诊：报错在子系统里，工具也点得到

把 `plant` 里的弹簧增益写成 `k_spring`（工作区没有这个变量）。`sl_update` 的返回：

```json
{"ok": false, "compiled": false,
 "error": "参数 'Gain' 的 'mkt_servo/plant/spr' 中的设置无效。",
 "blocks": ["mkt_servo/plant/spr"],
 "hint": "a block parameter is out of range or unreadable: read it back with sl_block_params"}
```

![诊断](assets/case2-model.png)

`blocks` 给的是**跨子系统边界的全路径**，红块是 `sl_highlight` 标的，图是 `sl_snapshot` 出的。中文版 MATLAB 的报错把块名裹在 `<a href="matlab:…">` 里——这版专门剥掉标记再解析（1.5.1 的修复）。

### 案例 3　扫：批量换参数，两条代价曲线对撞

同一结构，只动增益（Ki 跟着 Kp 走），三条响应叠在一张图上：

![扫参](assets/case3-sweep.png)

再扫一遍 Kp = 60…200，就是一张取舍图——**超调 11.9% → 24.3%，负载跌落 0.222 m → 0.084 m**：

![取舍](assets/case3-trend.png)

> 文案：手点十几次仿真、抄十组数字、画两张图，是 agent 一顿循环的事；每一步用的都是你真的会话，结果能当场核对。

---

## 三、工具一览（32 + 5）

| 组 | 工具 |
|---|---|
| 会话与模型 | `sl_env` `sl_set_folder` `sl_new` `sl_open` `sl_save` `sl_close` `sl_list_models` `sl_show` |
| 读结构 | `sl_blocks` `sl_ports` `sl_lines` `sl_block_params` `sl_lib_search` `sl_trace` |
| 改结构 | `sl_add_block` `sl_add_line` `sl_delete` `sl_delete_line` `sl_set_param` `sl_build` `sl_subsystem` `sl_cleanup` |
| 排版与验证 | `sl_layout` `sl_update` `sl_highlight` `sl_snapshot` `sl_selftest` |
| 仿真与结果 | `sl_sim` `sl_sim_data` `sl_series` `sl_metrics` `sl_plot` |
| 附带的 MATLAB 官方工具 | `evaluate_matlab_code` `run_matlab_file` `check_matlab_code` `run_matlab_test_file` `detect_matlab_toolboxes` |

---

## 四、安装

市场里一键装（推荐）。装完：

1. 设置 → 插件 → Simulink，点一次「刷新」
2. 在对话框里说「跑一下 sl_selftest」，应当 14/14

手动安装见包内 `INSTALL-WINDOWS.md`（Windows）与 `README.md`。

---

## 五、要如实写进列表的边界

- **需要 MATLAB R2022b+ 与 Simulink**。插件不含 MATLAB，也不代买授权。
- **需要一个开着的 MATLAB 会话**（插件会在你同意后拉起，或附加到你已开的那个）。
- **Windows 上若启用了「智能应用控制」**，未签名的 MATLAB DLL 会被拦；插件会自动退回不依赖信号观测器的读取方式（也能用），但系统日志里会有告警。要干净就得系统侧放行或给 DLL 签名。
- 一个 MATLAB 会话只服务一个 MCP 服务器。

---

## 六、素材清单

```
market/
├── MARKET.md              本文件
├── assets/
│   ├── hero.png           1600×800 主图（建 / 试 / 扫 三栏）
│   ├── case1-model.png    伺服顶层（7 块）
│   ├── case1-inside.png   plant 子系统内部（10 块，含双环反馈）
│   ├── case1-step.png     阶跃 + 6 s 负载扰动响应
│   ├── case2-model.png    子系统内的坏参数被标红
│   ├── case3-sweep.png    三种增益的响应对比
│   └── case3-trend.png    超调与负载跌落的取舍曲线
└── models/
    └── mkt_servo.slx      上述全部图由这个模型跑出
```

结构图都是 `sl_snapshot` 从模型直接导出的（含子系统内部），曲线是脚本算完 `exportgraphics` 出的，随时能重跑换成自己的模型。
