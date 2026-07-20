# Sumika Shell 模块管理系统设计

> 日期：2026-07-20
> 状态：设计中

## 1. 目标

在主仓库（OMD）中提供完整的模块生命周期管理：

- **安装**：从 git URL 安装新模块
- **更新**：拉取模块最新版本
- **启用/禁用**：通过 config.json 或 TUI 切换
- **卸载**：删除模块目录
- **列表**：查看已安装模块及状态
- **健康检查**：验证模块文件完整性和依赖满足
- **信息**：查看模块详情（版本、能力、依赖）

## 2. 命令行工具：`omd-modules`

### 2.1 命令结构

```bash
omd-modules <command> [args]

命令：
  list              列出所有已安装模块及状态
  info <id>         显示模块详情
  install <url>     从 git URL 安装模块
  update [id]       更新模块（默认全部）
  enable <id>       启用模块
  disable <id>      禁用模块
  remove <id>       卸载模块
  doctor            健康检查所有模块
  path              显示模块目录路径
```

### 2.2 各命令详细设计

#### `omd-modules list`

```
┌──────────────────────┬─────────┬────────┬─────────────────┐
│ Module               │ Status  │ Files  │ Capabilities    │
├──────────────────────┼─────────┼────────┼─────────────────┤
│ popup-components     │ enabled │ 12     │ shared          │
│ voice                │ enabled │ 4      │ popup, settings │
│ input-method         │ enabled │ 4      │ popup           │
│ battery-power        │ enabled │ 3      │ popup           │
│ display              │ enabled │ 4      │ popup           │
│ keyboard-remap       │ enabled │ 3      │ popup           │
│ ocr                  │ enabled │ 4      │ popup, settings │
│ file-backup          │ enabled │ 4      │ popup, settings │
│ session              │ enabled │ 3      │ popup           │
│ windows-vm           │ enabled │ 4      │ popup, settings │
│ clipboard            │ enabled │ 2      │ —               │
│ screenshot           │ enabled │ 2      │ —               │
│ mpris                │ enabled │ 2      │ —               │
│ systray              │ enabled │ 2      │ —               │
│ brightness-gamma     │ enabled │ 2      │ —               │
└──────────────────────┴─────────┴────────┴─────────────────┘
```

Status 取值：`enabled` / `disabled`（来自 config.json modules.disabled）

#### `omd-modules info <id>`

```bash
$ omd-modules info voice

Module: voice
  ID:          voice
  Name:        Voice Input
  Description: Voice input and speech-to-text
  Directory:   ~/development/sumika-modules/voice
  Status:      enabled
  Files:       module.json, qmldir, popup/VoicePopup.qml, settings/VoicePage.qml
  Capabilities:
    popupSections:  type="voice"
    settingsPages:  id="voice", title="Voice Input"
  Config:
    (no configDefaults defined)
  Dependencies:
    binaries: ffmpeg, jq
    python: sherpa_onnx, numpy
  Health: ✅ all checks passed
```

#### `omd-modules install <url>`

```bash
$ omd-modules install https://github.com/someuser/sumika-module-weather.git

Cloning into ~/development/sumika-modules/weather...
Installing dependencies...
  ✅ Module 'weather' installed
  Capabilities: barButtons(1), popupSections(1), settingsPages(1)
  Run 'omd-restart' to activate.
```

安装流程：
1. 解析 URL 获取模块 ID（目录名）
2. git clone 到 `SUMIKA_MODULES_HOME/<id>/`
3. 验证 `module.json` 格式
4. 如果有 `scripts/install.sh`，执行安装依赖
5. 如果模块声明了 `binScripts`，提示 PATH 注入
6. 输出能力摘要

#### `omd-modules update [id]`

```bash
$ omd-modules update voice

Updating voice...
  Already up to date.

$ omd-modules update

Updating all modules...
  popup-components:  up to date
  voice:              updated (3 files changed)
  input-method:       up to date
  ...
Done. Run 'omd-restart' to apply changes.
```

更新流程：
1. 在每个模块目录执行 `git pull`
2. 如果模块有 `.installed` 哨兵文件，检查是否需要重新运行 install.sh
3. 输出变更摘要

#### `omd-modules enable/disable <id>`

```bash
$ omd-modules disable mpris

Module 'mpris' disabled.
  Bar buttons, popup sections, and settings pages will not load.
  Run 'omd-restart' to apply.
```

启用/禁用流程：
1. 读取 `~/.config/sumika-shell/quickshell/config.json`
2. 修改 `modules.disabled` 数组（添加/移除 ID）
3. 提示用户重启

#### `omd-modules remove <id>`

```bash
$ omd-modules remove mpris

Remove module 'mpris'?
  Directory: ~/development/sumika-modules/mpris
  This will delete the module and all its files.
Type 'yes' to confirm: yes
  ✅ Module 'mpris' removed.
  Run 'omd-restart' to apply.
```

#### `omd-modules doctor`

