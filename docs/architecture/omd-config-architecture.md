# OMD `~/.config/omd` 架构重构

## 问题

当前 `~/.config/omd` 是一个 **symlink** 指向 `~/development/OMD`（整个项目仓库）。

```
~/.config/omd ──symlink──→ ~/development/OMD/
                                ├── hypr/
                                ├── bin/
                                ├── quickshell/
                                ├── current/        ← 用户数据（主题状态、壁纸）
                                ├── icons/
                                ├── keyboard-remap/ ← 用户数据
                                ├── launchers/      ← 用户数据
                                ├── notifications/  ← 用户数据
                                └── file-share-backup/ ← 用户数据（.gitignore 已排除）
```

这违反了 XDG 规范——`~/.config/omd` 应该只放**用户数据**（运行时配置、状态、主题快照），而不是成为整个开发目录的入口。

### 当前靠 symlink 工作的原因

整个项目大量引用 `~/.config/omd/...` 来发现代码：

| 引用方 | 例子 | 数量 |
|--------|------|------|
| `hypr/bindings.lua` | `$HOME/.config/omd/bin/omd-applauncher` | ~15 处 |
| `hypr/default/hypr/paths.lua` | `omd_root = os.getenv("OMD_ROOT") or (config_home.."/omd")` | 核心变量 |
| `hypr/default/hypr/*.lua` | `paths.omd_root .. "/bin/omd-screenshot"` | ~5 处 |
| Quickshell QML | `Directories.config + "/omd"` | 少量 |
| `bin/*` 脚本 | `$OMD_ROOT/...` | 几十处（已用 env var） |

路径系统已有 `OMD_ROOT` 环境变量（`paths.lua` 中 `os.getenv("OMD_ROOT")` 优先），但未在所有入口设置，导致部分引用仍 fallback 到 `~/.config/omd`。

## 用户数据清单

以下是当前在 OMD 仓库中但**属于个人配置、不应公开**的文件：

| 文件 | 描述 | git 状态 |
|------|------|----------|
| `current/theme.name` | 当前选中的主题（如 "hackerman"） | 已跟踪 |
| `current/wallpaper` | 当前壁纸（大文件） | **gitignored** |
| `current/wallpaper.revision` | 壁纸版本号 | **gitignored** |
| `current/background` | 壁纸 symlink | 已跟踪 |
| `current/theme/*` | 当前主题文件（每次切换覆盖） | 已跟踪（默认 last-horizon） |
| `file-share-backup/config.json` | Windows VM 文件共享备份 | **gitignore 已排除** |
| `keyboard-remap/profiles.json` | Keyd 键盘映射配置 | 已跟踪 |
| `keyboard-remap/keyd.generated.conf` | 生成的 keyd 配置 | 已跟踪 |
| `launchers/*.desktop` | 个人应用启动器（wechat, wps, keepassxc 等） | 已跟踪 |
| `notifications/muted_apps.cfg` | 静音通知的应用列表 | 已跟踪 |
| `omarchy/.deployed` | 旧版部署标记 | **gitignored** |

**影响**: 这些文件如果保留在 OMD 仓库中，会与上游冲突，且新用户 clone 后拿到的是你的个人配置。

## 目标架构

```
~/.config/omd/              ← 真实目录，chezmoi 管理
    ├── current/                当前主题快照
    │   ├── theme/              omarchy-theme-set 写入（主题模板文件）
    │   ├── theme.name          当前主题名称
    │   ├── background          壁纸 symlink
    │   ├── wallpaper           壁纸文件（gitignored 大文件）
    │   └── wallpaper.revision
    ├── file-share-backup/
    │   └── config.json
    ├── keyboard-remap/
    │   ├── profiles.json
    │   └── keyd.generated.conf
    ├── launchers/
    │   ├── wechat.desktop
    │   ├── wps.desktop
    │   ├── keepassxc.desktop
    │   └── remote-desktop.desktop
    ├── notifications/
    │   └── muted_apps.cfg
    └── ...其他运行时生成的数据

~/development/OMD/           ← git 仓库，代码路径
    ├── hypr/                   通过 $OMD_ROOT/hypr/ 加载
    ├── bin/                    通过 $OMD_ROOT/bin/omd-* 调用
    ├── quickshell/             通过 $OMD_ROOT/quickshell/ 加载
    ├── current/                删掉（移走）
    ├── keyboard-remap/         删掉（移走）
    ├── launchers/              删掉（移走）
    └── notifications/          删掉（移走）
```

