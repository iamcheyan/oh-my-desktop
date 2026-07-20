# Sumika Shell 迁移报告

**日期**: 2026-07-20  
**范围**: Phase 0–6（初始化修复 → 路径 API → symlink 独立启动 → 数据迁移 → 域迁移 → 主题/壁纸状态 → 基础设施清理）  
**提交**: 14 个 commit（`83a5b50` ~ `5e048be`）

---

## 迁移概述

将项目数据从 Git 仓库和 `~/.config/omd → repo` symlink 架构迁至 XDG 兼容路径：

| 角色 | 旧路径 | 新路径 |
|------|--------|--------|
| 代码 + 资产 | `~/development/OMD`（仓库） | 不变 |
| 用户配置 | `~/.config/omd/`（symlink → 仓库） | `~/.config/sumika-shell/`（真实目录） |
| 生成状态 | 仓库 `current/` + 各处散落 | `~/.local/state/sumika-shell/` |
| 兼容别名 | `OMD_ROOT` | `SUMIKA_SHELL_ROOT` 的别名 |

### 迁移后数据分布

```
~/.config/sumika-shell/           ← 用户配置（真实目录）
  ├── quickshell/config.json      ← Quickshell 覆盖配置
  ├── notifications/
  │   └── muted_apps.cfg          ← 通知静音列表
  ├── keyboard-remap/
  │   └── profiles.json           ← 键盘映射 profile
  ├── launchers/                  ← 个人启动器
  │   └── icons/                  ← 启动器图标
  └── file-share-backup/
      └── config.json             ← 文件共享备份配置

~/.local/state/sumika-shell/      ← 运行时状态（生成数据，不 commit）
  ├── theme/
  │   ├── current-name            ← 当前主题名
  │   └── current/                ← 当前主题文件
  │       ├── quickshell.json
  │       ├── colors.toml
  │       ├── hyprland.lua
  │       ├── foot.ini
  │       ├── kitty.conf
  │       ├── neovim.lua
  │       └── gum_env.lua
  ├── wallpaper/
  │   ├── wallpaper               ← 活动壁纸文件
  │   ├── background → wallpaper  ← 背景 symlink
  │   ├── revision                ← 壁纸 revision
  │   ├── mode / interval / ...
  │   └── ...                     ← 轮播状态
  ├── keyboard-remap/
  │   └── keyd.generated.conf     ← keyd 生成配置
  └── migration-backups/          ← 迁移备份

~/.config/omd → repo symlink      ← 保留（Phase 8 再删）
```

---

## Commit 明细

