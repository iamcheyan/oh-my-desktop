# Omarchy 遗留清理方案

目标：把项目收敛成以 OMD 自己的 Quickshell 和 Hyprland 配置为核心的桌面环境。Omarchy 只作为历史来源，不再作为运行时框架、配置命名空间或默认功能集合存在。

本文先做依赖分析和迁移路线，不建议在第一步直接删除目录。当前项目里仍有多个硬依赖指向 `~/.config/omarchy`、`~/.local/share/omarchy` 和 `omarchy-*` 命令，直接删除会导致登录会话、Hyprland 配置、主题、锁屏、键盘映射、语音输入或壁纸功能失效。

## 当前核心结论

现在真正要保留的是这些部分：

- `quickshell/`：主 UI、服务、设置中心和公共组件。
- `apps/omd-*`：拆分后的 Quickshell 进程入口。
- `bin/omd-*`：OMD 自己的运行入口，例如 `omd-restart`、`omd-wallpaper`、`omd-session`、`omd-settings-theme`。
- `scripts/`：OMD 辅助脚本，例如键盘捕获、语音测试、路径解析、Quickshell reload。
- `keyboard-remap/`：键盘映射状态和生成结果。
- Hyprland 配置本身：现在位于 `omarchy/hypr/`，但长期应该迁移到 OMD 命名空间，例如 `hypr/` 或 `config/hypr/`。

当前不能直接删除的 Omarchy 依赖：

- `Init.sh` 创建 `~/.config/omarchy -> ./omarchy` 和 `~/.local/share/omarchy -> ./share`。
- `Init.sh` 生成的 `/usr/local/bin/omd-hyprland-session` 固定从 `~/.config/omarchy/hypr/hyprland.lua` 启动，并把 `~/.local/share/omarchy/bin` 放入 `PATH`。
- `omarchy/hypr/hyprland.lua` 仍然加载 `require("default.hypr.omarchy")` 和 `require("default.hypr.toggles")`，这些来自 `share/default/hypr/`。
- Quickshell 的主题服务读取 `~/.config/omarchy/current/theme/quickshell.json`。
- `bin/omd-wallpaper` 调用 `omarchy-theme-bg-set`，并读取 `~/.config/omarchy/current/background`。
- `bin/omd-settings-theme` 调用 `omarchy-theme-set`，并读取 `~/.config/omarchy/current/theme.name`。
- 语音输入、键盘映射、剪贴板粘贴仍调用 `~/.config/omd/share/bin/omarchy-*` 脚本。
- Hypridle 和会话动作仍调用 `omarchy-system-lock`、`omarchy-system-wake`、`omarchy-launch-screensaver` 等命令。

## 运行时依赖地图

### 登录和 Hyprland

当前登录链路是：

```text
GDM session
  -> /usr/local/bin/omd-hyprland-session
  -> Hyprland -c ~/.config/omarchy/hypr/hyprland.lua
  -> require("default.hypr.omarchy")
  -> share/default/hypr/*
  -> require("hypr.monitors/input/bindings/looknfeel/autostart")
```

这里最大的 Omarchy 耦合是 `share/default/hypr/omarchy.lua`。它不是一个小兼容层，而是会加载：

- 默认 autostart：`hypridle`、`mako`、`waybar`、`fcitx5`、`swaybg`、polkit、first-run、powerprofiles、monitor-watch、post-boot hook。
- 默认按键：媒体键、剪贴板、窗口/工作区、Omarchy 菜单、截图、硬件菜单、锁屏、通知等。
- 默认环境变量、输入配置、窗口规则、looknfeel。
- 当前主题覆盖：`~/.config/omarchy/current/theme/hyprland.lua`。

因此不能先删 `share/default/hypr`。正确做法是先把我们还需要的 Hyprland 行为复制/重写到 OMD 自己的 Hyprland 模块里，再断开 `require("default.hypr.*")`。

### Quickshell

Quickshell 本身大部分已经是 OMD 命名空间：

- `bin/omd-restart` 启动 `omd-bar`、`omd-desktop`、`omd-overview`、`omd-applauncher`、`omd-corners`、`omd-clipboard`、`omd-clipboard-store`。
- 各 app 入口位于 `apps/omd-*/shell.qml`。
- QML 内部大量调用 `~/.config/omd/bin/omd-*`。

仍需处理的 Omarchy 调用集中在：

