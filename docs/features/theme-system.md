# 主题系统 (Theme System)

Sumika Shell 的主题系统管理桌面所有视觉元素的颜色：终端、Hyprland 边框、
Quickshell UI（bar、overview、launcher）、编辑器等。切换主题时，所有这些组件
应同步更新。

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        主题数据流                                 │
│                                                                 │
│  themes/<slug>/colors.toml  ← 唯一的颜色来源                      │
│         │                                                       │
│         ▼                                                       │
│  sumika-settings-theme apply <slug>                                 │
│         │                                                       │
│         ├─→ copy_theme()                                        │
│         │     cp -a themes/<slug> → state/theme/current/         │
│         │                                                       │
│         ├─→ generate_theme_derivatives()                        │
│         │     从 colors.toml 生成各应用配置：                      │
│         │     ├── quickshell.json   (bar/overview/launcher 颜色)  │
│         │     ├── hyprland.lua      (Hyprland 边框颜色)           │
│         │     ├── foot.ini          (foot 终端颜色)               │
│         │     ├── kitty.conf        (kitty 终端颜色)              │
│         │     ├── alacritty.toml    (alacritty 终端颜色)          │
│         │     └── ghostty.conf      (ghostty 终端颜色)            │
│         │                                                       │
│         └─→ refresh_running_apps()                              │
│               ├── Quickshell IPC theme reload (bar 等)           │
│               ├── hyprctl reload (边框颜色)                      │
│               ├── reload-terminals (终端实时颜色)                 │
│               ├── pkill -USR1 helix (Helix 重载)                 │
│               └── nvim --server IPC (Neovim 重载)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 文件布局

### 主题包（只读源）

```
~/.local/share/sumika-shell/extensions/theme-settings/themes/<slug>/
  colors.toml       # 必需：accent/background/foreground/cursor/16色调色板
  neovim.lua        # 可选：LazyVim 插件规范（指定 colorscheme）
  btop.theme        # 可选：btop 配色
  vscode.json       # 可选：VSCode 配色
  waybar.css        # 可选：waybar 样式
  icons.theme       # 可选：图标主题
  preview.png       # 可选：预览图
```

**唯一权威的颜色来源是 `colors.toml`。** 其他文件是可选的 per-app 覆盖。

### 当前主题状态（运行时生成）

```
~/.local/state/sumika-shell/theme/
  current-name          # 当前主题 slug（如 "oceanblack"）
  current/              # 当前主题的完整副本 + 生成的衍生配置
    colors.toml         # 从主题包复制
    neovim.lua           # 从主题包复制（如果有）
    quickshell.json      # 生成：Quickshell UI 颜色
    hyprland.lua         # 生成：Hyprland 边框颜色
    foot.ini             # 生成：foot 终端 16 色调色板
    kitty.conf           # 生成：kitty 终端 16 色调色板
    alacritty.toml       # 生成：alacritty 终端 16 色调色板
    ghostty.conf          # 生成：ghostty 终端 16 色调色板
```

### 关键脚本

| 文件 | 作用 |
|---|---|
| `extensions/theme-settings/bin/sumika-settings-theme` | 主题后端：列表、应用、状态查询 |
| `extensions/theme-settings/bin/sumika-settings-theme-tui` | 主题选择 TUI（Python curses） |
| `extensions/theme-settings/bin/sumika-launch-settings-theme-tui` | TUI 启动器（设置 app-id） |
| `OMD/scripts/reload-terminals` | 终端颜色实时重载（foot OSC / kitty remote / alacritty touch / ghostty SIGUSR2） |
| `OMD/quickshell/services/OmarchyTheme.qml` | Quickshell 主题单例（读取 quickshell.json） |
| `OMD/hypr/default/hypr/base.lua` | Hyprland 启动时加载 theme/current/hyprland.lua |

## colors.toml 格式

```toml
accent = "#20b2aa"
background = "#000000"
foreground = "#d9e6e2"
cursor = "#7ec0ee"
selection_foreground = "#000000"
selection_background = "#80a0ff"

color0  = "#000000"    # black
color1  = "#b22222"    # red
color2  = "#90ee90"    # green
color3  = "#7fff00"    # yellow
color4  = "#80a0ff"    # blue
color5  = "#bf7fff"    # magenta
color6  = "#00cdcd"    # cyan
color7  = "#d9e6e2"    # white
color8  = "#3d5d6d"    # bright black
color9  = "#ff3030"    # bright red
color10 = "#00ff7f"    # bright green
color11 = "#b0e2ff"    # bright yellow
color12 = "#87cefa"    # bright blue
color13 = "#ab82ff"    # bright magenta
color14 = "#40e0d0"    # bright cyan
color15 = "#ffffff"    # bright white
```