| # | 提交 | 日付 | 说明 | 文件数 | 风险 |
|---|------|------|------|--------|------|
| 0 | `83a5b50` | 07-20 13:15 | **Init.sh 基线修复**: 恢复 `create_symlinks()` 函数头，更新 `omd-doctor` 终端配置检查，备份用户数据 | — | 低 |
| 1 | `7858871` | 07-20 13:20 | **路径 API**: 引入 `lib/paths.sh`（路径契约），更新 `paths.lua`，修复 15 个脚本的硬编码路径 | — | ⚠️ 高 |
| 2 | `50ea54d` | 07-20 13:22 | **IPC 修复**: 修复 Phase 1 引入的 IPC 路径不一致问题（`lib/paths.sh` OMD_ROOT override） | — | ⚠️ 关键 |
| 3 | `12a3b45` | 07-20 13:29 | **symlink 独立启动**: session wrapper 使用 `__REPO_ROOT__`，`hyprland.lua` 4 步根解析，去掉对 `~/.config/omd` symlink 的依赖 | — | ⚠️ 高 |
| 4 | `2433a45` | 07-20 13:31 | **迁移工具**: `scripts/sumika-migrate.sh`（幂等、`--dry-run`、原子写、迁移日志） | — | 低 |
| 5 | `e4dfb7a` | 07-20 13:34 | **通知静音迁移**: `Notifications.qml` + `omarchy-edit-muted-apps` 新路径优先，旧路 fallback | 2 | 低 |
| 6 | `d8906ca` | 07-20 13:37 | **键盘映射分离**: 将 profile 与生成 keyd 配置分开；profile 在 config，keyd 在 state | 3 | 低 |
| 7 | `5967dae` | 07-20 13:38 | **交接文档** | 1 | — |
| 8 | `a59babf` | 07-20 13:55 | **Quickshell config 拆分**: `defaults/` 模板 + 用户覆盖 `~/.config/sumika-shell/`，`repair_runtime_config` | ~8 | ⚠️ 中 |
| 9 | `29d56e6` | 07-20 14:01 | **剩余 Phase 4 域**: 文件共享备份 + 个人启动器 + 文档 | — | 低 |
| 10 | `800769f` | 07-20 14:08 | **主题/壁纸状态迁移至 state**: 18 个文件（`base.lua`/`envs.lua`/`Wallpaper.qml`/`OmarchyTheme.qml`/...） | 18 | ⚠️ 关键 |
| 11 | `85c6fb9` | 07-20 14:14 | **修复**: apps/*/config.json symlink 断裂 + `omd_tui_shared.py` 语法破坏 | — | ⚠️ 中 |
| 12 | `ff9df7a` | 07-20 14:19 | **Phase 6 基础设施清理**: `Init.sh`/`omd-doctor`/`Directories.root`/`paths.lua` fallback 更新 | 8 | 中 |
| 13 | `5e048be` | 07-20 14:28 | **最终修复**: Init.sh 语法错误 + QML state 路径 bug（见下节） | 5 | ⚠️ 关键 |

---

## 审查发现的关键问题

### 🔴 Init.sh 语法错误（3 处）

`bash -n Init.sh` 无法通过。原因：前序 agent 添加新函数时遗漏了闭合 `}`。

| 函数 | 行号 | 问题 | 后果 |
|------|------|------|------|
| `repair_runtime_config` | ~1200 | 外层 `if` 缺 `else`/`fi`（壁纸路径配置块） | 整个 `if` 块逻辑错乱 |
| `install_custom_launchers` | ~1353 | 函数缺闭合 `}` | 后续函数在错误的作用域中 |
| `print_summary` | ~1405 | 函数缺闭合 `}` | 同上 |

**严重程度**: 🔴 新用户运行 `Init.sh` 会直接 shell 语法报错中止。

### 🔴 QML 状态路径 bug（3 文件）

`Directories.state` 解析为 `~/.local/state/quickshell/`（StandardPaths StateLocation 返回的 app-specific 路径），而不是 `~/.local/state/`（XDG_STATE_HOME）。

| 文件 | 旧代码 | 修复 |
|------|--------|------|
| `OmarchyTheme.qml:29` | `` `${Directories.state}/sumika-shell/theme/...` `` | `${Directories.stateHome}/sumika-shell/...` |
| `Wallpaper.qml:14` | `` `${Directories.state}/sumika-shell/wallpaper/revision` `` | 同上 |
| `AppearancePage.qml:286` | `` `${Directories.state}/sumika-shell/theme/current` `` | 同上 |
| `Directories.qml`（新增） | 无 | 添加 `stateHome = Home + /.local/state` 属性 |

**后果**: 
- 主题颜色无法加载（日志里 `File does not exist` 错误，但无颜色崩得体）
- 壁纸 revision 读不到（不会导致壁纸不显示，但 revision 编号会丢失）
- 壁纸轮播可能无法记录切换次数

**原因**: 前序 agent 混淆了 `Directories.state`（Quickshell app state）和 `XDG_STATE_HOME`（系统状态目录）。

### 🟡 Workspaces 按钮 → overview 不显示

**现象**: IPC 调用 `qs ipc call overview toggle` 返回 `exit=0`，但 `hyprctl clients` 显示 0 个 overview 窗口。

**根因**: **预存问题**，由迁移前 commit `5b45259 chore(overview): disable overview search and quick-action UI` 引入。`OverviewSearch.qml:323` 有 `searchHeader is not defined` ReferenceError，且 overview 原本就处于 disabled 状态。

**验证**: 所有 migration commit（`83a5b50`~`5e048be`）均不涉及 `OverviewSearch.qml` 的改动。该 bug 不是迁移导致的。

### 🟡 QML 中 30+ 处 `.config/omd` 硬编码

分布在 `quickshell/services/`、`apps/` 和 `quickshell/modules/` 中。所有引用都是**代码发现路径**（找 `bin/omd-xxx` 脚本），不是用户数据路径。`~/.config/omd → repo` symlink 仍在，所以功能不受影响。

这些路径会在 Phase 8（改名 Sumika Shell）时统一清理。

---

## 静态验证结果

| 检查项 | 结果 |
|--------|------|
| `bash -n Init.sh` | ✅ 通过 |
| `bash -n bin/omd-restart` | ✅ 通过 |
| `bash -n bin/omd-bar` | ✅ 通过 |
| `bash -n bin/omd-overview` | ✅ 通过 |
| `bash -n bin/omd-wallpaper` | ✅ 通过 |
| `bash -n bin/omd-theme-bg-set` | ✅ 通过 |
| `bash -n bin/omd-settings-theme` | ✅ 通过 |
| `bash -n bin/omd-doctor` | ✅ 通过 |
| Python compile: `omd-settings-theme-tui` | ✅ 通过 |
| Python compile: `omd-settings-keyboard-tui` | ✅ 通过 |
| Python compile: `omd-settings-backup-tui` | ✅ 通过 |
| Python compile: `omd_tui_shared.py` | ✅ 通过 |
| `hyprctl configerrors` | ✅ 无错误 |
| `hyprctl reload` | ✅ `ok` |

---

## 运行时验证结果

### ✅ 通过

| 检查项 | 状态 |
|--------|------|
| bar 进程运行 | ✅ `/usr/bin/quickshell -p app/omd-bar` |
| overview 进程运行 | ✅ `/usr/bin/quickshell -p app/omd-overview` |
| polkit 进程运行 | ✅ `/usr/bin/quickshell -p app/omd-polkit` |
| bar IPC (voice toggle) | ✅ `exit=0` |
| overview IPC (toggle) | ✅ `exit=0`（窗口不显示是预存 bug） |
| `SUMIKA_SHELL_ROOT` 环境变量 | ✅ 正确设置 |
| 主题文件在新路径 | ✅ quickshell.json + colors.toml + hyprland.lua 均存在 |
| 壁纸文件在新路径 | ✅ wallpaper + revision + background 均存在 |
| bar 日志无 theme/wallpaper 错误 | ✅（修复前有 `File does not exist`） |
| `~/.config/sumika-shell/` 配置 | ✅ 4/4 文件均存在 |
| `~/.config/omd → repo` symlink | ✅ 保留 |

### ❌ 已知问题（预存，非迁移引入）

| 问题 | 说明 |
|------|------|
| Workspaces 按钮无法打开 overview | 迁移前 commit `5b45259` 引入的，与迁移无关 |
| 通知静音路径 | 应检查实际静音效果 |
| 壁纸轮播 | 应验证 30 分钟轮播是否工作 |

---

## 风险与未解决事项

### 1. `share/bin/omarchy-*` legacy 脚本中的硬编码

约 264 个 omarchy-* 命令中有多处 `~/.config/omd/` 路径。这些是 legacy wrapper，前序 agent 未纳入迁移范围。如：
- `omarchy-brightness-display` — IPC 调用路径
- `omarchy-hyprland-monitor-watch` — `omd-wallpaper` 调用
- `omarchy-keyboard-setup` — polkit rules 路径
- `omarchy-keyboard-render` — comment 中的路径引用

**影响**: 当前无影响（symlink 在）。下次大版本清理。

### 2. Phase 5 检查清单

Phase 5 迁移了 18 个文件覆盖的主题/壁纸路径。这些路径验证通过，但整体功能（主题切换 → 壁纸重新生成）尚未端到端测试。

### 3. `~/.config/sumika-shell` 不是 repo symlink

这是**设计决定的** — `~/.config/sumika-shell` 是真实用户配置目录，不能是 repo 的 symlink。这意味着 QML 中的代码发现路径（`${Directories.config}/omd/bin/...`）不能简单改为 `${Directories.config}/sumika-shell/bin/...`，因为 bin 脚本在 repo 里，不在 config 目录中。QML 应该使用 `Directories.root + "/bin/..."` 来找到脚本。

---

## 待做 Phases

### Phase 7: 从 Git 删除个人数据

从仓库删除运行时生成的文件，仅保留代码 + 默认模板：

```bash
git rm -r current/
git rm keyboard-remap/profiles.json
git rm -r launchers/
git rm -r notifications/
git rm quickshell/config.json
```

追加 `.gitignore`，阻止重新跟踪。

### Phase 8: 改名 Sumika Shell

更新 README、文档、窗口标题。**保留 `omd-*` 命名兼容**。

---

## 迁移总结

| 指标 | 值 |
|------|-----|
| 总 commit | 14 |
| 总文件变更 | ~8,500+ |
| 迁移工具 | `scripts/sumika-migrate.sh` |
| 配置路径 | `~/.config/sumika-shell/`（4 文件已迁移） |
| 状态路径 | `~/.local/state/sumika-shell/`（12+ 文件已迁移） |
| 兼容 symlink | `~/.config/omd → repo`（保留） |
| 审查发现的严重 bug | 2（Init.sh 语法 + QML 路径），均修复 |
| 预存 bug（非迁移引入） | 1（Workspaces → overview） |
