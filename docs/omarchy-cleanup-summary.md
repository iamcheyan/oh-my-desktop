# Omarchy 清理实施汇总

分支：`omd-omarchy-cleanup`

这次清理的目标是把运行入口收敛到 OMD 自己的 Quickshell 和 Hyprland，同时删除不再作为运行时基础的 Omarchy 默认配置、安装器模板和旧用户配置目录。

## 已完成的结构迁移

- `omarchy/hypr/` 迁移到 `hypr/`。
- `omarchy/current/` 迁移到 `current/`。
- `omarchy/{foot,kitty,alacritty,ghostty,walker,fcitx5,nvim}` 迁移到 `config/`。
- `omarchy/voice_bindings.txt` 迁移到 `config/voice_bindings.txt`。
- Hyprland 默认层从 `share/default/hypr/` 复制到 `hypr/default/hypr/`，运行时不再需要 `~/.local/share/omarchy/default`。
- 删除旧 `omarchy/` 目录剩余配置。
- 删除 `share/default/`、`share/config/`、`share/install/` 等 Omarchy 框架模板和安装资产。
- 保留 `share/bin/` 和 `share/themes/`：
  - `share/bin/` 仍作为 legacy implementation，被 OMD wrapper 调用。
  - `share/themes/` 仍作为设置中心主题列表来源。

## 启动入口变化

- `Init.sh` 不再创建：
  - `~/.config/omarchy`
  - `~/.local/share/omarchy`
- `Init.sh` 现在创建：
  - `~/.config/omd -> repo`
  - `~/.config/quickshell -> repo/quickshell`
  - `~/.config/walker -> repo/config/walker`
  - `~/.config/{foot,kitty,alacritty,ghostty} -> repo/config/*`
- `/usr/local/bin/omd-hyprland-session` 现在从：
  - `~/.config/omd/hypr/hyprland.lua`
  启动 Hyprland。
- session `PATH` 不再加入 `~/.local/share/omarchy/bin`，只需要 `~/.config/omd/bin`。

## Hyprland 变化

- `hypr/hyprland.lua` 从 `~/.config/omd/hypr` 和 repo 根加载 Lua 模块。
- `hypr/default/hypr/paths.lua` 改为 OMD 路径：
  - `paths.omd_root`
  - `~/.local/state/omd`
- 当前主题覆盖从 `~/.config/omd/current/theme/hyprland.lua` 加载。
- 可选窗口规则从 `~/.config/omd/hypr/window_rules.lua` 加载，设置中心写入后会生效。
- `hypr/hypridle.conf` 改用：
  - `omd-lock`
  - `omd-wake`
  - `omd-launch-screensaver`
- `hypr/hyprlock.conf` 改读：
  - `~/.config/omd/current/theme/hyprlock.conf`
  - `~/.local/state/omd/toggles/hyprlock.conf`
- 复制出的默认 autostart 删除了 Waybar、first-run 和 post-boot hook 启动项。

## OMD 命令兼容层

新增 `bin/omd-legacy-omarchy`，并为仍需要的 legacy 实现提供 `omd-*` symlink。

主要新增入口包括：

- `omd-keyboard-*`
- `omd-voice-*`
- `omd-paste-at-cursor`
- `omd-launch-tui`
- `omd-launch-floating-terminal-with-presentation`
- `omd-lock`
- `omd-logout`
- `omd-wake`
- `omd-reboot`
- `omd-shutdown`
- `omd-font-current`
- Hyprland/brightness/audio/capture 等默认快捷键需要的 `omd-*` wrapper

注意：这些 wrapper 目前仍复用 `share/bin/omarchy-*` 的实现，但调用方已经不再直接依赖 `omarchy-*` 命令名，也不需要 `~/.local/share/omarchy/bin` 进入 `PATH`。

## 主题和壁纸变化

- `quickshell/services/OmarchyTheme.qml` 的主题路径改为：
  - `~/.config/omd/current/theme/quickshell.json`