- `quickshell/services/OmarchyTheme.qml`：主题文件路径仍是 Omarchy 当前主题。
- `quickshell/services/VoiceInput.qml`：调用 `omarchy-voice-setup/download/record/transcribe` 和 `omarchy-paste-at-cursor`。
- `quickshell/services/KeyboardRemap.qml`：调用 `omarchy-keyboard-list/render/apply/setup`。
- `quickshell/modules/common/functions/Session.qml`：锁屏/退出使用 `omarchy-system-lock`、`omarchy-system-logout`。
- 设置中心的主题、字体、终端字体、语音绑定仍读取或调用 Omarchy 路径/命令。

这些不一定要一次重写。可以先建立 OMD 命名的 wrapper，再逐步替换 QML 调用点。

### 主题和壁纸

主题系统目前仍以 Omarchy 目录结构为中心：

```text
share/themes/*
  -> omarchy-theme-set
  -> ~/.config/omarchy/current/theme/*
  -> quickshell.json / hyprland.lua / hyprlock.conf / foot.ini / alacritty.toml / ...
```

Quickshell、Hyprland、hyprlock、终端配置都会读取 `omarchy/current/theme`。这意味着主题系统是另一个大依赖。清理时需要先决定：

1. 是否保留多主题能力。
2. 是否只保留当前主题快照。
3. 是否把主题路径迁移到 `~/.config/omd/current/theme` 或 repo 内的 `themes/`。

建议不要在早期删除 `share/themes` 和 `omarchy/current`。先给 OMD 建立自己的主题路径，再做兼容迁移。

### `share/bin`

`share/bin` 现在有大量 `omarchy-*` 命令，其中只有一部分仍被 OMD 主流程使用。

高优先级保留/迁移：

- `omarchy-keyboard-*`：键盘映射设置中心正在使用。
- `omarchy-voice-*`：语音输入设置和录音转写正在使用。
- `omarchy-paste-at-cursor`：剪贴板和语音输入粘贴正在使用。
- `omarchy-launch-tui`、`omarchy-launch-floating-terminal-with-presentation`：语音 TUI 和 Windows VM 设置仍调用。
- `omarchy-theme-*` 中的 `theme-set`、`theme-bg-set`、`theme-current`、`theme-bg-next/cache/switcher`：主题和壁纸仍调用。
- `omarchy-system-lock`、`omarchy-system-logout`、`omarchy-system-wake`、`omarchy-launch-screensaver`：锁屏、退出、idle 仍调用。
- 部分 Hyprland 工具：窗口、显示器、亮度、音量、通知相关脚本仍可能被默认 Hyprland binding 调用。

低优先级或候选删除：

- `omarchy-install-*`、`omarchy-remove-*`、`omarchy-reinstall-*`：安装/卸载应用生态。
- `omarchy-refresh-*`：把默认模板刷新到用户配置的机制。
- `omarchy-pkg-*`：Arch/AUR 包管理辅助。
- `omarchy-hw-*`：硬件专项修复，除非当前机器明确依赖。
- `omarchy-menu*`：如果 Quickshell 设置中心和 app launcher 已覆盖菜单功能，可以逐步移除。
- Plymouth、SDDM、Limine、Waybar、SwayOSD、Chromium、Obsidian、Helix 等非核心集成。

## 推荐目标结构

长期建议把目录命名改成 OMD 自己的结构：

```text
oh-my-desktop/
├── quickshell/
├── apps/
├── hypr/
│   ├── hyprland.lua
│   ├── autostart.lua
│   ├── bindings.lua
│   ├── input.lua
│   ├── looknfeel.lua
│   ├── monitors.lua
│   └── lib/
├── bin/
│   ├── omd-restart
│   ├── omd-wallpaper
│   ├── omd-session
│   ├── omd-keyboard-apply
│   ├── omd-keyboard-render
│   ├── omd-voice-record
│   └── ...
├── scripts/
├── themes/
│   └── current/
├── config/
│   ├── walker/
│   ├── foot/
│   ├── kitty/
│   └── ...
└── docs/
```

兼容期可以保留：

```text
~/.config/omarchy -> ~/.config/omd/compat/omarchy 或 repo/omarchy
~/.local/share/omarchy -> ~/.config/omd/compat/share 或 repo/share
```

但最终目标应该是登录入口、Quickshell、Hyprland、设置中心都不再依赖这两个路径。

## 分阶段清理路线

### 阶段 0：冻结现状并生成依赖清单

目标：不删除任何东西，只把当前真实依赖列清楚。

动作：

- 运行引用扫描：

```sh
rg -n "omarchy-|default\\.hypr|~/.local/share/omarchy|\\.local/share/omarchy|\\.config/omarchy|share/bin|OMARCHY_PATH" quickshell apps bin scripts omarchy/hypr Init.sh
```

- 列出 `share/bin` 命令，并按引用情况分组。
- 记录当前 `hyprctl reload`、`~/.config/omd/bin/omd-restart`、`~/.config/omd/bin/omd-doctor` 的结果。
- 暂停大规模功能改动，避免清理过程中依赖关系继续漂移。

