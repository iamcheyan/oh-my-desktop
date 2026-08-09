# Sumika Shell → labwc 适配可行性调查

调查日期：2026-08-08（协议/源码结论已用官方 master `0.20.1-18-g17ad8a7b` 逐条核实，
源码位于 `~/development/labwc`，官方 clone）
调查范围：当前 OMD 仓库（`~/development/OMD`）对 Hyprland 的全部依赖，逐项评估
迁移到 labwc（wlroots 系、Openbox 风格堆叠式 Wayland 合成器）的可行性；并对
**窗口缩略图** 能力做了专项协议调查。

> **2026-08-09 更新**：专项调查产出的 **overview 窗口缩略图已实现**（labwc 分支）——
> 自写 C daemon `sumika-overview-thumbnaild` + `grim -T` 抓帧 + `LabwcOverview` QML
> （§2.6）。win+tab 用 labwc 原生 windowSwitcher。本文档其余可行性结论不变。

参考：
- labwc 配置手册 `labwc-config(5)` — https://labwc.github.io/labwc-config.5.html
- labwc 动作手册 `labwc-actions(5)` — https://labwc.github.io/labwc-actions.5.html
- labwc 集成指南 — https://labwc.github.io/integration.html
- Quickshell `ToplevelManager` — https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ToplevelManager/
- Quickshell `ScreencopyView` — https://quickshell.org/docs/v0.2.0/types/Quickshell.Wayland/ScreencopyView/
- Quickshell issue #160（toplevel capture via ext-image-copy-capture）— https://github.com/quickshell-mirror/quickshell/issues/160

环境实测：本机 labwc **官方 0.20.1**（`/opt/labwc-upstream`，`-xwayland +nls +rsvg
+libsfdo`，wlroots 0.20.1）已运行，`wayland-info` 输出的协议清单见文末附录。

---

## 0. 现状：labwc 适配已存在（增量）

仓库里已有一套**增量** labwc 适配（不影响 Hyprland 会话）：

| 文件 | 作用 |
|---|---|
| `labwc/rc.xml` | 主配置：core/focus/desktops/theme/keyboard/mouse/windowSwitcher/windowRules |
| `labwc/environment` | 环境变量 |
| `labwc/autostart` | 会话启动脚本（bar、WAYLAND_DISPLAY 兜底探测、HiDPI scale） |
| `labwc/menu.xml` | 桌面右键根菜单 |
| `docs/features/labwc.md` | 已有 labwc 适配说明 |
| `Init.sh` `install_labwc_session()` | 安装 `sumika-labwc-upstream-session` + `sumika-labwc-upstream.desktop`（官方 0.20.1） |

键位镜像了 `hypr/bindings.lua` 中**合成器无关**的命令（`sumika-action` /
`sumika-launch-profile`），但 **bar 的 Hyprland 专属模块在 labwc 下仍不工作**
（`HyprlandData` 服务、overview、workspace 缩略图都依赖 hyprctl IPC）。

本次调查重点关注这些"还没适配"的部分，特别是 **overview 窗口缩略图**。

---

## 0.1 本机 labwc 二进制来源核实（官方 vs 魔改）

用户疑问：本机 labwc 是否自家魔改、与官方有区别。核实结果（2026-08-08）：

**现状**：本仓库只保留**官方未修改的 labwc 0.20.1** 构建（`/opt/labwc-upstream`，
版本串 `0.20.1 (-xwayland +nls +rsvg +libsfdo) wlroots-0.20.1`）。此前在用的
labwc-plus fork（`/usr/local/bin/labwc` → `/opt/labwc-plus`，版本串
`0.20.0-17-g6ee26963-dirty`，`6ee26963` 2026-06-15 含 3 个下游文档提交）**已清理**
（`/usr/local/bin/labwc`/`labwc-plus` 符号链接、`labwc.desktop`/`labwc-plus.desktop`/
`sumika-labwc.desktop` 会话入口、`/opt/labwc-plus` 整目录均已删除）。登录管理器现在
只有 `sumika-labwc-upstream.desktop` 一个 labwc 入口。

**0.20.0→6ee26963 与官方 0.20.1 的关系**（调查当时）：`6ee26963` 与官方 0.20.1 同日在
官方仓库内，差异仅为 0.20.1 的 NEWS/版本号两个提交（`4dab6994`/`529fc382`），无功能差异。

**关键功能均为官方 0.20.x 正式功能**（已逐项对照官方源码）：

| 能力 | 官方状态 | 证据 |
|---|---|---|
| toplevel capture（窗口缩略图协议） | ✅ 官方 0.20.0 就有 | PR #2968（2026-05-20 合入）→ 0.20.0（2026-05-25 发布）包含；`src/server.c` 有 `wlr_ext_foreign_toplevel_image_capture_source_manager_v1` / `wlr_ext_image_copy_capture_manager_v1` / `wlr_ext_output_image_capture_source_manager_v1` 注册；官方 master 完整保留 |
| ext-workspace（工作区协议） | ✅ 官方 0.20.0 就有 | `src/workspaces.c` 19 处 `ext_workspace`（0.20.0/0.20.1/master 一致） |
| ext-foreign-toplevel-list | ✅ 官方 0.20.0 就有 | `src/foreign-toplevel/ext-foreign.c` |
| xdg-toplevel-icon（窗口图标） | ✅ 官方 0.20.0 就有 | `src/scaled-buffer/scaled-icon-buffer.c`（tag contains 0.20.0/0.20.1） |
| session-lock / idle / screencopy | ✅ 官方 0.20.0 就有 | `ext_session_lock_manager_v1` 等 wlroots 注册 |

**本地实测协议 vs 官方注册协议一致**：wayland-info 列出的本地协议（
`ext_foreign_toplevel_image_capture_source_manager_v1`、`ext_image_copy_capture_manager_v1`、
`ext_workspace_manager_v1`、`xdg_toplevel_icon_manager_v1`、`zwlr_foreign_toplevel_manager_v1`
等）均能在官方源码对应实现中找到，**未发现魔改独有的协议**。

