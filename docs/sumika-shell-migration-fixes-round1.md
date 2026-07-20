# Sumika Shell 迁移修复 — 第一轮

> 审查发现 7 个问题，实际修复涉及 12 个文件修改，涵盖 4 个域。
> 2026-07-20

---

## 1. Migrator — 迁移脚本时序修复

### 1.1 `scripts/sumika-migrate.sh` — copy_dir 不跳过已有目录

**问题**：`copy_dir()` 用 `mkdir && cp` 而非 `cp -r`，目标已存在时直接静默跳过，导致壁纸主题等旧数据全部丢失。

**修复**：改用 `cp -r "$src"/* "$dest"`，目标存在时合并内容。

### 1.2 `scripts/sumika-migrate.sh` — 移除 create_directories 中的 6 个冲突子目录

**问题**：`create_directories()` 预创建了 `toggles/`、`applauncher/`、`display/`、`session/`、`voice/`、`file-share-backup/` 等子目录。`copy_dir` 发现目标存在则跳过，导致后续 `copy_dir` 永远无法写入这些目录。

**修复**：`create_directories()` 只创建 sumika-shell 根目录，不创建子目录。数据由各路 `copy_dir` 调用单独写入。

### 1.3 `Init.sh` — 迁移在符号链接创建之后运行

**问题**：`create_symlinks` 先运行，将 `~/.config/omd` 替换为指向 repo 的符号链接；之后 `sumika-migrate.sh` 读取 `~/.config/omd` 得到的是空 repo 而非旧用户数据。

**修复**：将 `sumika-migrate.sh` 调用提前到 `create_symlinks` 之前，确保读取真实旧数据目录。

### 1.4 `scripts/sumika-migrate.sh` — OLD_CONFIG 路径歧义

**问题**：`OLD_CONFIG="${OMD_ROOT:-$HOME/.config/omd}"`。首次运行时 Symlink 尚未创建，`~/.config/omd` 是真实数据目录 — 正确。但 `OMD_ROOT` 可能指向 repo 根目录导致误读。

**修复**：改为固定 `OLD_CONFIG="$HOME/.config/omd"`，忽略 `OMD_ROOT` 环境变量。注释说明顺序依赖：首次运行先迁移后建符号链接。

---

## 2. State paths — 残留 `~/.local/state/omd` 引用迁移

### 2.1 `quickshell/modules/settings/pages/AppearancePage.qml`

**问题**：壁纸轮播间隔写入 `$HOME/.local/state/omd/wallpaper/interval`。

**修复**：改成 shell one-liner 通过 `SUMIKA_SHELL_STATE_HOME`（fallback `XDG_STATE_HOME` then `~/.local/state`）构造 sumika-shell 路径。

### 2.2 `quickshell/modules/bar/BarStatusPopup.qml`

**问题**：session snapshot 路径硬编码为 `$HOME/.local/state/omd/session/last.json`。

**修复**：改为 `Directories.stateHome/sumika-shell/session/last.json`。

### 2.3 `bin/omd-applauncher` + `bin/omd-applauncher-cache`

**问题**：app launcher cache 路径 `$HOME/.local/state/omd/applauncher/apps.json`。

**修复**：分别改为 `$SUMIKA_SHELL_STATE_HOME/applauncher/apps.json`。`omd-applauncher-cache` 在文件头加 XDG fallback 环境变量初始化。

### 2.4 `apps/omd-applauncher/modules/appLauncher/AppLauncher.qml`

**问题**：QML 侧 cacheFile 同样硬编码 `~/.local/state/omd/...`。

**修复**：改为 `${SUMIKA_SHELL_STATE_HOME}/applauncher/apps.json`，fallback `${HOME}/.local/state/sumika-shell/...`。

### 2.5 `hypr/autostart.lua`

**问题**：`mkdir -p $HOME/.local/state/omd/toggles` 用于 waybar 开关标记。

**修复**：通过 `os.getenv("SUMIKA_SHELL_STATE_HOME")` 构造 sumika-shell 路径。

### 2.6 Key-capture 状态文件（5 个文件）

涉及以下文件中 `~/.local/state/omd/key-capture.json` 的引用：
- `quickshell/modules/settings/pages/VoicePage.qml`
- `bin/omd-settings-voice`
- `scripts/key-test`
- `scripts/keyremap-capture-read`
- `scripts/voice-bind-tui`

所有文件统一改为 `SUMIKA_SHELL_STATE_HOME/sumika-shell/key-capture.json`（XDG fallback）。

### 2.7 `bin/omd-settings-voice` — voice runtime state

另发现 `STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omd/voice"` 残留，已改为 sumika-shell/voice/。

---

## 3. Infrastructure — 诊断/路径/Lua 修复

### 3.1 `bin/omd-doctor`

**问题**：`check_link "$HOME/.config/sumika-shell" "$repo"`。`~/.config/sumika-shell` 是由 chezmoi 管理的真实配置目录，不是 repo 符号链接 — check_link 永远 Failed。

**修复**：改为检查目录存在性 + 至少有一个配置文件（`quickshell/config.json`）。

### 3.2 `quickshell/modules/common/Directories.qml`

**问题**：`stateHome` 属性硬编码为 `Directories.home/.local/state`，不遵守 `XDG_STATE_HOME` 环境变量。

**修复**：改为 `Quickshell.env("XDG_STATE_HOME") ?? Directories.home/.local/state`。不做 `SUMIKA_SHELL_STATE_HOME` 检查 — QML 调用方在基路径后追加 `/sumika-shell/...`。

### 3.3 `hypr/default/hypr/paths.lua`

**问题**：Lua 端 root fallback 为 `config_home .. "/sumika-shell"`（即 `~/.config/sumika-shell`）。这是 chezmoi 管理的配置目录，不是 repo 根目录。

**修复**：root fallback 改为 `readlink -f ~/.config/omd`（解析 repo 符号链接），最后兜底为 `/dev/null/SUMIKA_SHELL_ROOT_UNSET`。

---

## 4. Verify — 语法检查

全部 12 个修改文件通过语法检查：
- Shell: `bash -n` — 6 个脚本全部通过
- Python: `py_compile` — 3 个脚本全部通过
- Lua: `luac -p` — 2 个模块全部通过

---

## 仓库状态

```
18 个文件未暂存 (staged 0, unstaged 18, untracked 1)
```
包括本轮 12 个修改 + 上一轮 Phase 5 遗留的 6 个代码编辑 + 1 个报告文件。

## 遗留

| 事项 | 状态 |
|---|---|
| 提交 Phase 5（18 个文件） | 待做 |
| chezmoi fcitx5 冲突 | 阻止全量 apply |
| 冒烟测试（wallpaper、theme switch、clipboard） | 待做 |
