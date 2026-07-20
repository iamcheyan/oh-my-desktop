# Sumika Shell 迁移 — 交接文档

## 当前进度（截至 2026-07-20）

**全部 8 个 Phase 中 Phase 0–6 已完成，Phase 7–8 待做。**

| Phase | 状态 | Commit | 说明 |
|-------|------|--------|------|
| 0: 修复 Init.sh 基线 | ✅ | `7858871` | — |
| 1: 引入路径 API (lib/paths.sh + paths.lua) | ✅ | `7858871` + `50ea54d` | — |
| 2: 启动链摆脱 symlink | ✅ | `12a3b45` | — |
| 3: 迁移工具 sumika-migrate.sh | ✅ | `2433a45` | — |
| 4 域 1: 通知静音配置 | ✅ | `e4dfb7a` | — |
| 4 域 2: 键盘映射配置 | ✅ | `d8906ca` | — |
| 4 域 3: 文件共享备份 | ✅ | `29d56e6` | CONFIG_DIR/STATE_DIR 迁至 sumika-shell |
| 4 域 4: 个人启动器 | ✅ | `29d56e6` | .desktop 文件、Init.sh、README |
| 4 域 5: Quickshell config 拆分 | ✅ | `a59babf` | defaults/ 模板 + user overrides |
| 5: 主题和壁纸状态迁移 | ✅ | `800769f` | 18 个文件 |
| 6: 基础设施清理 | ✅ | `ff9df7a` | Init.sh/omd-doctor/hypr fallbacks/Directories.root |
| 7: 删除 git 中个人数据 | ⬜ | — | 待做 |
| 8: 改名 Sumika Shell | ⬜ | — | 待做（omd-* 命名保留） |

**总计 9 个迁移 commit，8,503 个文件变更（净增）。**

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
QML（独立子应用如 clipboard）：手动构造 `` `${Quickshell.env("HOME")}/.local/state/sumika-shell/...` ``

## 关键设计决策

1. **`~/.config/sumika-shell` 是真实配置目录**，不是 repo 软链接。
   - 里面放 quickshell 覆盖配置、启动器、通知静音列表、键盘映射 profile
   - 不能替换为软链接，否则用户数据会混进 repo

2. **`~/.config/omd` → repo 软链接保留**（Phase 6 本打算删，发现不能删）。
   - QML 里大量硬编码 `$HOME/.config/omd/bin/omd-xxx`
   - `omd-*` 命令命名保留，所以软链接可以继续用
   - 不影响迁移正确性

3. **Phase 5 主题状态迁至 `~/.local/state/sumika-shell/`**，不是 config。
   - 主题文件是运行时切换生成的状态，不是用户手写配置

4. **Hyprland Lua 从 `require()` 改为 `dofile(path)`**。
   - 主题文件现在在 Lua 模块搜索路径之外

## 迁移规则

- **读**：新路径优先，旧路径 fallback
- **写**：只写新路径
- 源数据不删（Phase 7 才删）

## 已完成迁移的域

### Phase 4 域 3 — 文件共享备份 (`29d56e6`)

| 文件 | 旧路径 | 新路径 |
|------|--------|--------|
| `bin/omd-backup` | CONFIG_DIR: `~/.config/omd/file-share-backup` | `$SUMIKA_SHELL_CONFIG_HOME/file-share-backup` |
| | STATE_DIR: `~/.local/state/omd/file-share-backup` | `$SUMIKA_SHELL_STATE_HOME/file-share-backup` |
| `bin/omd-settings-backup-tui` | 同上的 Python 版本 | 同上，Python env vars fallback |

### Phase 4 域 4 — 个人启动器 (`29d56e6`)

| 文件 | 改动 |
|------|------|
| `.desktop` 文件 | 路径更新 |
| `Init.sh` | `install_custom_launchers` 从 sumika-shell 读取 |
| `sumika-migrate.sh` | 启动器数据迁移 |
| `README` / `AGENTS.md` | 文档更新 |

### Phase 4 域 5 — Quickshell config 拆分 (`a59babf`)