**本机编译选项**：`-xwayland +nls +rsvg +libsfdo`（官方 meson 可选特性开关）——
无 XWayland 是编译配置，非源码改动。

**官方 master 与本地编译点的差距**：本地 = 0.20.1 发布当日 commit；之后 master 仅有
零碎维护（样式、翻译、一个 `xwayland: fix missing panel icon` 修复、一个循环结束焦点
恢复修复等），无 toplevel capture 相关改动。

> ✅ **已用官方 master 源码实测确认**（2026-08-08，`~/development/labwc`，
> `0.20.1-18-g17ad8a7b`）：master 相对 0.20.1 的 18 个 commit 全部为样式/翻译/注释/
> 零碎修复（唯一行为相关为 `d36348e8 output.c: Force the initial modeset`），
> **无 capture / workspace / icon 相关改动**；toplevel capture 的捕获范围已逐行核实
> （§2.2），`ext_foreign_toplevel_image_capture_source_manager_v1` 注册与 0.20.1 一致。
> 官方 0.20.1 二进制已编译并安装至 `/opt/labwc-upstream`（独立于 fork），实测协议清单
> 与 fork 仅差 `wp_drm_lease_device_v1`（wlroots 后端差异，非 labwc 源码改动）。

> ⚠️ **发行版差异提醒**：Fedora/大多数发行版仓库里的 labwc 是 **0.9.x**（本机
> `dnf` 源 0.9.6-1.fc44），**没有** toplevel capture / ext-workspace / 窗口图标协议。
> 若网上查到的"labwc 无缩略图"说法来自 0.9.x 文档或发行版包，那是版本差；**官方 git
> 的 0.20.x 才具备这些能力**。Sumika 的 labwc 适配前提是自编译 0.20.1+（本机已满足）。

**结论**：窗口缩略图、ext-workspace 等能力是官方 0.20.x 功能，非本机魔改独有。
`-dirty` 的未提交改动内容未知（源码已不在），但从协议面与官方无差异；若需精确 diff，
需找回当时的源码树。

---

## 1. Hyprland 依赖清单 → labwc 可行性

难度评级：`easy` = wlroots/labwc 有对等替代；`medium` = 需重写到不同 IPC/协议；
`hard` = 核心功能需深度重做；`impossible` = Hyprland 独有能力，堆叠式合成器无对等物。

### 1.1 QML / Quickshell.Hyprland 服务（最深耦合）

约 24 个 QML 文件 `import Quickshell.Hyprland`。`Quickshell.Hyprland` 模块暴露
`Hyprland` 单例（`focusedMonitor`/`focusedWorkspace`/`monitorFor`/`dispatch`/
`monitors`/`rawEvent`）、`HyprlandMonitor`/`HyprlandWorkspace`/`HyprlandToplevel`
类型、`HyprlandFocusGrab`。这是整个适配最深的耦合点。

| 服务文件 | 作用 | Hyprland API | 迁移难度 |
|---|---|---|---|
| `services/HyprlandData.qml` | 工作区/窗口/显示器数据模型核心；轮询 `hyprctl -j clients/monitors/workspaces/activewindow`；构建 overview 模型；注册为 `workspace.v1` 服务 | `Quickshell.Hyprland` + `hyprctl -j` | **hard** — labwc 无 IPC；需 `wlr-foreign-toplevel` + `wlr-output-management` 或合成器无关的 Quickshell.Toplevel 模型 |
| `services/HyprlandXkb.qml` | 活动键盘布局（power-indicator XKB 徽章） | `hyprctl -j devices` + `rawEvent` | medium — 无标准 wlroots API；需另寻 xkb 读取机制 |
| `services/Hyprsunset.qml` | 夜灯/色温 | `hyprctl hyprsunset …` + hyprsunset 二进制 | medium — 换 `wlsunset`/`gammastep`（CLI/SIGHUP 控制） |
| `services/WorkspaceOrder.qml` | 每显示器可视化工作区排序持久化 | `HYPRLAND_INSTANCE_SIGNATURE` | medium — 逻辑通用但绑定 Hyprland 数字工作区 ID |
| `services/GlobalFocusGrab.qml` | 弹窗外部点击关闭 | `HyprlandFocusGrab` QML 类型 | medium — `Quickshell.Hyprland` 独有类型 |
| `services/Idle.qml` | 空闲抑制 | `Persistent.isNewHyprlandInstance` | easy — `IdleInhibitor` 是 Wayland 标准（`idle-inhibit-v1`） |
| `services/LockService.qml` | 锁屏路由 | 无直接依赖 | easy |
| `services/Brightness.qml` | 亮度；用 `Hyprland.focusedMonitor` 选屏 | `Hyprland.focusedMonitor` | medium — 需等价"聚焦输出"来源 |
| `GlobalStates.qml` | 全局状态单例 | `import Quickshell.Hyprland` | medium |

使用 `Hyprland` 单例的模块（节选）：
- `modules/bar/*` — `Hyprland.focusedMonitor`/`monitorFor`
- `modules/overview/*` — `Hyprland.dispatch`、`HyprlandMonitor`、`ToplevelManager` + `HyprlandToplevel.address`
- `modules/clipboard/*` — `hyprctl cursorpos -j`、`hyprctl monitors -j`
- `modules/launcher/.../RunningApps.qml` — `hyprctl clients -j`
- `modules/settings/*` — `hyprctl reload`、`hyprctl -j monitors`
- `apps/sumika-bar/shell.qml` — `Hyprland.focusedMonitor` 通知定位

### 1.2 工作区 / 窗口管理动作