```bash
$ omd-modules doctor

Checking 15 modules...

  popup-components    ✅ OK
  voice              ✅ OK
  input-method       ✅ OK
  battery-power      ⚠️  popup references ShellCard (OK via popup-components)
  display            ✅ OK
  keyboard-remap     ✅ OK
  ocr                ✅ OK
  file-backup        ✅ OK
  session            ✅ OK
  windows-vm         ✅ OK
  clipboard          ⚠️  no capabilities (module has no effect)
  screenshot         ⚠️  no capabilities
  mpris              ⚠️  no capabilities
  systray            ⚠️  no capabilities
  brightness-gamma   ⚠️  no capabilities

Summary: 10 OK, 5 warnings, 0 errors
```

检查项：
- `module.json` 格式有效
- `qmldir` 存在且声明正确
- 声明的 component 文件存在
- 声明的能力格式正确
- 依赖的二进制命令存在
- 模块未在 `disabled` 列表中

### 2.3 实现方式

`bin/omd-modules`：Bash 脚本（与项目其他 bin 脚本风格一致），调用 jq/python 做 JSON 操作。

## 3. TUI 界面：`omd-modules-tui`

### 3.1 设计

基于项目已有的 `omd_tui_shared.py`（Python curses TUI 框架），提供交互式模块管理界面。

```
┌─ Sumika Shell Modules ────────────────────────────────┐
│                                                       │
│  ┌─ Module ────────────┬─ Status ─┬─ Caps ─────────┐  │
│  │ ● popup-components  │ enabled  │ shared         │  │
│  │ ● voice             │ enabled  │ popup settings │  │
│  │ ● input-method      │ enabled  │ popup          │  │
│  │ ○ battery-power     │ enabled  │ popup          │  │
│  │ ○ display           │ enabled  │ popup          │  │
│  │ ○ keyboard-remap    │ enabled  │ popup          │  │
│  │ ○ ocr               │ enabled  │ popup settings │  │
│  │ ○ file-backup       │ enabled  │ popup settings │  │
│  │ ○ session           │ enabled  │ popup          │  │
│  │ ○ windows-vm        │ enabled  │ popup settings │  │
│  │ ○ clipboard         │ enabled  │ —              │  │
│  │ ○ screenshot        │ enabled  │ —              │  │
│  │ ○ mpris             │ enabled  │ —              │  │
│  │ ○ systray           │ enabled  │ —              │  │
│  │ ○ brightness-gamma  │ enabled  │ —              │  │
│  └─────────────────────┴──────────┴────────────────┘  │
│                                                       │
│  [e] Enable  [d] Disable  [i] Info  [u] Update  [?] Help│
└───────────────────────────────────────────────────────┘
```

- `j/k` 或 `↑/↓`：选择模块
- `e`：启用选中模块
- `d`：禁用选中模块
- `i`：查看模块详情
- `u`：更新选中模块
- `r`：刷新列表
- `q`：退出

### 3.2 实现

`bin/omd-modules-tui`：Python curses 脚本，使用 `omd_tui_shared.py` 的 UI 组件。

## 4. QML 设置页：ModulesPage

在 SettingsDialog 中添加一个 "Modules" 设置页，用 QML 实现图形界面。

### 4.1 导航

在 SettingsDialog primaryPages 中添加：
```qml
{ key: "modules", icon: "extension", title: "Modules", keywords: "module plugin addon extension" }
```

### 4.2 页面内容

```qml
// modules/settings/ModulesPage.qml
PageBody {
    // 模块列表
    Repeater {
        model: ModuleLoader.activeModuleIds
        delegate: SettingsRow {
            title: modelData
            // 开关
            SettingsToggleRow {
                checked: ModuleLoader.isEnabled(modelData)
                onCheckedChanged: {
                    // 修改 config.json modules.disabled
                }
            }
        }
    }
}
```

## 5. Init.sh 集成

### 5.1 模块目录初始化

```bash
# Init.sh 新增
setup_modules() {
    info "Setting up modules..."

    local modules_home="${SUMIKA_MODULES_HOME:-$HOME/development/sumika-modules}"

    # 如果模块目录不存在，创建并初始化为 git 仓库
    if [ ! -d "$modules_home" ]; then
        mkdir -p "$modules_home"
        cd "$modules_home"
        git init
        info "  Created module directory: $modules_home"
    fi

    # 如果模块仓库是空的，提示用户安装模块
    local module_count=$(find "$modules_home" -maxdepth 2 -name "module.json" | wc -l)
    if [ "$module_count" -eq 0 ]; then
        info "  No modules installed. Use 'omd-modules install <url>' to add modules."
    else
        ok "  Found $module_count modules"
    fi

    # 运行模块健康检查
    if command -v omd-modules >/dev/null 2>&1; then
        omd-modules doctor --quiet
    fi
}
```

### 5.2 omd-doctor 集成