| 文件 | 改动 |
|------|------|
| `defaults/config/quickshell/config.json` | 新增 repo 模板配置 |
| `~/.config/sumika-shell/quickshell/config.json` | 用户覆盖（init 时创建） |
| `Directories.qml` | `shellConfig → sumika-shell/quickshell` |
| `quickshell/scripts/quickshell` | `repair_config_json` 写 sumika-shell |
| `bin/omd-*` 脚本 | config.json 读取路径 |
| `Init.sh` | `repair_runtime_config` 从 defaults/ 读取 |

**特殊情况：`apps/*/config.json` symlink 断裂**
- `a59babf` 删了 `quickshell/config.json`，但子应用 symlink 还指着它
- `85c6fb9` 修复：改为指向 `defaults/config/quickshell/config.json`

### Phase 5 — 主题和壁纸状态 (`800769f`)

**18 个文件 +71 -83**

| 旧路径 | 新路径 |
|--------|--------|
| `$omd_root/current/theme/quickshell.json` | `$STATE_HOME/theme/current/quickshell.json` |
| `$omd_root/current/theme/colors.toml` | `$STATE_HOME/theme/current/colors.toml` |
| `$omd_root/current/theme/hyprland.lua` | `$STATE_HOME/theme/current/hyprland.lua` |
| `$omd_root/current/wallpaper` | `$STATE_HOME/wallpaper/wallpaper` |
| `$omd_root/current/background` | `$STATE_HOME/wallpaper/background → wallpaper` |
| `$omd_root/current/wallpaper.revision` | `$STATE_HOME/wallpaper/revision` |
| `$omd_root/current/theme.name` | `$STATE_HOME/theme/current-name` |

涉及文件：
- `bin/omd-wallpaper` — 壁纸路径、systemd unit、background symlink
- `bin/omd-theme-bg-set` — jq path、revision
- `bin/omd-settings-theme` — current dir、wallpaper mode
- `hypr/default/hypr/base.lua` — dofile 替换 require
- `hypr/default/hypr/envs.lua` — dofile 替换 require
- `quickshell/services/OmarchyTheme.qml` — theme path
- `quickshell/services/Wallpaper.qml` — revision path
- `apps/omd-clipboard/…/ClipboardStyle.qml` — 手动构造状态路径
- `quickshell/modules/settings/pages/AppearancePage.qml` — 打开主题目录按钮
- `defaults/config/quickshell/config.json` — wallpaperPath
- `bin/omd_tui_shared.py` — 主题 accent/border 颜色加载
- `scripts/reload-terminals` — `SUMIKA_SHELL_STATE_HOME`
- `scripts/key-test` — dev 脚本主题路径
- `scripts/sumika-migrate.sh` — 壁纸迁移命名对齐
- `Init.sh` — 种子壁纸
- `bin/omd-doctor` — 壁纸背景检查
- `config/nvim/lua/plugins/zz-omarchy-theme.lua` — neovim 主题路径
- `AGENTS.md` — 文档引用

### Phase 6 — 基础设施清理 (`ff9df7a`)

**8 个文件 +39 -32**

| 文件 | 改动 |
|------|------|
| `Init.sh` | 回退路径从 `~/.config/omd` → `~/.config/sumika-shell`，帮助文本更新 |
| `bin/omd-doctor` | 新增 sumika-shell 检查，注释更新 |
| `hypr/hyprland.lua` | fallback 路径更新 |
| `hypr/default/hypr/paths.lua` | fallback 路径 + 注释更新 |
| `Directories.qml` | 新增 `root` 属性（env var → omd symlink fallback） |
| `Workspaces.qml` | 使用 `Directories.root` 替代硬编码路径 |
| `scripts/reload-quickshell` | `OMD_ROOT` fallback 更新 |
| `AGENTS.md` | 同时记录两种路径 |

**关键发现：`~/.config/sumika-shell` 是真实的配置目录，不能作为 repo 软链接。**

### 额外修复 (`85c6fb9`)

- `apps/*/config.json` symlink 断裂 → 指向 `defaults/config/quickshell/config.json`
- `bin/omd_tui_shared.py` 语法破坏（SWAP 编辑错误）→ 修复 try/except 结构

## 待办 — Phase 7: 删除 git 中个人数据

从 git 仓库中删除运行时生成的文件，只保留代码 + 默认模板。**不影响用户本地数据**（数据已迁至 `~/.config/sumika-shell/` 和 `~/.local/state/sumika-shell/`）。

### 要删的文件