| 动作 | Hyprland 实现 | labwc 可行性 |
|---|---|---|
| 切换工作区 | `Hyprland.dispatch("hl.dsp.focus({workspace=N})")` | medium — `GoToDesktop`（rc.xml 键位） |
| 移动窗口到工作区 | `hl.dsp.window.move({workspace=N})` | medium — `SendToDesktop` |
| 移动整个工作区到显示器 | `hl.dsp.workspace.move({monitor})` | **hard** — labwc 无此动作 |
| 像素级移动窗口 | `hl.dsp.window.move({x,y,window=address})` | **hard** — 无 labwc IPC |
| 关闭窗口 | `hl.dsp.window.close({window=address})` | medium — `A-F4` / `wlr-foreign-toplevel` close |
| 聚焦窗口 | `hl.dsp.focus({window=address})` | medium — `wlr-foreign-toplevel` activate |
| 聚焦显示器 | `hl.dsp.focus({monitor=name})` | **hard** — labwc 无按输出聚焦动作 |
| 跳到空工作区 | `hl.dsp.focus({workspace="empty"})` | **hard** — 依赖 Hyprland 动态空工作区 |
| 特殊/scratchpad 工作区 | `hl.dsp.workspace.toggle_special` | **impossible** — Hyprland 独有 |
| 平铺（split/pseudo/swap/resize/group） | `hl.dsp.layout`/`window.swap`/`group.*` | **impossible** — labwc 纯堆叠 |
| 全屏/最大化 | `hl.dsp.window.fullscreen` | medium — `ToggleFullscreen`/`ToggleMaximize` |
| 给窗口发合成按键（粘贴） | `hl.dsp.send_key_state({window})` | ⚠️ 已适配 | Hyprland 可精确按窗口注入；wlroots 无对等，sasayaki 改用 `zwlr_foreign_toplevel_manager_v1` 探测焦点窗口 + wtype 虚拟键盘 / kitty 原生粘贴（2026-08-08 实测可用，见 `docs/features/labwc.md`） |

### 1.3 Shell 脚本

| 脚本 | Hyprland 依赖 | 难度 |
|---|---|---|
| `omarchy-hyprland-monitor-watch` | socket2.sock 事件 + `hyprctl reload` | medium — udev DRM 事件 / wlr-output-management 监听 |
| `omarchy-hyprland-window-pop` | `hyprctl activewindow` + `hl.dsp.window.{pin,float,resize,move,center}` | hard — labwc 堆叠无 pin 语义 |
| `omarchy-hyprland-monitor-scaling-cycle` | `hyprctl monitors -j` + `hl.monitor` | medium — `wlr-randr --scale` |
| `omarchy-hyprland-monitor-internal(-mirror)` | `hyprctl monitors` + `hl.monitor mirror` | medium — `wlr-randr --enable/--disable`/`--mirror-of` |
| `omarchy-hyprland-window-gaps-toggle` | toggle .lua + reload | **impossible** — labwc 无 gaps |
| `omarchy-hyprland-window-single-square-aspect-toggle` | `hl.config layout.single_window_aspect_ratio` | **impossible** — 平铺布局专属 |
| `omarchy-hyprland-window-transparency-toggle` | `hyprctl setprop` | hard — labwc 无按窗口不透明度 |
| `omarchy-hyprland-workspace-layout-toggle` | `hyprctl activeworkspace` + `hl.workspace_rule` | **impossible** — 无平铺布局 |
| `omarchy-hyprland-window-close-all` | `hyprctl clients -j` + `hl.dsp.window.close` | medium — `wlr-foreign-toplevel` 逐个 close |
| `omarchy-launch-or-focus` | `hyprctl clients -j` + `dispatch focuswindow` | medium — `wlr-foreign-toplevel` 枚举/激活 |
| `omarchy-system-lock` | `hyprctl switchxkblayout`（仅布局重置） | easy — 锁屏走 `WlSessionLock`，通用 |
| `omarchy-system-logout` | `hyprctl dispatch exit` + `hyprctl instances` | medium — `labwc --exit` / kill 进程 |
| `bin/sumika-session`（1772 行） | 大量 `hyprctl -j` + `hl.dsp.*` | **hard** — 整个恢复引擎需重写 |
| `bin/sumika-display-config` | `wlr-randr --json` 为主 + `hyprctl -j monitors` 补字段 | easy — `wlr-randr` 已是主路径 |
| `clipboard/bin/sumika-*-paste` | `hyprctl -j activewindow` + `hl.dsp.send_key_state` | ⚠️ 可参考 | 按窗口注入无 wlroots 对等；sasayaki 已给出 labwc 可行的替代路径（焦点探测 + wtype/kitty 原生），这些脚本可照搬 |
| `bin/sumika-restart` | `hyprctl reload` + `configerrors`（已条件化） | easy — guard 已存在 |

### 1.4 Hyprland 配置层（`hypr/*.lua`）

整个合成器配置是 Hyprland Lua，labwc 用 `labwc/rc.xml`（已建）整体替代。
- `helpers.lua`（`o.bind`/`o.window`/`o.launch` DSL）→ **hard**，Hyprland-Lua 独有。
- `envs.lua` → easy（`labwc/environment` 已镜像，`XDG_CURRENT_DESKTOP=labwc`）。
- `monitors.lua`（动态 scale）→ medium（autostart 已用 `wlr-randr` 处理内部屏）。
- `bindings/*` → 大量已镜像到 rc.xml；**平铺/group/scratchpad/resize 无 labwc 对等**。
- `looknfeel.lua`（装饰/gaps/blur/动画/dwindle/scrolling）→ hard/impossible，labwc theme 只管颜色/边框。

### 1.5 空闲 / 锁屏

| 组件 | Hyprland | labwc 可行性 |
|---|---|---|
| 空闲守护 | `hypridle`（`hypr/hypridle.conf`） | easy — 换 `swayidle`（wlroots） |
| 锁屏实现 | Quickshell `WlSessionLock`（`ext-session-lock-v1`，在 bar 进程内） | easy — Wayland 标准，labwc 支持 |
| `omarchy-system-lock` 预锁 | 仅 `hyprctl switchxkblayout` 是 Hyprland 专属 | easy — 去掉该调用 |
| 空闲抑制 | `Quickshell.Wayland IdleInhibitor`（`idle-inhibit-v1`） | easy — labwc 支持 |

