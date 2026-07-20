# Sumika Shell 迁移 — 交接给执行智能体的描述

## 当前进度

已完成 Phase 0–3 + Phase 4 域 1–2（共 7 个 commit）：

| Phase | 状态 | Commit |
|-------|------|--------|
| 0: 修复 Init.sh 基线 | ✅ | `83a5b50` |
| 1: 引入路径 API (lib/paths.sh + paths.lua) | ✅ | `7858871` + `50ea54d` |
| 2: 启动链摆脱 symlink | ✅ | `12a3b45` |
| 3: 迁移工具 sumika-migrate.sh | ✅ | `2433a45` |
| 4 域 1: 通知静音配置 | ✅ | `e4dfb7a` |
| 4 域 2: 键盘映射配置 | ✅ | `d8906ca` |
| 4 域 3: 文件共享备份 | ⬜ **从这里开始** | — |
| 4 域 4: 个人启动器 | ⬜ | — |
| 4 域 5: Quickshell config 拆分 | ⬜ | — |
| 5: 主题和壁纸状态迁移 | ⬜ | — |
| 6: 删除 symlink | ⬜ | — |
| 7: 删除 git 中的个人数据 | ⬜ | — |
| 8: 改名 Sumika Shell | ⬜ | — |

## 路径约定（所有迁移必须遵守）

```
SUMIKA_SHELL_ROOT         = 仓库根目录（代码 + 资产）
SUMIKA_SHELL_CONFIG_HOME  = ~/.config/sumika-shell/（用户手写配置）
SUMIKA_SHELL_STATE_HOME   = ~/.local/state/sumika-shell/（生成状态）
OMD_ROOT                  = SUMIKA_SHELL_ROOT 的兼容别名
```

Shell 脚本：`. "$_omd_root/lib/paths.sh"` 获取所有变量。
Lua：`local paths = require("default.hypr.paths")`，用 `paths.omd_root`、`paths.config_home`、`paths.state_home`。
QML：`Directories.config + "/sumika-shell"` 构造 config 路径（不能用 `Qt.environmentVariable`，这个 Qt 版本不支持）。

## 迁移规则

- **读**：新路径优先，旧路径 fallback
- **写**：只写新路径
- 每个 commit 一个域
- 源数据不删（Phase 7 才删）
- 每次改完重启 Quickshell 验证：`/home/tetsuya/development/OMD/bin/omd-restart`
- IPC 测试：`qs -p /home/tetsuya/development/OMD/apps/omd-bar ipc call voice toggle`

## 立即要做的：Phase 4 域 3 — 文件共享备份

### 需要改的文件

**1. `bin/omd-backup`（shell）**
- 行 8: `CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omd/file-share-backup"`
  → 改为 `"${SUMIKA_SHELL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/sumika-shell}/file-share-backup"`
- 行 10: `STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omd/file-share-backup"`
  → 改为 `"${SUMIKA_SHELL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/sumika-shell}/file-share-backup"`
- 加 legacy fallback：如果新 CONFIG_DIR 不存在但旧的 `${XDG_CONFIG_HOME:-$HOME/.config}/omd/file-share-backup` 存在，读取旧路径

**2. `bin/omd-settings-backup-tui`（Python）**
- 行 21: `CONFIG_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", ...), "omd", "file-share-backup")`
  → 改为用 `SUMIKA_SHELL_CONFIG_HOME` 环境变量，fallback 到 `~/.config/sumika-shell`
- 行 23: `STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME", ...), "omd", "file-share-backup")`
  → 改为用 `SUMIKA_SHELL_STATE_HOME` 环境变量，fallback 到 `~/.local/state/sumika-shell`
- 加 legacy fallback：读 CONFIG_FILE 时如果新路径不存在，尝试旧路径

### 参考已完成的域 1/2 的模式