在 `omd-doctor` 中添加模块检查：
```bash
check_modules() {
    echo "── Modules ──"
    local modules_home="${SUMIKA_MODULES_HOME:-$HOME/development/sumika-modules}"
    if [ ! -d "$modules_home" ]; then
        warn "Module directory not found: $modules_home"
        return
    fi
    # 检查注册表是否生成
    if [ ! -f /tmp/sumika-module-registry.json ]; then
        warn "Module registry not generated. Run omd-restart."
    fi
    # 检查模块数量
    local count=$(find "$modules_home" -maxdepth 2 -name "module.json" | wc -l)
    ok "$count modules installed"
    # 检查禁用列表
    local disabled=$(jq -r '.modules.disabled // [] | length' "$user_config" 2>/dev/null || echo 0)
    [ "$disabled" -gt 0 ] && info "  $disabled modules disabled"
}
```

## 6. 模块注册表增强

### 6.1 当前注册表格式

```json
{
  "modules": [{"id": "voice", "path": "/home/.../sumika-modules/voice"}],
  "barButtons": [],
  "popupSections": [{"type": "voice", "component": "file:///...", "moduleId": "voice"}],
  "settingsPages": [{"id": "voice", "component": "file:///...", "moduleId": "voice"}]
}
```

### 6.2 增强字段

```json
{
  "modules": [{
    "id": "voice",
    "name": "Voice Input",
    "description": "Voice input and speech-to-text",
    "path": "/home/.../sumika-modules/voice",
    "version": "1.0.0",
    "capabilities": ["popup", "settings"],
    "enabled": true,
    "health": "ok"
  }],
  "barButtons": [...],
  "popupSections": [...],
  "settingsPages": [...]
}
```

启动脚本在扫描时读取 module.json 的 `name`、`description`、`version` 并写入注册表。

## 7. 模块安装脚本标准：`scripts/install.sh`

```bash
#!/bin/bash
# sumika-module-voice/scripts/install.sh
set -eu

echo "Installing voice module dependencies..."

# Python 依赖
if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user sherpa_onnx numpy
fi

# 系统依赖
if command -v pacman >/dev/null 2>&1; then
    pacman -Q ffmpeg >/dev/null || sudo pacman -S --noconfirm ffmpeg
fi

# 写入哨兵文件
echo "{\"installed_at\": \"$(date -Iseconds)\", \"version\": \"1.0.0\"}" > "$(dirname "$0")/../.installed"

echo "Voice module ready."
```

## 8. 模块版本管理

### 8.1 module.json 版本字段

```json
{
  "id": "voice",
  "version": "1.0.0",
  "minCoreVersion": "1.0.0",
  ...
}
```

### 8.2 核心版本声明

在 `defaults/config/quickshell/config.json` 或单独的 `core-version.json` 中声明核心版本：
```json
{
  "coreVersion": "1.0.0"
}
```

### 8.3 兼容性检查

`omd-modules doctor` 检查每个模块的 `minCoreVersion` 是否 ≤ 核心版本。不兼容则警告。

## 9. 文件清单

需要创建的新文件：

| 文件 | 仓库 | 用途 |
|---|---|---|
| `bin/omd-modules` | OMD | 命令行模块管理工具 |
| `bin/omd-modules-tui` | OMD | TUI 模块管理界面 |
| `quickshell/modules/settings/pages/ModulesPage.qml` | OMD | QML 设置页 |
| `defaults/config/core-version.json` | OMD | 核心版本声明 |
| `scripts/generate-registry.sh` | OMD | 独立注册表生成脚本（从启动脚本提取） |

需要修改的文件：

| 文件 | 修改内容 |
|---|---|
| `quickshell/scripts/quickshell` | 注册表增加 name/description/version/enabled 字段 |
| `quickshell/modules/settings/SettingsDialog.qml` | 添加 "modules" 页到 primaryPages |
| `quickshell/modules/settings/pages/qmldir` | 注册 ModulesPage |
| `Init.sh` | 添加 setup_modules() 函数 |
| `bin/omd-doctor` | 添加模块健康检查 |

## 10. 实施步骤

### Phase 1：命令行工具（`bin/omd-modules`）

1. 创建 `bin/omd-modules` 脚本
2. 实现 `list`、`info`、`enable`、`disable`、`path` 命令
3. 实现 `doctor` 健康检查
4. 测试

### Phase 2：安装/更新/卸载

1. 实现 `install <url>` 命令
2. 实现 `update [id]` 命令
3. 实现 `remove <id>` 命令
4. 测试

### Phase 3：TUI 界面

1. 创建 `bin/omd-modules-tui`
2. 实现模块列表 + 启用/禁用/信息
3. 测试

### Phase 4：QML 设置页

1. 创建 `ModulesPage.qml`
2. 添加到 SettingsDialog 导航
3. 测试

### Phase 5：集成

1. Init.sh 添加模块初始化
2. omd-doctor 添加模块检查
3. 注册表增强
4. 版本管理
5. 最终测试