### 1.6 其他 Hyprland 独有工具

| 工具 | 用途 | 迁移 |
|---|---|---|
| `hyprpicker` | 取色 | easy — `grim -g "$(slurp -p)"` 像素采样 |
| `hyprsunset` | 夜灯 | medium — `wlsunset`/`gammastep` |
| `xdg-desktop-portal-hyprland` | 截屏共享 portal | easy — `xdg-desktop-portal-wlr` |
| `hyprpaper` | 壁纸 | n/a — 已用 `swaybg`（通用） |
| `hyprctl`（通用 IPC） | 工作区/窗口/显示器查询与派发 | **hard** — labwc 无对等，逐用例替换为 wlr 协议 |
| `HYPRLAND_INSTANCE_SIGNATURE` | 实例标识 | easy — 去掉/guard |
| 事件 socket `.socket2.sock` | 显示器热插拔 | medium — udev / wlr-output-management |

---

## 2. 窗口缩略图专项调查（用户关注点）

用户目标：在 labwc 下 overview 显示**当前工作区每个窗口的缩略图**，win+tab 切换
**当前工作区**的窗口。需要确认 labwc 是否提供窗口缩略图能力。

### 2.1 labwc 协议实测（已运行）

本机 labwc 0.20.1 已运行（官方构建，`/opt/labwc-upstream`），`wayland-info` 列出的相关协议：

```
ext_foreign_toplevel_image_capture_source_manager_v1   v1   ← 顶层窗口图像捕获源
ext_image_copy_capture_manager_v1                       v1   ← 图像拷贝捕获
ext_output_image_capture_source_manager_v1              v1
zwlr_foreign_toplevel_manager_v1                         v3   ← 窗口列表/控制
ext_foreign_toplevel_list_v1                             v1   ← 新版窗口列表
zwlr_screencopy_manager_v1                               v3   ← 输出截屏
ext_session_lock_manager_v1                              v1
ext_idle_notifier_v1                                     v2
zwp_idle_inhibit_manager_v1                              v1
xdg_toplevel_icon_manager_v1                             v1   ← 窗口图标
```

**关键结论：labwc 0.20 已提供窗口缩略图所需的全部 Wayland 协议。**

### 2.2 窗口缩略图协议栈

跨合成器的标准方案（非 Hyprland 专属）：

```
ext_foreign_toplevel_list_v1          ← 枚举窗口，拿到 handle
        │
        └── ext_foreign_toplevel_handle_v1
                │
                └── ext_foreign_toplevel_image_capture_source_manager_v1
                        │  create_source(source, toplevel_handle)
                        └── ext_image_capture_source_v1
                                │
                                └── ext_image_copy_capture_v1
                                        │  capture → wl_buffer / DMA-BUF
                                        └── 像素
```

- `wlr-foreign-toplevel-management`：只给窗口**元数据**（title/app_id/状态/激活/关闭），
  **不给像素**。
- `ext-foreign-toplevel-image-capture-source` + `ext-image-copy-capture`：把某个
  toplevel handle 变成可捕获的图像源，拷贝帧到客户端 buffer。这是按窗口取像素的
  标准方案。
- `hyprland-toplevel-export-v1`：Hyprland 专属的等价物，非便携。

labwc 0.20 的 toplevel capture 支持是**初始/部分**的（2026-05-20 合入，PR #2968），
但按官方源码（`src/server.c` `handle_toplevel_capture_request`、`src/view.c`、
`src/xdg-popup.c`、`src/xwayland.c`、`src/xdg.c`）逐行核实，实际支持范围：

- **捕获内容** = 每窗口独立的捕获 scene（`view->capture.scene`，`view.c:2486`
  `wlr_scene_create()`），**包含** xdg 弹窗（`xdg-popup.c:173` 把 popup 加入
  capture.scene）、subsurface（`xwayland.c:784` 加入）、xdg surface（`xdg.c:1087` 加入）。
- **已知限制**：`capture.scene->restack_xwayland_surfaces = false`（`view.c:2487`，
  XWayland surface 不参与重堆叠）；非托管窗口（未初始化 `view->capture`）不可捕获。
- **不含服务端装饰（SSD）**，与可见堆叠位置/工作区无关。

纯 Wayland 普通应用窗口可用。实测可用 `grim -T <toplevel-identifier>`（需支持
toplevel capture 的 grim）。

### 2.3 Quickshell 侧的阻塞（真正的瓶颈）

Quickshell 提供两个独立能力：

| Quickshell 组件 | 作用 | 协议 |
|---|---|---|
| `ToplevelManager` | 列出/控制窗口（元数据） | `zwlr_foreign_toplevel_management_v1` |
| `ScreencopyView` | 显示捕获的像素 | 取决于 captureSource 类型 |

`ScreencopyView.captureSource` 接受：
- `null` — 清空
- `ShellScreen`（显示器）— 需 `wlr-screencopy-unstable` 或 `ext-image-copy-capture-v1` + `ext-capture-source-v1`
- `Toplevel`（窗口）— **需 `hyprland-toplevel-export-v1`**

**问题**：Quickshell 当前（0.2.1，本机已装）把 toplevel 捕获**只**路由到
`hyprland-toplevel-export-v1` 后端；`ext-image-copy-capture` 后端目前**只处理输出捕获**，
不创建 toplevel 源。Quickshell issue #160（2025-07-31 开，2026-06-27 仍 open）正是要
"用 ext_image_copy_capture 实现 toplevel 捕获"，以便在 Hyprland 之外的合成器上工作。
维护者 outfoxxed 回复"还需更多 ext-toplevel 关联工作，但 icc for toplevels 从那里开始很简单"。

