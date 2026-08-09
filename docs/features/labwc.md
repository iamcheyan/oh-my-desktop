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
- **overview 缩略图 daemon**：拉起 `sumika-overview-thumbnaild`（§"overview
  窗口缩略图"），在 bar 之前启动使缩略图就绪。daemon 自带 labwc 协议探测，
  Hyprland 下自动退出（autostart 只存在于 labwc 会话，双保险）。

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
  通知等仍可用。**overview 已适配**（见上节"overview 窗口缩略图"）：labwc 分支
  自写 thumbnaild daemon + `grim -T` 抓帧，缩略图网格/工作区切换/搜索/点击聚焦
  均可用；bar 本身是 wlr-layer-shell 表面，labwc 原生支持。
- **无 XWayland**：本机 labwc 编译为 `-xwayland`，X11-only 应用无法运行；
  纯 Wayland 应用不受影响。若需要 XWayland，需重新编译 labwc。
- 电源/锁屏（`sumika-session`、`omarchy-system-lock`）走 systemd/loginctl，
  与合成器无关，两会话通用。
- **HiDPI 需要 autostart 设 scale**：labwc 不像 Hyprland 那样从保存的布局
  恢复每屏 scale（`hypr/monitors.lua` + `$SUMIKA_SHELL_STATE_HOME/display/layout.lua`），
  labwc 的 layout 需要 `wlr-randr` 管理。当前 autostart 只处理内部屏；
  多显示器布局下需扩展 autostart（或跑 kanshi）。

## overview 窗口缩略图（labwc 分支）

labwc 下 overview（工作区概览）显示**当前工作区每个窗口的缩略图**，由
`quickshell/modules/overview/` 的 labwc 分支实现——绕开 Quickshell
`ScreencopyView` 只支持 `hyprland-toplevel-export-v1` 的限制（issue #160 open）。

### 架构

```
LabwcOverview.qml          ← labwc 会话专用的 overview UI（网格布局）
      │ JSON 行协议（unix socket，0600）
      ▼
sumika-overview-thumbnaild ← C daemon（只存在于 labwc 会话）
      │
      ├─ ext_foreign_toplevel_list_v1      枚举窗口 + 32 位 hex identifier
      ├─ ext_workspace_manager_v1          工作区列表 + activate 切换
      ├─ zwlr_foreign_toplevel_manager_v1  activate（窗口聚焦）/ close
      └─ grim -T <identifier>              按窗口抓帧 → PNG
```

- **源码**：`quickshell/modules/overview/thumbnaild/`（`thumbnaild.c` +
  Makefile + 三个协议 xml；OMD 仓库首个原生 C 目录）。编译：`cd …/thumbnaild && make`。
  二进制不入库（仓库只跟踪源码）——`Init.sh` 的 `install_labwc_session()`
  检测到 make/cc 时自动构建，labwc 会话登录即用；手动构建同上。
- **启用条件**：daemon 启动时只探测 `ext_foreign_toplevel_list_v1` global——
  有才继续，无则立即退出。Hyprland 不实现该协议 → daemon 在 Hyprland 会话
  **永不生效**（labwc 专属，符合设计）。
- **socket**：`$SUMIKA_SHELL_RUNTIME_DIR/overview-thumbnaild.sock`。
  缩略图落盘：`$SUMIKA_SHELL_STATE_HOME/overview-thumbs/`（注意是 `overview-thumbs`，
  不是 `thumbnails`）。两者无环境变量时按仓库路径契约
  （`lib/paths.sh`）回退 `$XDG_RUNTIME_DIR/sumika-shell` /
  `$XDG_STATE_HOME/sumika-shell`，与 QML 桥的 fallback 一致。
- **桥协议**（JSON 行）：daemon 广播 `{"type":"snapshot","seq":N,
  "activeWorkspace":"…","workspaces":[…],"windows":[…]}`
  （`seq` 同时用作缩略图 URL cache-buster：`file://…?v=${bridge.seq}`）；
  命令 `activate-workspace`（ext-workspace `activate`+`commit`，事务式）/
  `activate-window`（zwlr activate，labwc 一次请求完成切桌面+聚焦）/
  `refresh`。