`accent` / `background` / `foreground` 是必须的；`cursor` 和 `selection_*`
有默认值回退；`color0`–`color15` 也有默认值回退。

## 衍生配置生成

`generate_theme_derivatives()` 从 `colors.toml` 读取所有颜色值，然后**仅在文件
不存在时**生成衍生配置文件：

```bash
if [[ ! -f "$dir/quickshell.json" ]]; then
    # 生成 quickshell.json
fi
if [[ ! -f "$dir/hyprland.lua" ]]; then
    # 生成 hyprland.lua
fi
# ... foot.ini, kitty.conf, alacritty.toml, ghostty.conf 同理
```

因为主题包只包含 `colors.toml`（和可选的 `neovim.lua` 等），`copy_theme()`
执行 `cp -a` 后这些衍生文件不存在，所以每次应用主题都会重新生成。

### 各衍生文件内容

**`quickshell.json`** — Quickshell UI 三个核心色：

```json
{
  "primary": "#20b2aa",
  "background": "#000000",
  "backgroundText": "#d9e6e2"
}
```

**`hyprland.lua`** — Hyprland 活动窗口边框颜色：

```lua
local active_border_color = "rgb(20b2aa)"
hl.config({
  general = { col = { active_border = active_border_color } },
  group = { col = { border_active = active_border_color } },
})
```

**`foot.ini`** — foot 终端 16 色调色板（无 `#` 前缀）：

```ini
[colors]
background=000000
foreground=d9e6e2
regular0=000000
regular1=b22222
...
bright7=ffffff
```

**`alacritty.toml`** — alacritty 完整颜色配置（带 `#` 前缀）：

```toml
[colors.primary]
background = "#000000"
foreground = "#d9e6e2"

[colors.cursor]
text = "#000000"
cursor = "#7ec0ee"

[colors.normal]
black = "#000000"
red = "#b22222"
...

[colors.bright]
black = "#3d5d6d"
...
```

**`kitty.conf`** / **`ghostty.conf`** — 同理，格式各按其终端要求。

## 切换主题时的实时更新

`apply_theme()` 调用 `refresh_running_apps()`，按以下顺序通知所有运行中的组件：

### 1. Quickshell UI（bar / overview / launcher / clipboard）

```bash
for app in (sumika-bar sumika-overview sumika-applauncher sumika-clipboard); do
    qs -p "$SUMIKA_SHELL_ROOT/apps/$app" ipc call theme reload
done
```

Quickshell 的 `OmarchyTheme.qml` 单例通过 `FileView` 监听
`state/theme/current/quickshell.json`。IPC `theme reload` 调用
`themeFile.reload()`，重新读取 JSON 并更新 `accent` / `background` /
`foreground` 属性。所有引用这些属性的 QML 组件自动重绘。

### 2. Hyprland 边框

```bash
hyprctl reload
```

Hyprland 配置加载链：`hyprland.lua` → `default/hypr/base.lua` →
`dofile(state/theme/current/hyprland.lua)`。`hyprctl reload` 重新执行整个配置链，
边框颜色从新生成的 `hyprland.lua` 读取。

### 3. 终端颜色实时重载

```bash
"$SUMIKA_SHELL_ROOT/scripts/reload-terminals"
```

这是最关键的一步——终端不会自动监听配置文件变化（除了 alacritty）。
`reload-terminals` 脚本对每个终端使用不同的机制：

| 终端 | 机制 | 说明 |
|---|---|---|
| **foot** | SIGUSR1 + OSC 转义序列 | SIGUSR1 让 foot 重新加载 `[colors]` 段；同时直接向每个 foot 进程的 PTY 写入 OSC 序列（`\033]11;#color\007` 等），立即更新所有已打开终端的颜色，无需重启 |
| **kitty** | `kitty @ load-config` | 通过 kitty 的 remote-control 协议（Unix socket）发送重载命令 |
| **alacritty** | `touch` 配置文件 | alacritty 内置文件监听，配置 mtime 变化时自动重载 |
| **ghostty** | SIGUSR2 信号 | ghostty 的兼容性重载信号 |

### 4. 编辑器

```bash
# Helix
pkill -USR1 helix

# Neovim（通过 remote server socket IPC）
for socket in $(find $XDG_RUNTIME_DIR -name "nvim.*"); do
    nvim --server "$socket" --remote-send "<C-\><C-N>:OmarchyThemeReload<CR>"
done
```

> **注意：** Neovim 的实时重载依赖 `OmarchyThemeReload` 命令存在且 Neovim
> 以 `--listen` socket 模式运行。如果 Neovim 配置中未定义此命令，IPC 调用
> 会静默失败。Neovim 的 colorscheme 当前在 `options.lua` 中硬编码
> （`pcall(vim.cmd.colorscheme, "oceanblack")`），切换主题后需要手动
> 修改或重启 Neovim 才能完全生效。