**因此**：尽管 labwc 0.20 协议齐全，当前 Quickshell 0.2.1 的 `ScreencopyView` 在 labwc
下**无法捕获窗口缩略图**——因为它只认 Hyprland 专属的 `hyprland-toplevel-export-v1`，
而 labwc 不实现该协议。

> ✅ `labwc/rc.xml` 的 windowSwitcher 注释**已按官方代码修正**：labwc 0.20+ 通告
> `ext_foreign_toplevel_image_capture_source_manager_v1`，但 Quickshell 的
> `ScreencopyView` 尚未消费该协议做 toplevel 捕获（issue #160），因此原生
> 合成器侧 OSD 是当前可用的缩略图路径。

### 2.3.1 特权协议白名单 `<allowedInterfaces>`（官方源码核实）

`src/config/rcxml.c` 的 `parse_privileged_interface()` 定义**特权协议白名单**，受
`rc.xml` 的 `<allowedInterfaces>` 控制：默认 `rc.allowed_interfaces = UINT32_MAX`
（`rcxml.c:1536`，全部允许）；显式配置后从 0 开始累积（`rcxml.c:1444`）。

| 协议 | 在白名单？ | 影响 |
|---|---|---|
| `ext_foreign_toplevel_image_capture_source_manager_v1` | ❌ **不在** | 不受白名单限制，任何客户端始终可见 → 缩略图捕获源始终可用 |
| `ext_image_copy_capture_manager_v1` | ✅ 在 | 配置白名单后被拒 → 拷贝捕获不可用 |
| `ext_foreign_toplevel_list_v1` / `zwlr_foreign_toplevel_manager_v1` | ✅ 在 | 配置白名单后被拒 → 窗口列表不可用 |
| `zwlr_screencopy_manager_v1` / `ext_workspace_manager_v1` / `ext_session_lock_manager_v1` | ✅ 在 | 配置白名单后被拒 |

**含义**：Sumika 的 labwc 适配依赖 foreign-toplevel / image-copy-capture / screencopy
等协议，**不要**在 `labwc/rc.xml` 配 `<allowedInterfaces>`（当前未配，保持默认全允许）。
即使配了，窗口缩略图**捕获源**协议仍可用，但拷贝帧的 `ext-image-copy-capture` 会被拒。

### 2.4 labwc 原生窗口切换器（合成器侧，已可用）

labwc 自带 `windowSwitcher` 是**合成器侧** OSD，可直接访问窗口 buffer，无需客户端协议。
当前 `labwc/rc.xml` 已配置：

```xml
<windowSwitcher preview="yes" outlines="yes">
  <osd show="yes" style="thumbnail" output="all" thumbnailLabelFormat="%T" />
</windowSwitcher>
...
<keybind key="W-Tab">
  <action name="NextWindow" workspace="current" />
</keybind>
<keybind key="W-S-Tab">
  <action name="PreviousWindow" workspace="current" />
</keybind>
```

- `osd style="thumbnail"`：labwc 原生 OSD 显示**真实窗口缩略图**（合成器侧渲染）。
- `NextWindow`/`PreviousWindow` + `workspace="current"`：切换**当前工作区**的窗口。
- 鼠标点击 OSD 项即选；按住键期间键盘循环。

**结论：用户想要的"win+tab 切换当前工作区窗口 + 缩略图"已通过 labwc 原生窗口切换器
实现，开箱可用。** 这是合成器侧方案，不依赖 Quickshell，不受 issue #160 阻塞。

### 2.5 当前 Quickshell overview 的缩略图机制

`modules/overview/OverviewWindow.qml` 用 `ScreencopyView { captureSource: toplevel }`
为每个窗口渲染实时缩略图；`toplevel` 来自 `ToplevelManager.toplevels`，再通过
`HyprlandToplevel.address` 与 `HyprlandData`（`hyprctl clients -j`）交叉引用拿到
工作区/几何/位置。模型按**工作区分组**，每个工作区 tile 内按真实几何摆放各窗口缩略图。

在 labwc 下这套原本有三处断点：

1. **像素捕获**：~~`ScreencopyView` toplevel 捕获走 `hyprland-toplevel-export-v1` →
   labwc 不支持 → **无缩略图**（issue #160 解锁后可用 labwc 0.20 协议）。~~
   **✅ 已实现**：labwc 分支用自写缩略图 daemon（§2.6）绕开 Quickshell 限制——
   `grim -T <identifier>` 按窗口抓帧（内部走 `ext-foreign-toplevel-image-capture-source` +
   `ext-image-copy-capture`），PNG 落盘后 QML `Image` 直接显示。实测本机
   `grim -T` 对 Firefox/kitty 窗口均可出完整 PNG。
2. **窗口→工作区归属**：`wlr-foreign-toplevel-management` / `ext-foreign-toplevel-list`
   **都不暴露窗口属于哪个 desktop**，无法做"当前工作区窗口"过滤。
   **✅ 已近似实现**：用**激活历史归属**——切桌面后经 `ext-workspace` 事件记录
   当前激活桌面，窗口的 workspace 归属取"最近一次激活时所在的桌面"；新 daemon
   启动时的未知归属窗口（`workspace==""`）在 UI 上归当前工作区显示并带 `?` 角标。
3. **窗口几何**：`hyprctl clients -j` 给每个窗口的 x/y/w/h；labwc 无 IPC，
   无法拿到窗口像素坐标（无法按真实几何摆放缩略图，也无法做 drag-to-reorder）。
   **已降级**：labwc 分支 overview 用**网格布局**（非真实几何），不做 drag-to-reorder。

### 2.6 labwc 分支实现：thumbnaild + LabwcOverview（路径 2，已落地）

采用 §4 路径 2（自写 Wayland 客户端）并做简化：抓帧用现成的 `grim -T`
（`-T <identifier>` 与 `-o` 互斥，只认 identifier 形式），而非直连
`ext-image-copy-capture` 拷贝 DMA-BUF——工程量和调试成本大幅降低，且协议面相同。

