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

`autostart` 里做了两件 Hyprland 会话不需要的事：

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
- **bar 的 Hyprland 专属模块失效**：`HyprlandData` 服务（workspaces、overview、
  窗口相关）依赖 hyprland IPC socket，labwc 下不工作；时钟、托盘、音频、WiFi、
  通知等仍可用。bar 本身是 wlr-layer-shell 表面，labwc 原生支持。
- **无 XWayland**：本机 labwc 编译为 `-xwayland`，X11-only 应用无法运行；
  纯 Wayland 应用不受影响。若需要 XWayland，需重新编译 labwc。
- 电源/锁屏（`sumika-session`、`omarchy-system-lock`）走 systemd/loginctl，
  与合成器无关，两会话通用。
- **HiDPI 需要 autostart 设 scale**：labwc 不像 Hyprland 那样从保存的布局
  恢复每屏 scale（`hypr/monitors.lua` + `$SUMIKA_SHELL_STATE_HOME/display/layout.lua`），
  labwc 的 layout 需要 `wlr-randr` 管理。当前 autostart 只处理内部屏；
  多显示器布局下需扩展 autostart（或跑 kanshi）。

## 验证

```sh
# 配置合法性
xmllint --noout labwc/rc.xml labwc/menu.xml
bash -n labwc/autostart

# 会话入口
ls -l /usr/local/bin/sumika-labwc-upstream-session /usr/share/wayland-sessions/sumika-labwc-upstream.desktop
```

在登录管理器（plasmalogin/GDM）选择 "Sumika Shell (labwc upstream)" 登录即可实测。

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
- **验证**：`journalctl --user -u sasayaki.service -f` 看
  `recording started → transcribed chars=N → paste succeeded backend=…`
  （kitty 目标为 `kitty-native-paste`，其他窗口为 `wtype`）。

