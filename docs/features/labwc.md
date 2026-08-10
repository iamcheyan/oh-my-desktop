# Sumika Shell on labwc

Sumika Shell 现在可以在 **labwc**（wlroots 系、Openbox 风格的堆叠式 Wayland
合成器）上运行。Hyprland 会话不受影响——labwc 适配是**增量**的，两套会话共存，
登录管理器里选择即可。

## 会话入口

| 会话 | 合成器 | 启动脚本 | Desktop entry |
|---|---|---|---|
| Sumika Shell | Hyprland | `/usr/local/bin/sumika-hyprland-session` | `sumika-shell.desktop` |
| Sumika Shell (labwc upstream) | labwc 0.20.1 | `/usr/local/bin/sumika-labwc-upstream-session` | `sumika-labwc-upstream.desktop` |

`sumika-labwc-upstream-session`（由 `Init.sh` 的 `install_labwc_session()` 安装）：

1. 导出与 Hyprland 会话相同的环境（`SUMIKA_SHELL_ROOT`、Wayland 工具链变量）。
2. `PATH` 优先 `/opt/labwc-upstream/usr/local/bin`，`exec labwc -C "$SUMIKA_SHELL_ROOT/labwc"`
   —— `-C` 让 labwc 把整个配置目录指向仓库内的 `labwc/`，无需把配置散落到
   `~/.config/labwc`。`/opt/labwc-upstream` 是**官方未修改的 labwc 0.20.1 构建**
   （`-xwayland`，wlroots-0.20.1）；本仓库不再维护 labwc-plus 分支。

`Init.sh` 重跑时若检测不到 labwc（PATH 或 `/opt/labwc-upstream`），会自动移除
labwc 会话入口（自愈）。

## 仓库内配置（`labwc/`）