**架构**：

```
LabwcOverview.qml  (QML, labwc 分支专用 UI)
      │  JSON 行协议 (unix socket)
      ▼
sumika-overview-thumbnaild  (C daemon, 只存在于 labwc 会话)
      │  直连 wayland
      ▼
ext_foreign_toplevel_list_v1  → 枚举窗口 + 32 位 hex identifier
ext_workspace_manager_v1      → 工作区列表 + active 状态 + activate 切换
zwlr_foreign_toplevel_manager_v1 v3 → activate(窗口聚焦)/close
grim -T <identifier>          → 每窗口抓帧 → PNG → $STATE_HOME/overview-thumbs/
```

**源码位置**：`quickshell/modules/overview/thumbnaild/`（独立原生目录——OMD 仓库
首个 C 代码；`Makefile` + `thumbnaild.c` + 三个 wayland 协议 xml 生成的 C 头）。

**桥协议**（unix stream socket，`$SUMIKA_SHELL_RUNTIME_DIR/overview-thumbnaild.sock`，
0600，JSON 行协议）：

- daemon → QML 广播：`{"type":"snapshot","seq":N,"activeWorkspace":"2",
  "workspaces":[{"name":"3","active":false},…],
  "windows":[{"identifier":"<32hex>","title":…,"app_id":…,"workspace":"1",
  "active":true,…}]}`
- QML → daemon 命令：`{"cmd":"activate-workspace","name":"2"}`（ext-workspace
  `activate` + `commit`，事务式）/ `{"cmd":"activate-window","identifier":"<32hex>"}`
  （zwlr activate，labwc 一次请求完成"切桌面+聚焦"）/ `{"cmd":"refresh"}`

**QML 侧**（`modules/overview/LabwcOverview.qml` + `LabwcOverviewBridge.qml`）：
独立简化 UI，不复用深度耦合 Hyprland 的 `OverviewWidget`；保留 `IpcHandler "overview"`
接口（`bin/sumika-overview` toggle/open/close/workspacesToggle 不变）；
`shell.qml` 按 `SystemInfo.desktopEnvironment` 条件加载——`labwc` → LabwcOverview，
其余 → 旧 Overview（Hyprland 行为不变）。

**labwc 判定**：daemon 启动时只探测 `ext_foreign_toplevel_list_v1` global——
有才继续（Hyprland 不实现该协议 → daemon 立即退出，Hyprland 会话零影响）。
**会话接入**：`labwc/autostart` 在 bar 之前拉起 daemon（§文档 features/labwc.md），
labwc 会话登录即生效，无需手动启动。

**已知取舍**：
- 缩略图为**静态帧**（grim 抓帧时点），非实时画面；靠 debounce 250ms + 事件驱动刷新
  （toplevel 事件、工作区切换、`refresh` 命令）。
- 窗口→桌面归属是激活历史近似（见 §2.5 断点 2），不是精确协议映射。
- 触发 grim 抓帧会短暂占用窗口捕获源；**并发抓帧过多时 wlroots 的
  `ext_foreign_toplevel_image_capture_source` 只服务一个客户端**，多余的 grim 会
  hang——daemon 每次刷新最多 spawn 一个 grim（`capture_in_flight` 守卫），
  且 grim 退出由 SIGCHLD 驱动转正临时文件。

**实现期修掉的三个关键 bug**（2026-08-09）：
1. **qmldir singleton**：`LabwcOverviewBridge` 必须 `singleton` 注册 + 文件头
   `pragma Singleton`，否则 QML 值引用拿到类型对象，实例属性 `undefined` 抛
   `TypeError`。
2. **daemon grim 临时文件不转正**：`signal(SIGCHLD, SIG_DFL)` 下 grim 退出无信号
   驱动 `reap_children`，tmp→png rename 只发生在下次事件触发的刷新——空闲桌面
   永久卡住。改为 SIGCHLD handler 置标志位，主循环 poll 前 reap。
3. **daemon 主循环卡死**（`read(listen_fd)` 阻塞）：两个叠加根因——(a) poll 后
   accept 的新 client 使 `fds[2+i]` 读到**未初始化栈内存**（revents 垃圾值可带
   `POLLIN`，随后 `read()` 阻塞在无数据的 fd）；(b) `close_client` 的 memmove 压缩
   数组后，后续循环项的 fds revents 与 clients 错位。修复：client 输入每 poll 轮
   至多处理一个，且 `idx >= nfds` 直接 break。

---

## 3. 可行性总表

