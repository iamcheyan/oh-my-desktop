# Omarchy Fedora Session 排障记录

日期：2026-06-21

## 背景

本仓库新增了 `omarchy/`，用于在 Fedora 上部署一个独立的 Omarchy
Hyprland session。登录入口是：

- `/usr/share/wayland-sessions/omarchy.desktop`
- `~/.local/bin/omarchy-session`

Omarchy 文件部署到：

- `~/.local/share/omarchy`
- `~/.config/omarchy`

该 session 目标是独立于当前 `~/.config/hypr` / Quickshell 配置运行，
避免破坏现有桌面。

## 已遇到的问题

### 1. Hyprland 把 Lua 配置当普通 config 解析

症状：

```text
config error in file /tmp/tmp.* at line ...
invalid config line
```

原因：

`omarchy-session` 用 `mktemp` 生成临时入口文件，但没有 `.lua` 后缀。
Hyprland 0.55 会根据配置文件后缀选择解析器；无 `.lua` 时按旧
Hyprland config 语法解析，导致 `local ...` 等 Lua 内容报错。

修复：

```bash
ENTRY_POINT=$(mktemp --suffix=.lua)
```

已同步到：

- `~/.local/bin/omarchy-session`
- `omarchy/install-fedora.sh`
- `omarchy/install-fedora-fast.sh`

验证：

```bash
hyprland --verify-config -c /tmp/tmp.xxx.lua
```

结果应包含：

```text
[cfg] Config is lua, loading lua mgr
Config parsing result:
config ok
```

### 2. Fedora Hyprland 提示未使用 start-hyprland

症状：

Hyprland 启动时提示没有通过 `start-hyprland` 启动。

原因：

Fedora 的 Hyprland 0.55 包提供 `/usr/bin/start-hyprland`，用于通过
watchdog 正确启动 Hyprland。原 wrapper 直接执行：

```bash
exec hyprland -c "$ENTRY_POINT"
```

修复：

优先使用 `start-hyprland`，没有该命令时 fallback：

```bash
if command -v start-hyprland >/dev/null 2>&1; then
  exec start-hyprland -- -c "$ENTRY_POINT"
fi

exec hyprland -c "$ENTRY_POINT"
```

验证：

```bash
start-hyprland -- --verify-config -c /tmp/tmp.xxx.lua
```

结果应为 `config ok`。

### 3. 进入 session 后空白，waybar/swaybg/hypridle 没启动

症状：

Hyprland 进程存在，但桌面没有 bar、壁纸或常驻服务。只看到空 Hyprland。

排查结果：

`hyprland.start` hook 有触发，`polkit-gnome` 能启动。但 Omarchy 默认用：

```bash
uwsm-app -- waybar
uwsm-app -- swaybg ...
uwsm-app -- hypridle
```

当前 Fedora wrapper 是 `start-hyprland` session，不是 `uwsm start`
session。通过 `uwsm app` 启动的程序不会稳定进入当前 Hyprland 环境。

修复：

在 `omarchy-session` 中导出：

```bash
export OMARCHY_FORCE_NO_UWSM=1
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
```

同时将 `~/.local/bin/uwsm-app` 改为兼容 wrapper：

```bash
#!/bin/bash

if [[ ${OMARCHY_FORCE_NO_UWSM:-0} == 1 ]]; then
  [[ ${1:-} == -- ]] && shift
  exec "$@"
fi

exec uwsm app -- "$@"
```

这样 Omarchy 原有脚本里硬编码的 `uwsm-app -- ...` 在该 session 内会直接
执行原命令，不再依赖 UWSM 管理。

已同步到：

- `~/.local/bin/uwsm-app`
- `~/.local/bin/omarchy-session`
- `omarchy/install-fedora.sh`
- `omarchy/install-fedora-fast.sh`

### 4. waybar 因主题文件缺失退出

症状：

手动启动 waybar 报：

```text
style.css:1:46 Failed to import:
Error opening file ~/.config/omarchy/current/theme/waybar.css:
No such file or directory
```

原因：

`~/.config/omarchy/current/theme` 没有完整通过 `omarchy-theme-set` 生成，
只包含少量主题文件，缺少由模板生成的 `waybar.css`。

修复：

重新应用当前主题：

```bash
export OMARCHY_PATH="$HOME/.local/share/omarchy"
export OMARCHY_CONFIG="$HOME/.config/omarchy"
export OMARCHY_FORCE_NO_UWSM=1
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set kanagawa
```

生成后应存在：

```text
~/.config/omarchy/current/theme/waybar.css
```

## 当前验证状态

已验证：

- `start-hyprland -- --verify-config -c <entry.lua>` 返回 `config ok`
- 从 KDE 中运行 `~/.local/bin/omarchy-session` 可以启动 nested Hyprland
- `hyprctl instances` 可看到 Hyprland 实例
- `swaybg` 可启动，并出现在 Hyprland layer `wallpaper`
- `hypridle` 可启动
- `waybar` 可读取配置并完成：

```text
Bar configured ... for output: WAYLAND-1
```

## 测试命令

从 KDE/已有 Wayland session 中测试：

```bash
~/.local/bin/omarchy-session 2>&1 | tee /tmp/omarchy-session.log
```

另开终端查看实例：

```bash
hyprctl instances
```

连接最近的 Hyprland 实例：

```bash
sig=$(basename "$(ls -td "$XDG_RUNTIME_DIR"/hypr/* | head -1)")
HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -j monitors
HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -j layers
HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -j clients
```

在 Lua config mode 下手动启动程序：

```bash
HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl dispatch 'hl.dsp.exec_cmd("alacritty")'
```

注意：Lua config mode 下旧式命令：

```bash
hyprctl dispatch exec alacritty
```

会被当作 Lua 片段解析，可能报语法错误；这不是 session 启动失败。

## 已知非阻塞问题

这些日志目前不影响基本桌面显示：

- `DRM Backend failed`：从 KDE 内嵌套启动时正常，Hyprland 会 fallback 到
  Wayland backend。SDDM 直接登录时应走 DRM backend。
- `swayosd-server.service does not exist`：Fedora 当前没有该 service。
- Chromium policy 写入 `/etc/chromium/...` 权限不足：普通用户无权限，不影响
  Hyprland/Waybar 基本显示。
- `fatal: 'origin' does not appear to be a git repository`：Waybar update
  模块检查 Omarchy 更新时触发，当前部署目录不是完整 git remote。

## 回归检查清单

重新登录 SDDM 的 `Omarchy (Fedora)` 后检查：

```bash
pgrep -a Hyprland
pgrep -a start-hyprland
pgrep -a waybar
pgrep -a swaybg
pgrep -a hypridle
```

如果仍然空白，优先查看：

```bash
journalctl --user -b --no-pager | rg 'omarchy|Hyprland|hyprland|uwsm|waybar|swaybg|hypridle|command not found|Failed|failed|ERR|ERROR' | tail -200
```

以及：

```bash
find "$XDG_RUNTIME_DIR/hypr" /tmp -maxdepth 4 -type f \
  \( -name 'hyprland.log' -o -name '*omarchy*log' -o -name '*hypr*.log' \) \
  -printf '%T@ %p\n' | sort -nr | head
```