- `bin/omd-settings-theme` 已重写：
  - 直接读取 `~/.config/omd/themes` 和 `~/.config/omd/share/themes`
  - 直接写入 `~/.config/omd/current/theme`
  - 不再调用 `omarchy-theme-set`
- 新增 OMD 自己的 `bin/omd-theme-bg-set`：
  - 更新 `~/.config/omd/current/background`
  - 同步 `quickshell/config.json` 的 wallpaperPath
  - 重启 `swaybg`
- 终端配置已经改读：
  - `~/.config/omd/current/theme/*`
- Walker 主题 import 修正为从 `config/walker/themes/omd` 回到 repo 的 `current/theme/walker.css`。

## Quickshell 和脚本调用变化

- 语音输入改为调用 `~/.config/omd/bin/omd-voice-*`。
- 键盘映射改为调用 `~/.config/omd/bin/omd-keyboard-*`。
- 粘贴改为调用 `omd-paste-at-cursor`。
- 设置中心语音绑定改读写 `~/.config/omd/config/voice_bindings.txt`。
- 设置中心主题文件夹打开路径改为 `~/.config/omd/current/theme`。
- 设置中心窗口规则文件改为 `~/.config/omd/hypr/window_rules.lua`。
- session lock/logout 改为 `~/.config/omd/bin/omd-lock` 和 `omd-logout`。
- `omd-doctor` 改为检查新的 OMD symlink 和当前背景路径。

## 保留的兼容内容

这些内容还保留，原因是它们仍有实际价值：

- `share/bin/`：legacy 实现层。下一轮可以逐个把脚本改名/搬到 `bin/` 或 `scripts/`，再删除旧文件。
- `share/themes/`：主题库。后续可以迁移到 repo 根目录 `themes/`。
- `share/polkit-1/rules.d/50-omd-keyboard.rules`：键盘映射 setup 仍需要安装这条 polkit 规则。
- QML singleton 名称 `OmarchyTheme.qml` 暂时未改名，避免一次性牵动大量 QML import 和引用。它的实际读取路径已经改为 OMD。

## 已做验证

- `bash -n` 通过：
  - `Init.sh`
  - 新增/修改的 `bin/omd-*`
  - 修改过的关键 `share/bin/omarchy-*` legacy 实现
- `luajit` 基础解析通过：
  - `hypr/hyprland.lua`
  - `hypr/default/hypr/paths.lua`
  - `hypr/default/hypr/helpers.lua`
  - `hypr/default/hypr/base.lua`
  - `hypr/bindings.lua`
  - `hypr/autostart.lua`
- 运行路径扫描没有再发现 `~/.config/omarchy`、`~/.local/share/omarchy`、`share/default`、`OMARCHY_PATH` 等硬路径依赖。

## 建议人工核对

合并或切换到该分支后，建议按这个顺序核对：

1. 运行 `./Init.sh`，确认 symlink 更新。
2. 重新登录 `Oh My Desktop` session。
3. 运行 `hyprctl reload`。
4. 运行 `~/.config/omd/bin/omd-restart`。
5. 打开设置中心，检查：
   - 主题列表和主题切换
   - 壁纸切换
   - 键盘映射读取、修改、应用
   - 语音输入快捷键列表和测试
6. 测试快捷键：
   - overview
   - app launcher
   - clipboard
   - voice input
   - lock/logout
   - brightness/audio media keys
7. 运行 `~/.config/omd/bin/omd-doctor`。

## 后续可继续精简

这次已经完成运行入口去 Omarchy 化，但还有两个可以继续收敛的方向：

- 把 `share/bin/omarchy-*` 中仍被 wrapper 使用的脚本逐个迁移为真正的 `bin/omd-*` 实现。
- 把 `share/themes/` 迁移为根目录 `themes/`，让 repo 结构彻底摆脱 Omarchy 历史命名。