## 终端配置的 include 机制

终端主配置文件通过 `include` / `import` 指令引入主题生成的颜色文件：

### foot

```ini
# ~/.config/foot/foot.ini
[main]
include=~/.local/state/sumika-shell/theme/current/foot.ini
```

### alacritty

```toml
# ~/.config/alacritty/alacritty.toml
general.import = [ "~/.local/state/sumika-shell/theme/current/alacritty.toml" ]
```

> alacritty 配置中**不应**硬编码 `[colors.*]` 段，否则会覆盖主题导入的颜色。

### kitty

```conf
# ~/.config/kitty/kitty.conf
include ~/.local/state/sumika-shell/theme/current/kitty.conf
```

### ghostty

```conf
# ~/.config/ghostty/config
config-file = ~/.local/state/sumika-shell/theme/current/ghostty.conf
```

## TUI 主题选择器

### 启动方式

| 入口 | 路径 |
|---|---|
| 桌面条目 | `sumika-theme-settings.desktop` → `sumika-launch-settings-theme-tui` |
| Settings 重定向 | `sumika-settings appearance` → `sumika-launch-settings-theme-tui` |
| 直接命令 | `sumika-launch-settings-theme-tui` |

`sumika-launch-settings-theme-tui` 使用 `xdg-terminal-exec --app-id=io.github.iamcheyan.sumika.themetui`
打开终端，使 Hyprland 窗口规则（float + center + 1180×760）生效。

### TUI 功能

- 22 个主题以色板网格显示（3–6 列，自适应宽度）
- 每个主题色板显示 accent / background / foreground 三色
- 当前主题高亮，可用的主题显示圆点标记
- 键盘导航：`hjkl` / `↑↓←→` 移动选择，`Enter` / `a` 应用主题
- `r` 刷新，`q` / `ESC` 退出
- 鼠标滚轮滚动，鼠标点击选择

### TUI 与后端的交互

TUI 是纯前端，所有主题操作通过 `sumika-settings-theme` 后端执行：

| TUI 动作 | 后端命令 | 说明 |
|---|---|---|
| 初始化 | `sumika-settings-theme appearance-status` | 获取当前主题名、颜色、状态 |
| 初始化 | `sumika-settings-theme list` | 获取所有主题列表（slug/name/status/accent/bg/fg） |
| 应用主题 | `sumika-settings-theme apply <slug>` | 复制主题包 + 生成衍生配置 + 通知所有组件 |
| 刷新 | `sumika-settings-theme appearance-status` + `list` | 重新获取状态 |

后台命令通过 `sumika_tui_framework.py::run_cmd_bg()` 异步执行，完成后通过回调
队列更新 Model。`Model.__init__()` 调用 `self.refresh()` 启动初始数据加载。

## 添加新主题

1. 创建目录：
   ```bash
   mkdir ~/.local/share/sumika-shell/extensions/theme-settings/themes/my-theme
   ```

2. 编写 `colors.toml`（必须包含 accent/background/foreground 和 16 色调色板）。

3. 可选：添加 `neovim.lua`（LazyVim 插件规范）、`btop.theme` 等。

4. 在 TUI 中按 `r` 刷新即可看到新主题。应用后会自动生成所有衍生配置。

## 常见问题

### 切换主题后只有边框颜色变了

`refresh_running_apps()` 中缺少 `reload-terminals` 调用。检查
`sumika-settings-theme` 的 `refresh_running_apps()` 函数是否包含：

```bash
"$SUMIKA_SHELL_ROOT/scripts/reload-terminals" >/dev/null 2>&1 || true
```

### 终端颜色不变化

检查终端主配置是否有 `include` / `import` 指令指向
`~/.local/state/sumika-shell/theme/current/` 下对应的颜色文件。
如果配置中硬编码了颜色段，会覆盖主题导入的颜色——删除硬编码的 `[colors.*]` 段。

### alacritty 不跟随主题

`~/.config/alacritty/alacritty.toml` 必须在文件顶部有：

```toml
general.import = [ "~/.local/state/sumika-shell/theme/current/alacritty.toml" ]
```

且不能包含硬编码的 `[colors.primary]`、`[colors.normal]`、`[colors.bright]` 等段。

### Quickshell bar 颜色不更新

检查 `sumika-bar` 是否在 `$SUMIKA_SHELL_ROOT/apps/` 下存在，且 `qs` 命令可用。
`OmarchyTheme.qml` 的 `FileView` 监听 `quickshell.json` 的变化，
IPC `theme reload` 触发重载。