看 `quickshell/services/Notifications.qml` 的 `mutedAppsFilePath` / `mutedAppsFilePathLegacy` 和 `bin/omd-settings-keyboard-tui` 的 `_profiles_path()` / `load_profiles()` 作为模板。

### Commit 信息

```
refactor(backup): move private backup config outside repository

bin/omd-backup:
- CONFIG_DIR → $SUMIKA_SHELL_CONFIG_HOME/file-share-backup
- STATE_DIR → $SUMIKA_SHELL_STATE_HOME/file-share-backup
- Legacy fallback for reads from old ~/.config/omd/file-share-backup

bin/omd-settings-backup-tui:
- Same path migration with legacy fallback

Phase 4 domain 3 of Sumika Shell migration plan.
```

## 后续待做的工作概要

### Phase 4 剩余域

**域 4: 个人启动器** — `launchers/*.desktop` + `launchers/icons/*`
- 改 `bin/omd-settings`、`bin/omd-settings-windows-vm` 中引用 `~/.config/omd/launchers/` 的地方
- 可能需要安装 desktop 文件到 `~/.local/share/applications/`
- 相关 QML：`quickshell/modules/settings/pages/WindowsVmPage.qml`（有 5 处 `.config/omd`）

**域 5: Quickshell config 拆分**
- `quickshell/config.json` → defaults 在 repo (`defaults/config/quickshell/config.json`)，user overrides 在 `~/.config/sumika-shell/quickshell/config.json`
- 启动时合并生成运行时 config 到 `~/.local/state/sumika-shell/quickshell/config.json`
- 影响：`bin/omd-restart`、`quickshell/scripts/quickshell`、所有 split app launchers

### Phase 5: 主题和壁纸状态
- `current/theme.name` → `~/.local/state/sumika-shell/theme/current-name`
- `current/theme/` → `~/.local/state/sumika-shell/theme/current/`
- `current/wallpaper`、`current/background` → `~/.local/state/sumika-shell/wallpaper/`
- 影响：`bin/omd-wallpaper`、`bin/omd-theme-bg-set`、`hypr/default/hypr/base.lua`、`hypr/default/hypr/envs.lua`、Quickshell 主题加载、终端主题加载、主题切换 TUI
- 这是影响最大的迁移，需要同时更新所有读写点

### Phase 6: 删除 symlink
- `Init.sh` 不再创建 `~/.config/omd → repo`
- 创建 `~/.config/sumika-shell` 为真实目录
- 更新 `omd-doctor` 检查
- 加 CI 检查：`rg '~/.config/omd' bin scripts share hypr quickshell apps`

### Phase 7: 删除 git 中的个人数据
- `git rm -r current/ keyboard-remap/profiles.json launchers/ notifications/`
- 在 `defaults/` 放中立默认配置
- 更新 `.gitignore`

### Phase 8: 改名
- README、文档、窗口标题改成 Sumika Shell
- 保留 `omd-*` 命令兼容

## 剩余的 .config/omd 引用分布（72 处）

大部分集中在：
- `quickshell/` QML 文件（~20 处）— 需要逐个改成 `Directories.config + "/sumika-shell"`
- `bin/` 脚本（~30 处）— 大部分已有 `OMD_ROOT` fallback，但有些直接用 `$HOME/.config/omd`
- `hypr/` Lua（~10 处）— 已在 Phase 2 改了主要的，剩余的是 fallback 路径

## 关键注意事项

1. **QML 不能用 `Qt.environmentVariable()`** — 这个 Qt 版本不支持。用 `Directories.config + "/sumika-shell"` 构造路径。
2. **IPC 路径一致性** — Quickshell 进程的 `-p` 路径和 IPC 调用方的路径必须完全一致。当前都用 `paths.omd_root`（已解析 symlink），所以一致。
3. **不要碰 session wrapper** — 已经在 Phase 2 更新了，下次 relogin 生效。
4. **每次改完验证** — `omd-restart` + IPC 测试 + `hyprctl configerrors`