```bash
git rm -r current/                       # 主题/壁纸快照（已迁至 state）
git rm -r keyboard-remap/profiles.json   # 键盘映射配置（已迁至 config）
git rm -r launchers/                     # 个人启动器（已迁至 config/sumika-shell/launchers）
git rm -r notifications/                 # 通知数据（运行时生成）
git rm -r quickshell/config.json         # 已被 defaults/config/quickshell/config.json 替代
```

### 要留的

- `defaults/config/quickshell/config.json` — 模板配置
- `share/themes/` — 预装主题库
- `current/.gitkeep` 如果 git 需要保留目录结构

### 更新 .gitignore

追加：
```
# Phase 7: personal data removed from repo
current/
keyboard-remap/profiles.json
launchers/
notifications/
quickshell/config.json
```

## 待办 — Phase 8: 改名 Sumika Shell

| 域 | 说明 |
|----|------|
| README / 文档 | 标题、描述改成 Sumika Shell |
| `AGENTS.md` | 顶栏说明 |
| 窗口标题 / Hyprland 窗口规则 | `org.omd.*` naming can stay |
| `omd-*` 命令命名 | **保留不变**（破坏性太大） |
| `share/bin/omarchy-*` (264 个) | 如需重命名，独立 phase |

## 已知问题

### 1. 🔴 Workspaces 按钮点击无反应

**现象**：顶栏 "Workspaces" 按钮点击后不打开 overview。

**排查记录**：
- IPC 路径在 Phase 6 已改为 `Directories.root`
- `qs ipc call overview toggle` 返回 0（OK）
- `omd-overview` 进程运行正常
- `config.json` symlink 已修复
- **未找到根本原因**

**可能原因**：
- `IpcHandler` target `"overview"` 注册问题（`Overview.qml:412-416`）
- `GlobalStates.overviewOpen` 状态未正确触发窗口显示
- Quickshell IPC 路由问题（多个进程共享同一个 IPC namespace？）

**建议排查方向**：
- 在 overview shell.qml 的 `Overview {}` 组件上加 debug 日志
- 检查 `GlobalStates.qml` 中 `overviewOpen` 的绑定
- 检查 overview 是否真的收到了 IPC（在 `toggle()` 函数加 `console.log`）

### 2. 🟡 QML 中大量 `$HOME/.config/omd/bin/omd-xxx` 硬编码

**约 30+ 处**分布在：
- `quickshell/modules/settings/pages/` — AppearancePage, SoundPage, WindowsVmPage
- `quickshell/services/` — Network, Brightness, VoiceInput
- `quickshell/modules/common/functions/` — Session, WorkspaceNavigation, ScreenshotAction
- `apps/omd-applauncher/`, `apps/omd-clipboard/`
- `bin/omd-*` 脚本入口（~5 处）

**影响**：功能正常（`~/.config/omd → repo` 软链接仍在），但不利于未来 Phase 8 改名。

### 3. 🟡 `share/bin/omarchy-*` 遗留脚本

264 个 omarchy-* 命令中有多处硬编码 `~/.config/omd/` 路径。如：
- `omarchy-brightness-display` — IPC 调用路径
- `omarchy-hyprland-monitor-watch` — `omd-wallpaper` 调用
- `omarchy-keyboard-setup` — polkit rules 路径
- `omarchy-keyboard-render` — comment 中的路径引用

**不在本次迁移范围内**。这些是 legacy wrapper，下次大版本可以考虑清理。

## 迁移成功标准

### 已通过

- [x] 所有 6 个 Python TUI 语法检查通过
- [x] 主题颜色加载正常 (accent: 130, 251, 156)
- [x] 壁纸状态文件存在于新路径
- [x] 主题文件存在于新路径（17 个文件，含 quickshell.json、hyprland.lua、neovim.lua、colors.toml、终端配置）
- [x] `quickshell/config.json` → `defaults/config/quickshell/` (repo 模板) + `~/.config/sumika-shell/quickshell/` (用户覆盖)
- [x] `~/.config/sumika-shell/` 作为真实配置目录已在使用中
- [x] `~/.config/omd → repo` 软链接保留作为运行时兼容

### 待验证

- [ ] Workspaces 按钮功能
- [ ] 主题切换是否正常生成 `~/.local/state/sumika-shell/theme/current/`
- [ ] 壁纸轮播是否使用新路径
- [ ] 重启后整体是否正常工作