| 功能 | Hyprland | labwc 可行性 | 说明 |
|---|---|---|---|
| **bar 主体（layer-shell）** | Quickshell.Wayland | ✅ 可用 | `wlr-layer-shell`，labwc 原生支持 |
| **时钟/托盘/音频/WiFi/通知** | 通用服务 | ✅ 可用 | 与合成器无关 |
| **工作区指示器** | `Hyprland.focusedWorkspace` + `hyprctl workspaces -j` | ⚠️ 需重写 | 用 `ext-workspace` 协议（Waybar 已用）；Quickshell 需 workspace 模型 |
| **窗口缩略图（Quickshell overview 内）** | `ScreencopyView` + `hyprland-toplevel-export-v1` | ✅ **已实现（labwc 分支）** | 自写 `sumika-overview-thumbnaild` daemon + `grim -T` 抓帧，PNG 桥进 `LabwcOverview`（§2.6）；Hyprland 会话不受影响 |
| **窗口缩略图（labwc 原生 OSD）** | n/a | ✅ 已可用 | `windowSwitcher osd style="thumbnail"`，合成器侧渲染 |
| **win+tab 切换当前工作区窗口** | `OverviewSwitchingController` | ✅ 已可用（原生） | rc.xml 已绑 `W-Tab`→`NextWindow workspace="current"`，带缩略图 OSD |
| **overview（工作区 tile + 窗口缩略图）** | `HyprlandData` + `ScreencopyView` | ✅ **已实现（labwc 分支）** | `LabwcOverview`：缩略图网格 + 工作区 chips + 搜索 + 点击聚焦（§2.6）；归属用激活历史近似，几何用网格布局 |
| **overview 搜索** | `hyprctl clients -j` 过滤 | ⚠️ 可降级 | 用 `ToplevelManager`（元数据可用）做无缩略图的列表搜索 |
| **窗口拖拽到工作区 / 像素移动** | `hl.dsp.window.move` | ❌ 不可能 | labwc 无 IPC 做像素级窗口移动 |
| **平铺/gaps/scratchpad/group** | `hl.dsp.*` 平铺派发 | ❌ 不可能 | labwc 纯堆叠 |
| **夜灯** | `hyprsunset` | ✅ 可用 | `wlsunset`/`gammastep` |
| **锁屏** | `WlSessionLock`（`ext-session-lock-v1`） | ✅ 可用 | Wayland 标准，labwc 支持 |
| **空闲抑制** | `IdleInhibitor`（`idle-inhibit-v1`） | ✅ 可用 | labwc 支持 |
| **取色器** | `hyprpicker` | ✅ 可用 | `grim -g "$(slurp -p)"` |
| **截屏** | `grim`/`slurp`/`wf-recorder` | ✅ 可用 | 已是 wlroots 工具 |
| **壁纸** | `swaybg` | ✅ 可用 | 已通用 |
| **显示器热插拔监听** | socket2.sock 事件 | ⚠️ 需重写 | udev DRM / wlr-output-management 监听 |
| **会话保存/恢复** | `sumika-session`（大量 hyprctl） | ❌ 难 | 整个引擎需重写 |
| **launch-or-focus** | `hyprctl clients -j` | ⚠️ 可改 | `wlr-foreign-toplevel` 枚举/激活 |
| **XKB 布局徽章** | `hyprctl -j devices` | ⚠️ 需重写 | 无标准 wlroots API |
| **按窗口合成按键（智能粘贴）** | `hl.dsp.send_key_state` | ⚠️ 已适配 | labwc 无按窗口注入；sasayaki 用 `zwlr_foreign_toplevel_manager_v1` 焦点探测 + wtype/kitty 原生粘贴（2026-08-08 实测） |
| **按窗口不透明度** | `hyprctl setprop` | ❌ 不可能 | labwc 无此属性 |

---

## 4. 针对用户两个具体目标的结论

### 目标 A：overview 显示当前工作区每个窗口的缩略图

| 路径 | 可行性 | 说明 |
|---|---|---|
| **复用 Quickshell overview + ScreencopyView** | ❌ 阻塞上游 | Quickshell 0.2.1 toplevel 捕获只走 `hyprland-toplevel-export-v1`；labwc 不支持。需 Quickshell issue #160 落地后，才能用 labwc 0.20 的标准协议。 |
| **等 Quickshell #160** | ⏳ 中期 | #160 一旦实现，`ScreencopyView { captureSource: toplevel }` 即可在 labwc 0.20+ 出缩略图。仍需解决"窗口→工作区归属"和"窗口几何"两个元数据断点。 |
| **自写 Wayland 缩略图客户端喂 QML** | ✅ **已实现** | **`sumika-overview-thumbnaild` daemon（C，§2.6）**：直连 `ext-foreign-toplevel-list` 枚举 + `grim -T <identifier>` 抓帧 → PNG 桥进 QML。只检测到 labwc 的 `ext_foreign_toplevel_list_v1` 才启用，Hyprland 下自动退出。labwc 分支 overview（`LabwcOverview.qml`）已可用：缩略图网格、工作区 chips、搜索过滤、点击缩略图聚焦。窗口→桌面归属用激活历史近似。 |
| **降级：无缩略图的窗口列表 overview** | ✅ 现在 | `ToplevelManager`（`wlr-foreign-toplevel`，labwc 已支持）给 appId/title/图标，可做点击激活/关闭的列表式 overview。但"当前工作区"过滤无协议支撑（见下）。 |

> "当前工作区"过滤的硬限制：`wlr-foreign-toplevel-management` 与
> `ext-foreign-toplevel-list` **都不暴露窗口属于哪个 desktop**。labwc 切桌面只是
> 隐藏/显示窗口，foreign-toplevel 列表仍含全部桌面窗口，无字段可过滤。
> **已采用近似**（§2.6）：激活历史归属——窗口的 workspace 取"最近一次激活时
> 所在桌面"，未知归属窗口归当前工作区显示并带 `?` 角标。

### 目标 B：win+tab 切换当前工作区的窗口

| 路径 | 可行性 | 说明 |
|---|---|---|
| **labwc 原生 windowSwitcher** | ✅ 已实现 | rc.xml 已绑 `W-Tab`→`NextWindow workspace="current"`，`osd style="thumbnail"` 显示真实缩略图（合成器侧，不受 Quickshell 阻塞）。这正是用户要的。 |
| **Quickshell 内 win+tab 循环** | ⚠️ 降级 | 可用 `ToplevelManager` 做无缩略图循环，但"当前工作区"过滤受同一协议限制。原生方案更优。 |

**建议（已执行）**：win+tab 用 labwc 原生窗口切换器（已配好，开箱即用，带缩略图）。
overview 的窗口缩略图**已用自写客户端落地**（§2.6：thumbnaild daemon + `grim -T`
+ `LabwcOverview`）——无需再等 Quickshell #160。

---

## 5. 建议的适配优先级

1. **立即可做**（无上游阻塞，低风险）：
   - win+tab → 已用 labwc 原生 windowSwitcher（已配）。
   - bar 通用模块（时钟/托盘/音频/WiFi/通知）→ 已可用。
   - 取色器→`grim`+`slurp`、夜灯→`wlsunset`、锁屏→`WlSessionLock`、idle→`swayidle`。
   - `sumika-restart`/`sumika-doctor`/`sumika-display-config` 去掉 hyprctl 硬依赖。