验收：

- 有一份“实际仍在调用的 Omarchy 命令列表”。
- 有一份“可以直接删除的文件/目录候选列表”。
- 当前桌面能正常登录、重载、重启 Quickshell。

### 阶段 1：建立 OMD 命名的兼容 wrapper

目标：先改调用名，不改实现。这样可以把 Quickshell 和 Hyprland 从 `omarchy-*` 命令名中解耦出来。

动作：

- 给仍在使用的脚本建立 `bin/omd-*` wrapper，例如：
  - `omd-keyboard-list` -> `share/bin/omarchy-keyboard-list`
  - `omd-keyboard-render` -> `share/bin/omarchy-keyboard-render`
  - `omd-keyboard-apply` -> `share/bin/omarchy-keyboard-apply`
  - `omd-voice-setup` -> `share/bin/omarchy-voice-setup`
  - `omd-voice-record` -> `share/bin/omarchy-voice-record`
  - `omd-paste-at-cursor` -> `share/bin/omarchy-paste-at-cursor`
  - `omd-lock` -> `share/bin/omarchy-system-lock`
- 修改 QML 和 OMD 脚本优先调用 `~/.config/omd/bin/omd-*`。
- 暂时保留 `share/bin/omarchy-*` 作为实现层。

验收：

- `rg "omarchy-keyboard|omarchy-voice|omarchy-paste-at-cursor"` 在 Quickshell 和 `bin/` 中明显减少。
- 键盘映射、语音输入、剪贴板粘贴、锁屏仍正常。

### 阶段 2：迁移 Hyprland 入口

目标：把 Hyprland 配置移出 `~/.config/omarchy` 命名空间，但先保持功能一致。

动作：

- 新建 OMD 自己的 Hyprland 配置目录，例如 `hypr/`。
- 把 `omarchy/hypr/*.lua` 迁移到 `hypr/*.lua`。
- 修改 `Init.sh`：
  - 新增 `~/.config/hypr` 或 `~/.config/omd-hypr` 指向新目录。
  - `/usr/local/bin/omd-hyprland-session` 改为加载新路径。
  - `PATH` 优先使用 `~/.config/omd/bin`。
- 保留旧 `~/.config/omarchy/hypr` 作为兼容，直到所有引用完成迁移。

验收：

- 重新登录后 Hyprland 从新路径启动。
- `hyprctl reload` 成功。
- Quickshell autostart 正常。

### 阶段 3：抽出最小 Hyprland 默认层

目标：断开 `require("default.hypr.omarchy")`。

动作：

- 在 `hypr/lib/` 建立 OMD 自己的 Lua helper：
  - `paths.lua`
  - `helpers.lua`
  - `windows.lua`
  - 必要的 `require_all.lua`
- 从 `share/default/hypr/` 复制并删减真正需要的默认行为：
  - 基础环境变量。
  - 必要输入规则。
  - 必要窗口规则。
  - 核心 tiling/window/workspace binding。
  - 媒体键如果还需要，就改成 Quickshell/系统工具直接实现，不再走 Omarchy 菜单。
- 移除默认 Omarchy 菜单、Waybar、first-run、post-boot hook、硬件菜单、包管理菜单、主题菜单等绑定。
- `hyprland.lua` 改为加载 OMD 自己的模块，不再 `require("default.hypr.omarchy")` 和 `require("default.hypr.toggles")`。

验收：

- `rg "default\\.hypr" hypr omarchy/hypr` 没有运行时引用。
- 临时移走 `share/default/hypr` 后，`hyprctl reload` 仍成功。
- 常用窗口管理、工作区、Quickshell overview、app launcher、语音、剪贴板快捷键正常。

### 阶段 4：迁移主题和壁纸

目标：让 Quickshell、Hyprland、锁屏、终端不再读取 `~/.config/omarchy/current/theme`。

动作：

- 决定主题策略：
  - 简化策略：只保留当前主题快照，后续主题由设置中心管理。
  - 完整策略：把 `share/themes` 迁移为 OMD 自己的 `themes/`，重写 `omd-settings-theme`。
- 新建 OMD 当前主题路径，例如 `~/.config/omd/current/theme`。
- 修改：
  - `quickshell/services/OmarchyTheme.qml`
  - `bin/omd-wallpaper`
  - `bin/omd-settings-theme`
  - `hyprlock.conf`
  - 终端配置 `foot/kitty/alacritty/ghostty`
  - Neovim 主题 drop-in
- 旧路径保留为 symlink 或兼容读路径。

验收：