| 文件 | 作用 | 官方文档 |
|---|---|---|
| `rc.xml` | 主配置：core/focus/desktops/theme/keyboard/mouse/windowRules | [labwc-config(5)](https://labwc.github.io/labwc-config.5.html) |
| `environment` | 环境变量（labwc 直接解析，非 shell 脚本） | 同上 |
| `autostart` | 会话启动脚本（拉起 bar、keep-awake、壁纸） | 同上 |
| `menu.xml` | 桌面右键根菜单 | [labwc-menu(5)](https://labwc.github.io/labwc-menu.5.html) |

热重载：`labwc --reconfigure`（仓库内键位 `W-r` 已绑定）。`autostart` 改动需重启会话。

`autostart` 里做了三件 Hyprland 会话不需要的事：

- **自探测 `WAYLAND_DISPLAY`**：labwc 官方 0.20.1 在 `server_start()` 里
  `setenv("WAYLAND_DISPLAY", socket)`（`src/server.c`），autostart 作为 labwc 的
  子进程**必然继承**该变量——即使裸 `labwc -C` 启动也一样。labwc 还额外把
  `WAYLAND_DISPLAY`/`XDG_CURRENT_DESKTOP` 等变量经 `dbus-update-activation-environment`
  + `systemctl --user import-environment` 注入用户环境（`src/config/session.c` 的
  `update_activation_env()`；默认仅在 DRM 后端时执行，可用 `LABWC_UPDATE_ACTIVATION_ENV`
  关闭——那只影响用户环境注入，不影响 autostart 自身继承）。因此 autostart
  **正常运行时变量已有值**；这里的探测只是**冗余保险**（未来版本改动、或自定义
  session 脚本清掉环境等边界情况），保证 bar 不会 fallback 到不存在的 `wayland-1`
  而启动失败。
- **HiDPI 缩放**：labwc 默认所有输出 scale=1.0。autostart 用 `wlr-randr`
  按 `hypr/monitors.lua` 的规则设内部屏 scale（≤2000px → 1.25，否则 → 2.0）。
  外接屏保持默认。
## 键位映射

键位镜像 `hypr/bindings.lua` + `hypr/default/hypr/bindings/*.lua`，但只映射
**合成器无关**的命令：

- `sumika-action <id>` —— 经 Quickshell bar 的 ActionManager IPC 路由（launcher、
  wifi、bluetooth、screenshot、notifications、input-method 等）
- `sumika-launch-profile <profile>` —— 从 `sumika.json` 解析应用命令（terminal、
  browser、editor 等）
- `labwc --reconfigure` 取代 `hyprctl reload`

原生 labwc 能力：`W-1..5` 切换工作区（`GoToDesktop`）、`W-S-1..5` 移动窗口
（`SendToDesktop`）、`A-Tab` 窗口切换、`A-F4` 关闭、`W-方向键` 贴边。

## 已知差异（非 bug）

- **堆叠 vs 平铺**：labwc 是堆叠式窗口管理器，没有 Hyprland 的 tiling、gaps、
  opacity 窗口规则。这些键位未映射。
- **bar 的 Hyprland 专属模块部分失效**：`HyprlandData` 服务（workspaces、窗口
  相关）依赖 hyprland IPC socket，labwc 下不工作；时钟、托盘、音频、WiFi、
  通知等仍可用；bar 本身是 wlr-layer-shell 表面，labwc 原生支持。
  overview 模块（LabwcOverview + thumbnaild）保留在 `labwc-adaptation` 分支
  （待上游 Quickshell toplevel 捕获协议）；**mainline 的 labwc 会话彻底禁用
  overview**（见下文「工作区与 topbar」），入口改用 labwc 原生
  `client-list-combined-menu`。
- **剪贴板菜单固定贴 bar**：wlroots 合成器不向客户端暴露绝对指针位置（没有
  hyprctl/swaymsg 这类 IPC，`zwp_relative_pointer` 只有相对位移），因此
  `sumika-clipboard` 在 labwc 下直接以 **bar 定位**（右上角、bar 下方，与点击
  bar 剪贴板按钮一致），不尝试跟随光标。shell.qml 用 `hyprctl monitors -j`
  探测合成器：Hyprland 走原路径（`cursorpos` 跟随光标），非 Hyprland 回退
  `wlr-randr --json` 解析显示器布局并固定 `positionMode: "bar"`。
- **无 XWayland**：本机 labwc 编译为 `-xwayland`，X11-only 应用无法运行；
  纯 Wayland 应用不受影响。若需要 XWayland，需重新编译 labwc。
- 电源/锁屏（`sumika-session`、`omarchy-system-lock`）走 systemd/loginctl，
  与合成器无关，两会话通用。
- **HiDPI 需要 autostart 设 scale**：labwc 不像 Hyprland 那样从保存的布局
  恢复每屏 scale（`hypr/monitors.lua` + `$SUMIKA_SHELL_STATE_HOME/display/layout.lua`），
  labwc 的 layout 需要 `wlr-randr` 管理。当前 autostart 只处理内部屏；
  多显示器布局下需扩展 autostart（或跑 kanshi）。

## 已知限制（labwc 降级，记录不修）

以下模块/功能在 labwc 下**降级而非报错**（Hyprland 会话不受影响），由
`hyprctl` IPC socket 缺失或 labwc 协议栈限制造成：

- **剪贴板/语音粘贴的 kitty 路径**：已修复为 send-text 主路径（见上文），
  但 class 检测在 labwc 下失败时（`hyprctl -j activewindow` 不可用）目标退化为
  `activewindow` + 空 class——修复版脚本对空 class 也先试 kitty remote
  （`kitty*|""` 分支），缓解了该问题；若目标窗口不是 kitty，按类回退 wtype
  快捷键（可能注入失败，因为 class 未知无法选对粘贴键）。
- **录音中 Escape 取消不可用**：voice/sasayaki 的「按 Escape 取消录音」靠
  `hyprctl eval o.bind("escape")` 动态绑键，labwc 无 hyprctl socket、无动态
  键位绑定机制 → 该路径失效。**降级方案**：录音中再按一次 toggle 键
  （rc.xml 已绑定 `sasayaki.toggle`）即停止并转写（`Toggle()`：idle →
  recording → transcribing）；「取消（丢弃）」降级为「停止（转写）」，功能可用。
- **launcher 运行中指示为空**：`RunningApps.qml` 靠 `hyprctl -j clients` 拿
  toplevel 列表；labwc-workspace daemon 只实现 `ext_workspace_manager_v1`
  （广播工作区名与 active 状态），**不提供 toplevel 枚举接口** → runningSet
  恒空。labwc 下无复用接口可修，记为已知降级。
- **Xkb 指示器为空**：`HyprlandXkb.qml` 的 `hyprlandIpcAvailable` 用环境变量
  探测（`HYPRLAND_INSTANCE_SIGNATURE`），labwc 下不设置 → 键盘布局指示器不显示。
  （改进方向：探测 hyprctl socket 而非 env，与 shell.qml 的探测方式一致。）
- **截图光标不隐藏**：`ScreenshotAction.qml` 的 grimHideCursor 调 hyprctl 被
  `|| true` 包裹，labwc 下静默跳过（光标在截图中可见），不影响截图功能。
- **设置页「重载配置」静默失败**：`SystemPage.qml` 的 hyprctl reload 在 labwc
  下无效果（不报错）。
- **Hyprland 专属**：`Persistent.qml`/`Session.qml`/`PowerContextMenu.qml`
  中的 hyprctl-only 逻辑在 labwc 下静默失效。
- **点击空白处关闭 popup/右键菜单不可用**：Hyprland 下有两套并行 dismiss
  机制——(1) `hyprland_focus_grab_v1` 协议（`GlobalFocusGrab.qml` 的
  `HyprlandFocusGrab`，点击 grab 窗口列表外部时 compositor 直接发 `onCleared`
  信号关闭 popup）；(2) `BarDismissLayer.qml` 全屏透明 Overlay 层窗口 +
  `MouseArea`（`mask: Region` 设 input region 捕获点击）。labwc **两套都失效**：
  `hyprland_focus_grab_v1` 是 Hyprland 专有协议，labwc 不支持（日志反复
  `hyprland_focus_grab_v1 protocol. HyprlandFocusGrab will not work`）；
  透明 layer-shell 窗口在 labwc 下不接收输入（`color: "transparent"` + `mask:
  Region` 的 input region 未被 labwc/wlroots 尊重，点击穿透；实测 `#80FF0000`
  有内容时能接收点击、dismiss 成功，透明时不能）。`BarRuntime.dismissLayerActive`
  绑定因 `GlobalFocusGrab` 单例未初始化而始终为 false，进一步使 dismiss window
  永不显示。**结论**：labwc 下点击空白处不能关闭 bar popup 和右键菜单，只能
  再次点击触发按钮 toggle 关闭（bar popup）或按 Esc（右键菜单 `ContextMenuWindow`
  有 `Keys.onEscapePressed: close()`）。这是 labwc 协议栈限制，不修。

## 顶栏透明/不透明切换（bar 透明逻辑调查）

原版（haline）顶栏有透明↔不透明切换：窗口占满时顶栏变不透明，否则透明。
OMD 的 bar 通过 `transparentOnEmptyDesktop` 实现同类效果（`sumika.json`
默认开启）。

### 当前实现机制（compositor-agnostic，两会话通用）

`BarContent.qml` 的 `workspaceHasMaximized` 直接走
`zwlr_foreign_toplevel_manager_v1`（Hyprland、labwc 均可用），不再依赖
`HyprlandData` 的 hyprctl poll：

```
workspaceHasMaximized = toplevels.values 中 ∃ t：
    t.activated && t.maximized && t.screens 包含本 bar 所在屏
barBackgroundColor = showBackground && transparentOnEmptyDesktop
    ? (workspaceHasMaximized ? barOpaqueColor(rgba 50%) : "transparent")
    : barOpaqueColor
```

判定规则：**本屏有激活且最大化的窗口 → 半透明黑面板；否则 → 完全透明**。
（与 `active-window` 扩展的 `focusedToplevel` 同一查找模式：`activated` +
`screens` 按屏匹配；直接属性读取，QML 绑定可追踪。）

### 修复历史

- **labwc 下永久透明（旧 bug）**：旧实现 `workspaceHasWindows` 依赖
  `HyprlandData`（hyprctl poll），labwc 下恒空 → bar 永远透明（即使有窗口
  也不显示面板）。已由上方 ToplevelManager 实现取代。
- **空桌面不透明（2026-08-09 修复）**：初版 ToplevelManager 实现只判断
  `maximized` 不判断 `activated`（或误用 `ToplevelManager.activeToplevel`，
  其语义是"最后激活的窗口"，最小化后不置空）→ **最小化所有窗口后 bar 仍
  不透明**，而此时 bar 标题已回退为操作系统名称（`ActiveWindow.displayTitle`
  在无激活窗口时显示 distro 名，如 "Fedora Linux Asahi Remix 44"）。
  修复：判定加 `t.activated` 条件——无激活窗口（标题显示 OS 名称）即视为
  空桌面 → 透明。实测三态：最大化激活 → 不透明；最小化（标题=OS 名）→
  完全透明；恢复最大化激活 → 不透明。
- **labwc 点击桌面不清焦点**（设计行为，未修）：labwc 点击桌面空白处只
  取消 popup grab，不清除窗口焦点（`cursor.c` 无 focus NULL 路径）→
  激活窗口保持不变，bar 保持不透明。这与"空桌面"（无激活窗口）不同，
  无合成器侧配置可改。

## 验证

```sh
# 配置合法性
xmllint --noout labwc/rc.xml labwc/menu.xml
bash -n labwc/autostart

# 会话入口
ls -l /usr/local/bin/sumika-labwc-upstream-session /usr/share/wayland-sessions/sumika-labwc-upstream.desktop
```

在登录管理器（plasmalogin/GDM）选择 "Sumika Shell (labwc upstream)" 登录即可实测。

> **⚠️ headless 测试必须隔离 autostart（2026-08-09 事故）**
>
> 用 `WLR_BACKENDS=headless` 起第二个 labwc 时**不要直接 `-C` 指向仓库的
> `labwc/`**：会话脚本会执行共享的 `labwc/autostart`，其中 `sumika-restart`
> 通过共享的 user systemd 杀掉真实会话的 bar，然后
> `systemd-run --unit=sumika-bar` 因 transient unit 名冲突报
> "Device or resource busy"，新 bar 起不来 → 真实会话 bar 消失。
>
> headless 验证配置加载请用隔离目录（空 autostart）：
> `mkdir -p /tmp/labwc-test && : > /tmp/labwc-test/autostart &&
> WLR_BACKENDS=headless labwc -C /tmp/labwc-test -c <仓库>/labwc/rc.xml`。
> 需要 keybind 行为实测时只能在真实会话（headless 无 seat，wtype 注入无效）。

## 工作区与 topbar

### 工作区布局（scratchpad = 工作区 0）

`rc.xml` 的 `<desktops number="6">` 名字按 **`1,2,3,4,5,0`** 顺序排列。
这是刻意的：labwc 的 `workspace_find_by_name()` **先按 index 匹配**
（`parse_workspace_index("1")` = 1 → 列表第 1 个），而
`parse_workspace_index("0")` = 0（falsy）→ 跳过 index 分支走 by-name 匹配。
因此**数字命名的桌面必须按 1..N 顺序排列，"0" 必须放列表末尾**，否则
W-1..W-5 全部错位一位；`GoToDesktop to="0"` / `SendToDesktop to="0"` 靠
by-name 命中末尾的 "0"。

键位（镜像 Hyprland 的 special workspace）：

- `W-s` —— 进出工作区 0（`GoToDesktop to="0" toggle="yes"`，再按一次回上次）
- `W-A-s` —— 把焦点窗口移入 0 并留在原工作区（`SendToDesktop to="0" follow="no"`）
- `W-S-1..5` —— 移窗口并跟随（`follow="yes"`）；`W-S-A-1..5` —— 移窗口不跟随

### 工作区切换 OSD 已隐藏

labwc 的工作区切换 OSD 由 `<desktops><popupTime>` 控制；设为 `0` 时
`workspaces.c` 的 `_osd_show()` 直接早退，完全不渲染（源码级确认）。
Alt-Tab 窗口切换 OSD（`<windowSwitcher>`）保持默认未动。

### topbar workspaces 模块（labwc 模式）

Hyprland 会话：workspaces 按钮照旧打开 overview。

labwc 会话（`XDG_CURRENT_DESKTOP=labwc`）：overview 彻底禁用，workspaces
按钮降级为**当前工作区编号 + 原生工作区一览菜单**：

- **显示** `workspaces[N]`：`Quickshell.Io.Socket` 连接
  `labwc-workspace` daemon（`$SUMIKA_SHELL_RUNTIME_DIR/labwc-workspace.sock`，
  fallback `$XDG_RUNTIME_DIR/sumika-shell/`），实时显示当前工作区号
  （`workspaces[1]` / `workspaces[0]`…）。
- **点击** = 注入 `W-A-w`（wtype）→ rc.xml `ShowMenu client-list-combined-menu`
  —— labwc 内置"所有工作区一览"：每个工作区 + 窗口标题（当前工作区标
  `>N<`、活动窗口 `*` 前缀、`Go there...` 直达操作）。bar 是 layer surface，
  labwc 的鼠标绑定管不到，只能模拟按键触发。

### labwc-workspace daemon

`labwc/tools/labwc-workspace/`：纯 C 的 ext-workspace-v1 客户端（vendored
`ext-workspace-v1.xml`），监听 active 工作区变化，经 unix socket 向 bar 广播
一行工作区名。Quickshell 无 ext-workspace QML 类型、labwc 无 CLI 查询，这是
两者间唯一的状态通道。

- 构建：`make && make install`（`Init.sh install_labwc_session` 已包含）
  → `~/.local/bin/labwc-workspace`；labwc 会话 `autostart` 在 bar 之前拉起。
- 协议要点：wlroots 在客户端 `wl_registry_bind` 时**同步重放**全部 workspace
  状态（`wlr_ext_workspace_v1.c` 的 `manager_bind`），listener 必须在
  registry global handler 里、下一个 roundtrip 派发**之前**挂上，否则初始
  active 状态丢失（曾导致 daemon 连上但收不到任何事件）。
- 单实例（flock）+ socket 0600，仅本用户可连。

### overview 在 labwc 下的禁用（三处）

1. `bin/sumika-restart`：`XDG_CURRENT_DESKTOP=labwc` 时跳过 overview 应用
   模块（registry 循环）。
2. `apps/sumika-bar/shell.qml`：labwc 下不预热 overview（`overviewPreWarmTimer`
   跳过），否则 1.5s 后 `sumika-overview warm` 会把 overview 进程拉起来。
3. `Workspaces.qml`：labwc 下按钮不再调用 `overview.open`。

## 语音输入（Sasayaki）在 labwc 下

语音输入（sasayaki 扩展，Go 守护进程 + SenseVoice）在 labwc 下**可用**：
按键说话、自动识别、自动粘贴（实测 `paste succeeded backend=kitty-bracketed-send`）。

### 键位链路

```
labwc rc.xml <keybind> → Execute sumika-action sasayaki.toggle
    → Quickshell ActionManager IPC → SasayakiInput.toggle()
    → $XDG_RUNTIME_DIR/sasayaki/sasayaki.sock → Go 守护进程 → 录音/识别/粘贴
```

`labwc/rc.xml` 的语音键位块（`A-a`、`Hangul_Hanja`、`XF86Fn`、`XF86Tools` →
`sasayaki.toggle`；`Hangul` → `sasayaki.translate-toggle`；`A-S-a` →
`sasayaki.repair`）镜像 `hypr/bindings.lua` 的 `read_sasayaki_bindings()`。
Hyprland 动态读 `~/.config/sasayaki/config.json`，**labwc rc.xml 不能读配置，
改绑定后要手动同步这个块**（块内注释已说明）。

### 粘贴为什么能工作

labwc 官方 0.20.1 暴露了整条粘贴栈所需的协议（`wayland-info` 实测）：

- `zwp_virtual_keyboard_manager_v1` —— wtype 注入粘贴键
- `zwlr_data_control_manager_v1` —— wl-copy 写入剪贴板
- `zwlr_foreign_toplevel_manager_v1` —— 焦点窗口探测

流程：`wl-copy` 写剪贴板 → 150ms 防竞争 → 解析焦点窗口 → 按窗口类选粘贴键
（终端 Shift+Insert / GUI Ctrl+V，kitty 走 send-text 直接注入）→ wtype 注入。

### 已知要点（2026-08-08 实测，已提交并部署）

- **焦点探测**：labwc 没有 hyprctl/swaymsg 这类 IPC。sasayaki 仓库
  `internal/paste/wlroots.go`（已提交，`agent/standalone-voice` 分支）实现了一个
  裸 Wayland 客户端，经 `zwlr_foreign_toplevel_manager_v1` 枚举 toplevel、读
  `activated` 状态拿焦点窗口 app_id（`ext-foreign-toplevel-list-v1` 无焦点状态，
  不能用；go-wayland 库无法注册服务端创建的对象，故手写协议）。加入解析链：
  Hyprland → Sway → **wlroots（labwc/wayfire/river…）** → KWin → GNOME → X11。
  **字符串参数长度必须填含 NUL 的原始字节数**——libwayland ≥ 1.24 在反序列化时
  校验 `strlen(s) == length-1`，发 padded 长度会被判 "string has embedded nul"
  直接断连（go-wayland 的 `PutString` 正是 padded 写法，不可照抄）。
- **服务环境修复**（`internal/paste/paste.go` 的 `sessionCompositorEnv()` /
  `applySessionEnv()`，已提交）：`sasayaki.service` 是 user 级服务，可能继承旧会话
  （Hyprland）的 `WAYLAND_DISPLAY`/`HYPRLAND_INSTANCE_SIGNATURE`。新逻辑经
  `loginctl list-sessions` 找**当前激活会话** → 走 cgroup `cgroup.procs` 找合成器
  进程 → 读 `/proc/<pid>/environ`；官方 labwc 0.20.1 自己在 `server_start()` 里
  `setenv("WAYLAND_DISPLAY", socket)`，所以正常有值；对不导出的合成器则按它持有
  的 socket inode 对照 `/proc/net/unix` 反推，并对活 socket 校验后应用。
- **已部署**：`make install` + `systemctl --user restart sasayaki` 已执行，
  `/proc/<pid>/environ` 实测 `WAYLAND_DISPLAY=wayland-0`、
  `XDG_CURRENT_DESKTOP=labwc`（`DISPLAY`/`HYPRLAND_INSTANCE_SIGNATURE` 未设置）。
  服务跨会话残留旧环境的问题由 daemon 内自愈逻辑根治（`ensureGraphicalEnvironment`
  只在真实 runner 下执行，单元测试保持封闭）。
- **端到端实测**：焦点探针命中焦点 kitty（app_id 解析 + `activated` 状态），
  粘贴走 kitty send-text 注入（`Backend=kitty-bracketed-send`），文本落入焦点
  tmux 窗口输入区；非 kitty 窗口按类回退 wtype 快捷键（终端 Shift+Insert、
  GUI Ctrl+V）。
- **kitty 粘贴主路径是 send-text，不是原生 action**（2026-08-09 修复）：
  kitty 默认 `clipboard_control=no-append write-clipboard write-primary`（只写不读），
  `kitty @ action paste_from_clipboard`（shift+Insert / `kitty-native-paste`）读的是
  **kitty 内部剪贴板缓冲**而非系统剪贴板，会粘出过时内容——与今日剪贴板菜单 bug
  同根因（见 `docs/features/paste-kitty-conflicts.md`）。sasayaki `sendToKitty`
  主路径改为 `kitty @ send-text --stdin --bracketed-paste auto` 直接注入 payload
  （transport `kitty-bracketed-send`），`paste_from_clipboard` 降为 send-text 失败
  时的 fallback（`kitty-native-paste`）；注入前 `wl-copy -c` 清剪贴板防 OSC 5522
  双粘贴，成功后 50ms 恢复 payload。voice 扩展的 `omarchy-paste-at-cursor` 同步修复。
- **多 kitty 实例下的粘贴聚焦约束**（2026-08-09 实测）：wlroots 系合成器
  （labwc/sway）的 `zwlr_foreign_toplevel_handle_v1` 没有 pid 事件，sasayaki
  只能靠 glob `/tmp/mykitty-*` 枚举实例。旧实现无聚焦要求时直接取第一个
  socket（按词法序，通常是最老的**后台**实例），曾导致
  `paste succeeded backend=kitty-native-paste` 但文本落在后台窗口、焦点窗口
  什么都没收到。修复后（`paste.go` 的 `resolveKittyWindowID(ls, requireFocused)` /
  `tryKittySockets`）：glob 发现的 socket 必须由 kitty 自身 `@ ls` 报告
  `is_focused:true` 才接受；pid 指定的 socket（Hyprland/sway 路径）保持权威；
  找不到聚焦实例时回退 wtype chord（作用于合成器聚焦表面）。多开 kitty 时
  该约束保证文本只进**当前聚焦**的实例。
- **验证**：`journalctl --user -u sasayaki.service -f` 看
  `recording started → transcribed chars=N → paste succeeded backend=…`
  （kitty 目标为 `kitty-bracketed-send`，其他窗口为 `wtype`）。

### 诊断（`sasayaki diagnose`）在 labwc 下

`diagnose` 的检测逻辑与粘贴路径一一对应，labwc 下实测全部通过：

- **compositor**：经 loginctl 激活会话 → cgroup → `/proc/<pid>/cmdline`
  识别当前合成器（实测 `compositor: labwc`），并校验 `WAYLAND_DISPLAY` socket 存活。
- **paste protocols**：裸 Wayland 客户端枚举 registry，校验粘贴栈三个全局协议
  （`zwp_virtual_keyboard_manager_v1` / `zwlr_data_control_manager_v1` /
  `zwlr_foreign_toplevel_manager_v1`）。labwc 全有；缺哪个就报哪个。
- **focus resolution**：实际跑完整解析链（Hyprland → Sway → wlroots → KWin →
  GNOME → X11），报告命中的后端与窗口类（实测
  `focused window kitty resolved via wlroots`）。
- 三个检测在探测前都会先走 daemon 同款环境自愈（`paste.EnsureDisplayEnv`），
  因此从旧会话（残留死 `wayland-1`）的 shell 里跑 `sasayaki diagnose` 也不会误报。