2. **需中等重写**（无缩略图需求时可推进）：
   - 工作区指示器 → `ext-workspace` 协议（需 Quickshell workspace 模型或自建）。
   - `launch-or-focus` → `wlr-foreign-toplevel` 枚举/激活。
   - 显示器热插拔 → udev / wlr-output-management 监听。

3. **已实现（2026-08-09）**：
   - overview 窗口缩略图 → **自写客户端已落地**（§2.6：thumbnaild daemon + `grim -T`
     + `LabwcOverview`）。无需等 Quickshell #160。
   - "当前工作区窗口"过滤 → 激活历史归属近似（无协议字段，见 §2.5 断点 2）。
   - 会话保存/恢复（`sumika-session`）→ 整个引擎重写（未动）。

4. **不可能 / 放弃**：平铺/gaps/scratchpad/group、按窗口不透明度、特殊工作区、
   单窗口宽高比 toggle、workspace-layout toggle。（智能粘贴已适配——见 §1.2/§3。）

---

## 附录 A：labwc 0.20.1 实测协议清单（wayland-info 节选）

```
xdg_toplevel_icon_manager_v1                  v1
zwlr_screencopy_manager_v1                     v3
ext_image_copy_capture_manager_v1              v1
ext_output_image_capture_source_manager_v1     v1
ext_foreign_toplevel_image_capture_source_manager_v1   v1   ← 窗口缩略图源
ext_idle_notifier_v1                           v2
zwp_idle_inhibit_manager_v1                    v1
zwlr_foreign_toplevel_manager_v1              v3
ext_foreign_toplevel_list_v1                   v1
ext_session_lock_manager_v1                     v1
```

labwc 版本：`0.20.1 (-xwayland +nls +rsvg +libsfdo) wlroots-0.20.1`
（**官方未修改构建**，位于 `/opt/labwc-upstream`，编译为 `-xwayland`，X11-only
应用不可用；需 XWayland 要重编译。）

> 此前在用的 labwc-plus fork（`0.20.0-17-g6ee26963-dirty`）已整体清理（§0.1），
> 现登录管理器只有 `sumika-labwc-upstream.desktop` 一个 labwc 入口。官方 0.20.1
> 与 fork 实测协议清单**完全一致**，唯一差异是 fork 多通告
> `wp_drm_lease_device_v1`（wlroots 后端差异，非 labwc 源码改动）；官方 0.20.1
> 通告窗口缩略图所需全部协议。

## 附录 B：窗口缩略图协议对照

| 协议 | 作用 | labwc | Quickshell 用途 |
|---|---|---|---|
| `wlr-foreign-toplevel-management` | 窗口列表/控制（元数据，无像素） | ✅ v3 | `ToplevelManager`（可用） |
| `ext-foreign-toplevel-list` | 新版窗口列表（元数据，无像素） | ✅ v1 | 同上（新版）；**thumbnaild 枚举用**（拿 32 位 hex identifier） |
| `ext-foreign-toplevel-image-capture-source` | toplevel→图像源 | ✅ v1 | **未用于 toplevel**（#160 open）；thumbnaild 借道 `grim -T` 消费 |
| `ext-image-copy-capture` | 从源拷贝帧到 buffer | ✅ v1 | 仅用于**输出**捕获；`grim -T` 内部走它 |
| `wlr-screencopy` | 输出截屏 | ✅ v3 | `ScreencopyView` 监视器捕获 |
| `hyprland-toplevel-export` | Hyprland 专属 toplevel 捕获 | ❌ 不支持 | `ScreencopyView` toplevel 捕获（仅 Hyprland） |
| `ext-workspace` | 工作区列表/切换（事务式，需 `commit`） | ✅ v1 | Quickshell 未建模；thumbnaild 消费（`activate` 请求切桌面） |

**labwc 分支已落地的抓帧路径**（§2.6）：`grim -T <32hex identifier> out.png`——
grim 内部经 `ext_foreign_toplevel_image_capture_source_manager_v1` 创建 source，
`ext_image_copy_capture_manager_v1` 拷贝帧（即上面第 3/4 行协议的现成消费方）。
daemon 只负责枚举/归属/命令，像素抓取完全复用 grim，绕开 Quickshell #160 阻塞。

> ⚠️ **白名单注意**（`src/config/rcxml.c` `parse_privileged_interface()`）：
> `ext_image_copy_capture_manager_v1`、`ext_foreign_toplevel_list_v1`、
> `zwlr_foreign_toplevel_manager_v1`、`zwlr_screencopy_manager_v1`、`ext_workspace_manager_v1`
> 均在 labwc 特权协议白名单内，默认全允许，但 rc.xml 显式配 `<allowedInterfaces>` 后会被拒。
> **`ext_foreign_toplevel_image_capture_source_manager_v1` 不在白名单**，始终可用。

## 附录 C：参考链接

- **KDE / 其他合成器协议对照**（KWin、Mutter、niri、cosmic-comp 等逐源码核实）—
  [kde-and-compositor-protocol-support.md](kde-and-compositor-protocol-support.md)
- labwc PR #2968（toplevel capture 实现）— https://github.com/labwc/labwc/pull/2968
- labwc 0.20 release notes — https://github.com/labwc/labwc/releases
- `ext-foreign-toplevel-list` — https://wayland.app/protocols/ext-foreign-toplevel-list-v1
- `ext-image-capture-source` — https://wayland.app/protocols/ext-image-capture-source-v1
- `ext-image-copy-capture` — https://wayland.app/protocols/ext-image-copy-capture-v1
- `hyprland-toplevel-export` — https://wayland.app/protocols/hyprland-toplevel-export-v1
- Quickshell ScreencopyView 源码 — https://github.com/quickshell-mirror/quickshell/tree/master/src/wayland/screencopy