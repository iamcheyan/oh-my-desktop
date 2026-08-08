# Sumika Shell on labwc

Sumika Shell 现在可以在 **labwc**（wlroots 系、Openbox 风格的堆叠式 Wayland
合成器）上运行。Hyprland 会话不受影响——labwc 适配是**增量**的，两套会话共存，
登录管理器里选择即可。

## 会话入口

| 会话 | 合成器 | 启动脚本 | Desktop entry |
|---|---|---|---|
| Sumika Shell | Hyprland | `/usr/local/bin/sumika-hyprland-session` | `sumika-shell.desktop` |
| Sumika Shell (labwc) | labwc | `/usr/local/bin/sumika-labwc-session` | `sumika-labwc.desktop` |

`sumika-labwc-session`（由 `Init.sh` 的 `install_labwc_session()` 安装）：

1. 导出与 Hyprland 会话相同的环境（`SUMIKA_SHELL_ROOT`、Wayland 工具链变量）。
2. `exec labwc -C "$SUMIKA_SHELL_ROOT/labwc"` —— `-C` 让 labwc 把整个配置目录
   指向仓库内的 `labwc/`，无需把配置散落到 `~/.config/labwc`。

`Init.sh` 重跑时若检测不到 `labwc` 命令，会自动移除 labwc 会话入口（自愈）。

## 仓库内配置（`labwc/`）

| 文件 | 作用 | 官方文档 |
|---|---|---|
| `rc.xml` | 主配置：core/focus/desktops/theme/keyboard/mouse/windowRules | [labwc-config(5)](https://labwc.github.io/labwc-config.5.html) |
| `environment` | 环境变量（labwc 直接解析，非 shell 脚本） | 同上 |
| `autostart` | 会话启动脚本（拉起 bar、keep-awake、壁纸） | 同上 |
| `menu.xml` | 桌面右键根菜单 | [labwc-menu(5)](https://labwc.github.io/labwc-menu.5.html) |

热重载：`labwc --reconfigure`（仓库内键位 `W-r` 已绑定）。`autostart` 改动需重启会话。

`autostart` 里做了两件 Hyprland 会话不需要的事：

- **自探测 `WAYLAND_DISPLAY`**：不依赖 labwc 注入 socket 变量，增强健壮性。
  labwc 的 `server_start()` 确实会 setenv `WAYLAND_DISPLAY`（headless 实测
  生效），但 Hyprland → labwc 会话切换时曾出现 bar 拿不到 socket、
  `sumika-restart` fallback 到不存在的 `wayland-1` 而启动失败的情况。
  autostart 在变量为空时遍历 `$XDG_RUNTIME_DIR/wayland-*` 找到真实 socket；
  变量已有值时保持不变。
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
ls -l /usr/local/bin/sumika-labwc-session /usr/share/wayland-sessions/sumika-labwc.desktop
```

在登录管理器（plasmalogin/GDM）选择 "Sumika Shell (labwc)" 登录即可实测。