- **UI**：`LabwcOverview.qml`（+ singleton `LabwcOverviewBridge.qml`）。
  窗口缩略图网格（非真实几何）、工作区 chips 点击切换、标题/应用搜索过滤、
  点击缩略图聚焦窗口。保留 `IpcHandler "overview"` 接口——
  `bin/sumika-overview toggle/open/close/workspacesToggle` 行为与 Hyprland 版一致。
  不注册 GlobalShortcut（labwc 快捷键由 rc.xml 管理）。
- **条件加载**：`shell.qml` 按 `SystemInfo.desktopEnvironment`（bash 读
  `XDG_CURRENT_DESKTOP` 第一字段）分支——`labwc` → LabwcOverview；
  其余 → 旧 Overview（Hyprland 行为不变）。

### 已知取舍（相对 Hyprland 版）

- **缩略图是静态帧**（grim 抓帧时点），非实时画面；事件驱动刷新（toplevel 事件、
  工作区切换、`refresh` 命令），debounce 250ms。
- **窗口→工作区归属是近似**：`ext-foreign-toplevel-list` 不暴露窗口属于哪个
  desktop。daemon 用**激活历史归属**——窗口的 workspace 取"最近一次激活时所在
  桌面"；未知归属窗口（`workspace==""`）在 UI 上归当前工作区并带 `?` 角标。
- **并发抓帧限制**：wlroots 的 capture source 同一时刻只服务一个客户端，多余
  grim 会 hang——daemon 每次刷新最多 spawn 一个 grim（`capture_in_flight` 守卫），
  SIGCHLD 驱动 tmp→png 转正。
- **win+tab**：不用 Quickshell 内循环，用 labwc 原生 windowSwitcher
  （`W-Tab` → `NextWindow workspace="current"`，`osd style="thumbnail"` 合成器侧
  渲染真实缩略图），见 rc.xml。

### 调试

```sh
# daemon 前台运行（打印协议事件与抓帧日志）
WAYLAND_DISPLAY=wayland-0 SUMIKA_SHELL_RUNTIME_DIR=$XDG_RUNTIME_DIR/sumika-shell \
SUMIKA_SHELL_STATE_HOME=$HOME/.local/state/sumika-shell \
./quickshell/modules/overview/thumbnaild/sumika-overview-thumbnaild

# 手工发命令验证
printf '{"cmd":"activate-workspace","name":"2"}\n' | \
  socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/sumika-shell/overview-thumbnaild.sock
```

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
> 通过共享的 user systemd 杀掉真实会话的 bar/overview，然后
> `systemd-run --unit=sumika-bar` 因 transient unit 名冲突报
> "Device or resource busy"，新 bar 起不来 → 真实会话 bar 消失。
> 同目录下 thumbnaild 还会因无单实例守卫 unlink 抢走真实 daemon 的 socket。
>
> headless 验证配置加载请用隔离目录（空 autostart）：
> `mkdir -p /tmp/labwc-test && : > /tmp/labwc-test/autostart &&
> WLR_BACKENDS=headless labwc -C /tmp/labwc-test -c <仓库>/labwc/rc.xml`。
> 需要 keybind 行为实测时只能在真实会话（headless 无 seat，wtype 注入无效）。

## 语音输入（Sasayaki）在 labwc 下

语音输入（sasayaki 扩展，Go 守护进程 + SenseVoice）在 labwc 下**可用**：
按键说话、自动识别、自动粘贴（实测 `paste succeeded backend=kitty-native-paste`）。

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
（终端 Shift+Insert / GUI Ctrl+V，kitty 走原生 remote paste）→ wtype 注入。

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
  粘贴走 kitty 原生 remote paste（`Backend=kitty-native-paste`），文本落入焦点
  tmux 窗口输入区；非 kitty 窗口按类回退 wtype 快捷键（终端 Shift+Insert、
  GUI Ctrl+V）。
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
  （kitty 目标为 `kitty-native-paste`，其他窗口为 `wtype`）。

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

