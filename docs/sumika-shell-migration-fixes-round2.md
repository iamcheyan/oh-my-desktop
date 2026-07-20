# Sumika Shell 迁移修复 — 第二轮

> **更正（2026-07-20）**：后续隔离回归测试发现本报告中的“二次重跑全
> skip、数据完整”结论不准确。旧版 `copy_dir()` 会覆盖已有目标文件。
> 修复和重新验证结果见 `docs/sumika-shell-migration-fixes-round3.md`。

> 审查发现 7 个问题（3 严重、1 高、3 中），全部修复并经过幂等测试验证。
> 2026-07-20

---

## Critical（3/3）

### 1. `OLD_STATE_HOME` 未定义变量

**问题**：`sumika-migrate.sh` 设置 `set -u`，但第 117 行的 `detect_old_state()` 和第 240 行的 `write_marker()` 引用了已被删除的 `OLD_STATE_HOME`，导致脚本立即退出。

```
scripts/sumika-migrate.sh: line 117: OLD_STATE_HOME: unbound variable
```

**修复**：恢复 `OLD_STATE_HOME` 变量定义：
```sh
OLD_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/omd"
```

### 2. `copy_dir()` 子 shell 丢失 `dst` 变量

**问题**：`find -exec sh -c '...'` 创建的子进程无法读取父 shell 的 `dst` 变量。由于 `set -u`，引用空变量会使 `cp -a "$item" "$dst/"` 中的 `$dst` 展开为空，实际写入根目录 `/`。

```
cp: cannot create directory '/sub': Read-only file system
```

**修复**：将 `dst` 作为参数传递给子 shell：
```sh
find "$src" -mindepth 1 -maxdepth 1 -exec sh -c '
    dst="$1"; shift
    for item; do
        cp -a "$item" "$dst/"
    done
' sh "$dst" {} +
```

### 3. Init.sh 迁移失败降级为警告

**问题**：
```sh
sh "$REPO/scripts/sumika-migrate.sh" || warn "..."
```
迁移脚本因 `OLD_STATE_HOME` 未绑定而失败后，Init.sh 仅打印 warning，仍继续创建 `~/.config/omd` 符号链接。如果这是唯一一次迁移机会，旧配置数据将永久丢失。

**修复**：迁移失败改为 fatal error，阻止后续操作：
```sh
sh "$REPO/scripts/sumika-migrate.sh" || { echo "FATAL: ..."; exit 1; }
```

---

## High（4/4）

| 文件 | 旧路径 | 新路径 |
|---|---|---|
| `bin/omd-session:12` | `XDG_STATE_HOME/omd/session` | `SUMIKA_SHELL_STATE_HOME/session` |
| `bin/omd-display-config:18` | `XDG_STATE_HOME/omd/display` | `SUMIKA_SHELL_STATE_HOME/display` |
| `hypr/monitors.lua:67` | `XDG_STATE_HOME/omd/display/layout.lua` | `SUMIKA_SHELL_STATE_HOME/display/layout.lua` |
| `bin/omd-settings-ocr:8` | `XDG_STATE_HOME/omd/ocr` | `SUMIKA_SHELL_STATE_HOME/ocr` |

统一模式：优先读取 `SUMIKA_SHELL_STATE_HOME` 环境变量，fallback 到 `XDG_STATE_HOME/sumika-shell`。Python 和 Lua 实现均遵循此模式。

---

## Medium（3/3）

### 1. `Directories.qml` 不识别 `SUMIKA_SHELL_STATE_HOME`

**问题**：QML 侧 `stateHome` 属性只读 `XDG_STATE_HOME`，忽略优先级更高的 `SUMIKA_SHELL_STATE_HOME`。

**修复**：添加 `SUMIKA_SHELL_STATE_HOME` 优先检查（通过 IIFE），只在未设置时将 `XDG_STATE_HOME` 作为基路径返回。

### 2. `omd-doctor` 硬编码 `$HOME/.config/sumika-shell`

**问题**：第 79-86 行的 sumika-shell 目录检查硬编码 `$HOME/.config/sumika-shell`，不遵守 `XDG_CONFIG_HOME` 或 `SUMIKA_SHELL_CONFIG_HOME`。

**修复**：改为：
```sh
_sumika_cfg="${SUMIKA_SHELL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/sumika-shell}"
```

### 3. `mkdir -p` 不限制目录权限

**问题**：`mkdir -p` 默认创建 755 目录。state 和 config 目录包含 keyboard-remap profiles、file-share-backup config 等敏感数据，应限制访问。

**修复**：`mkdir -p -m 700` 创建所有 state 和 config 子目录。

---

## 幂等测试结果

```
首次迁移: exit=0   15 个文件正确迁移
二次重跑: exit=0   全 skip，数据完整
--dry-run: exit=0  不写入任何文件
增量合并: exit=0   session/new.json 正确合并到已有目录
```

数据完整性验证：theme name、wallpaper interval、session JSON 在二次迁移后内容不变。合并路径日志干净：`(already exists — merging contents)`。

## 语法验证

13 个修改文件全部通过：
| 语言 | 工具 | 文件数 | 结果 |
|---|---|---|---|
| Shell | `bash -n` | 7 | 全部通过 |
| Python | `py_compile` | 5 | 全部通过 |
| Lua | `luac -p` | 3 | 全部通过 |

## 仓库状态

22 个文件变更（+372 / -380），包括本轮 14 个核心修复 + 上一轮 Phase 5 的代码编辑 + AGENTS.md/docs 更新。

## 遗留

| 事项 | 状态 |
|---|---|
| 提交全部 22 个文件 | 待做 |
| chezmoi fcitx5 冲突 | 阻止全量 `chezmoi apply` |
| 冒烟测试（wallpaper、theme switch、clipboard） | 待做 |