**关键**: 不再是 `~/.config/omd` 指向 repo，而是 `$OMD_ROOT` 环境变量指向 repo。

## 改动方案

### Phase 0: 备份

将当前 `~/.config/omd` 下的用户数据拷贝到 `~/chezmoi/dot_omd/backup-YYYYMMDD/`（通过 `~/.config/omd` symlink 读出原始内容）。

### Phase 1: 删除 `~/.config/omd` symlink

- `Init.sh` 不再创建 `~/.config/omd` → repo 的 symlink
- `Init.sh` 中的 `$HOME/.config/omd|$REPO` 行移除

### Phase 2: 确保 `$OMD_ROOT` 环境变量

需要保证 OMD 所有入口已设置 `OMD_ROOT`：

- `hypr/default/hypr/paths.lua` 已有 `os.getenv("OMD_ROOT")` 优先逻辑
- `bin/*` 脚本：大部分已有 `OMD_ROOT="${OMD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"` 自动推导
  - 但依赖 `dirname $0` 需要从 `~/.config/omd/bin/` 执行 → 改为 `~/development/OMD/bin/` 直接
- Quickshell QML：`Directories.config + "/omd"` → 用 `StandardPaths.home + "/development/OMD"` 或通过 env 传递
- `hypr/autostart.lua` 中设置 `export OMD_ROOT=$HOME/development/OMD`（或 `hyprctl` 中）

### Phase 3: 建立 `~/.config/omd` 真实目录

创建 `~/.config/omd/` 作为真实目录，包含：

- `current/`（`omarchy-theme-set` 写入此目录）
- 个人配置文件（chezmoi 管理）

`Init.sh` 中创建此目录（保证 `omarchy-theme-set` 首次运行有此目标）。

### Phase 4: 删除 OMD 仓库中的用户数据

从 git 删除：
- `current/`（保留默认主题模板在 `share/themes/` 中）
- `keyboard-remap/`
- `launchers/`
- `notifications/`
- `file-share-backup/`

### Phase 5: chezmoi 接管用户数据

`chezmoi add` 管理：
- `~/.config/omd/file-share-backup/config.json`
- `~/.config/omd/keyboard-remap/profiles.json`
- `~/.config/omd/launchers/*.desktop`
- `~/.config/omd/notifications/muted_apps.cfg`

注意：`current/` 和 `keyboard-remap/keyd.generated.conf` 是运行时生成的文件，不应由 chezmoi 管理（否则每次主题切换都 diff）。

## 风险与注意事项

1. **`~/.config/quickshell` 保持 symlink** 不变——它是 Quickshell 项目代码路径，不是用户数据
2. **`current/theme/` 的默认模板**：需要有一份默认主题（如 last-horizon）作为新用户的 fallback，存在 `share/themes/default/` 中。切换主题时由 `omarchy-theme-set` 复制到 `~/.config/omd/current/theme/`
3. **`icons/OS/`**：是 `ActiveWindow.qml` 需要用到的图标集，**不是用户数据**，保持在 OMD 仓库中，通过 `$OMD_ROOT/icons/OS/` 引用
4. **Hyprland 引用**：`hypr/autostart.lua` 中 `$HOME/.config/omd/bin/omd-restart` 这类硬编码需要改为 `$OMD_ROOT/bin/omd-restart`
5. **Quickshell QML 引用**：需要确认 Quickshell 也能访问 `$OMD_ROOT`
6. **`omarchy-theme-set` 写入路径**：需要确认它已经写入 `~/.config/omd/current/` 而非 `$OMD_ROOT/current/`（写入 repo 是错误的）
7. **备份旧 symlink 的 `current/` 内容**：当前 `~/.config/omd` 是 symlink，所以 `~/.config/omd/current/` 实际上是 `~/development/OMD/current/`。搬走前需要复制出来