- `rg "\\.config/omarchy/current|current/theme" quickshell bin hypr config omarchy` 中只剩兼容层或文档。
- 主题切换、壁纸切换、锁屏、终端颜色仍正常。

### 阶段 5：迁移 `share/bin` 的实际实现

目标：把真正属于 OMD 的脚本从 `share/bin/omarchy-*` 移到 `bin/omd-*` 或 `scripts/`。

动作：

- 键盘映射脚本迁移到 `bin/omd-keyboard-*` 或 `scripts/keyboard-*`。
- 语音输入脚本迁移到 `bin/omd-voice-*`。
- 粘贴、锁屏、退出、截图、亮度、音量等脚本按功能迁移。
- 每迁移一个命令，旧的 `omarchy-*` 可以变成兼容 wrapper，最后再删除。

验收：

- `PATH` 不再需要 `~/.local/share/omarchy/bin`。
- `rg "omarchy-" quickshell apps bin scripts hypr` 只剩兼容 wrapper、注释或文档。

### 阶段 6：删除 Omarchy 安装/模板/菜单生态

目标：删除已经不参与 OMD 运行的历史包。

优先删除候选：

- `share/install/`
- `share/config/`
- `share/default/` 中非 Hyprland 且未迁移的旧模板
- `share/bin/omarchy-install-*`
- `share/bin/omarchy-remove-*`
- `share/bin/omarchy-reinstall-*`
- `share/bin/omarchy-refresh-*`
- `share/bin/omarchy-pkg-*`
- `share/bin/omarchy-menu*`
- `share/bin/omarchy-hw-*` 中当前机器不用的专项修复
- Plymouth、SDDM、Limine、Waybar 等不再使用的默认资产

谨慎删除候选：

- `omarchy/walker`：如果 app launcher/clipboard 仍依赖 walker provider，需要先替换。
- `omarchy/fcitx5`：如果输入法配置仍由 repo 管理，需要明确迁移位置。
- `omarchy/foot`、`omarchy/kitty`、`omarchy/alacritty`、`omarchy/ghostty`：如果设置中心仍管理终端字体和主题，需要先迁移。
- `omarchy/current` 和 `share/themes`：必须等主题迁移完成。

验收：

- 删除候选目录后，重新登录、`hyprctl reload`、`omd-restart`、设置中心常用功能正常。
- `omd-doctor` 更新为检查 OMD 新路径，不再要求 Omarchy symlink。

## 风险点

- 登录入口风险最高。`/usr/local/bin/omd-hyprland-session` 一旦指向不存在的配置，会导致图形会话无法启动。
- `share/default/hypr` 现在提供了大量默认快捷键。断开后如果没有补齐核心窗口管理绑定，会感觉桌面“按键全坏了”。
- 主题路径同时被 Quickshell、Hyprland、hyprlock、终端、Neovim 使用，迁移时要一次性提供兼容路径。
- `PATH` 里移除 `~/.local/share/omarchy/bin` 前，必须确认所有运行时命令都有 OMD 版本。
- `Init.sh` 现在既安装依赖又创建 symlink，还写系统 session 文件。清理时要把“安装器清理”和“运行时清理”分开做。

## 建议的第一批实际改动

第一批不要删文件，建议只做低风险重命名和入口准备：

1. 新增 OMD wrapper：键盘、语音、粘贴、锁屏、主题、壁纸相关命令。
2. 修改 Quickshell 和 `bin/omd-*` 优先调用 OMD wrapper。
3. 新增 `hypr/lib/paths.lua` 和 `hypr/lib/helpers.lua`，先不接入。
4. 修改 `omd-doctor`，让它同时报告 Omarchy 旧依赖数量。
5. 新增一个清理检查脚本，例如 `scripts/audit-omarchy-deps`，输出剩余 `omarchy-*` 和 `~/.config/omarchy` 引用。

完成这批后，再进入 Hyprland 入口迁移。这样每一步都可以回滚，并且不会在还没建立替代路径时把当前桌面拆掉。

## 最终完成标准

清理完成后应该满足：

- `Init.sh` 不再创建 `~/.config/omarchy` 和 `~/.local/share/omarchy` 作为必需 symlink。
- `/usr/local/bin/omd-hyprland-session` 从 OMD 自己的 Hyprland 路径启动。
- Hyprland 配置不再 `require("default.hypr.*")`。
- Quickshell 不再读取 `~/.config/omarchy/current/theme`。
- `PATH` 不再需要 `~/.local/share/omarchy/bin`。
- `rg "omarchy-" quickshell apps bin scripts hypr` 没有运行时硬依赖。
- 键盘映射、语音输入、剪贴板、壁纸、主题、锁屏、退出、overview、app launcher、session restore 都仍可用。

