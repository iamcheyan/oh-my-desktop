# Sumika Shell 模块拆分 — 执行交接文档

> **给执行智能体的说明**：本文档包含 88 项任务的完整清单和详细描述。按顺序执行，每完成一个 Phase 提交一次。所有模块放在 `/home/tetsuya/development/sumika-modules/<module-id>/`。每步必须编译验证，不能破坏任何现有功能。完成后由另一个智能体检查。

---

## 项目背景

**项目**：oh-my-desktop (Sumika Shell) — 基于 Omarchy + Quickshell 的公开桌面环境
**仓库**：`~/development/OMD`
**模块输出目录**：`~/development/sumika-modules/`

### 当前架构

```
quickshell/
├── modules/
│   ├── bar/
│   │   ├── BarContent.qml          # bar 按钮布局（硬编码 9 个按钮，118-166 行）
│   │   ├── BarStatusPopup.qml       # 2800 行弹窗（13 个 content section）
│   │   ├── *Button.qml             # 各按钮组件
│   │   └── ...
│   ├── settings/pages/             # 11 个设置页（有 qmldir）
│   ├── common/                     # 核心 API + 共享组件
│   ├── overview/                   # 工作区概览（核心，不拆）
│   ├── lock/                       # 锁屏（核心，不拆）
│   ├── notificationPopup/          # 通知弹窗（核心，不拆）
│   ├── onScreenDisplay/            # OSD（核心框架，不拆）
│   ├── polkit/                     # PolKit（核心，不拆）
│   ├── schedulePopup/              # 通知中心（核心，不拆）
│   └── regionSelector/             # 截图区域选择（拆到 screenshot 模块）
├── services/                       # 30+ 个 QML 单例服务
├── scripts/quickshell              # 启动脚本
├── ModuleLoader.qml                # 模块加载器（已创建，需完善）
└── qmldir                          # qs 模块声明（已创建）
```

### BarContent.qml 右侧按钮（118-166 行）

```qml
RowLayout {
    id: rightSectionRowLayout
    SysTray { ... }              // → systray 模块
    InputMethodButton { ... }    // → input-method 模块
    AudioButton { ... }          // 核心（保留）
    WifiButton { ... }          // 核心（保留）
    ClipboardButton { ... }      // → clipboard 模块
    SessionButton { ... }       // → session 模块
    DisplayButton { ... }        // → display 模块
    ToolsButton { ... }         // → 拆分后移除，各模块注册自己的按钮
    ClockWidget { ... }          // 核心（保留）
    SidebarIndicators { ... }    // 核心（保留）
}
```

### BarStatusPopup.qml content sections

| 行号 | ID | 模块归属 |
|---|---|---|
| 440 | emptyContent | 核心 |
| 445-503 | toolsContent | 拆分后移除（OCR/备份/键盘各自注册） |
| 504-635 | inputMethodContent | → input-method 模块 |
| 636-677 | keyboardContent | → keyboard-remap 模块 |
| 678-748 | sessionContent | → session 模块 |
| 749-808 | xkbContent | 核心（xkb 布局指示） |
| 809-1319 | wifiContent | 核心 |
| 1320-1361 | bluetoothContent | 核心 |
| 1362-1921 | audioContent | 核心 |
| 1922-2016 | displayContent | → display 模块 |
| 2017-2427 | batteryContent | → battery-power 模块 |
| 2428-2528 | notificationsContent | 核心 |
| 2529-end | voiceContent | → voice 模块 |

### 验证方法

```bash
# 编译测试（每个 Phase 后必须跑）
cd ~/development/OMD
timeout 8 qs -p apps/omd-bar 2>&1 | grep -E "ERROR|Loaded"
timeout 8 qs -p apps/omd-overview 2>&1 | grep -E "ERROR|Loaded"
timeout 8 qs -p apps/omd-applauncher 2>&1 | grep -E "ERROR|Loaded"
timeout 8 qs -p apps/omd-clipboard 2>&1 | grep -E "ERROR|Loaded"
# 全部应显示 "Configuration Loaded"

# Lua 语法
lua -e "loadfile('hypr/hyprland.lua')"

# JSON 验证
python3 -c "import json; json.load(open('defaults/config/quickshell/config.json'))"
```

### 重要约定

1. **不要创建测试文件**：项目无测试框架，验证靠编译
2. **每步先读再改**：`edit` 工具的 TAG 会过期，每次编辑后用返回的新 TAG
3. **不破坏功能**：每改一个文件后立即编译验证
4. **模块目录**：`/home/tetsuya/development/sumika-modules/<module-id>/`
5. **仓库内引用**：模块 QML 通过 `QML_IMPORT_PATH` 解析，bin 脚本通过 `PATH` 解析
6. **不要动核心文件**：`AGENTS.md`、`Init.sh`（除非需要加模块初始化）
7. **每个 Phase 单独提交**

---

## Phase 0：基础设施（6 项）

### 任务 1：完善 ModuleLoader.qml

ModuleLoader.qml 已创建在 `quickshell/ModuleLoader.qml`，qmldir 已创建。需要：
- 确认 `import qs` 能找到 `ModuleLoader`
- 测试 `ModuleLoader.barButtons` 返回空数组（无模块时）
- 如果编译报错，修复 import 路径

**验证**：`timeout 8 qs -p apps/omd-bar 2>&1 | grep -E "ERROR|Loaded"` → Configuration Loaded

### 任务 2：改造启动脚本

修改 `quickshell/scripts/quickshell`：
- 在 `exec qs` 之前，扫描 `~/development/sumika-modules/*/module.json`
- 为每个找到的模块，将其目录加入 `QML_IMPORT_PATH`，将其 `bin/` 加入 `PATH`
- 生成模块注册表 JSON 写到 `/tmp/sumika-module-registry.json`，格式：
```json
{
  "modules": [{ "id": "voice", "path": "/home/.../sumika-modules/voice" }],
  "barButtons": [{ "moduleId": "voice", "component": "file:///path/to/VoiceButton.qml", "slot": "right", "order": 45 }],
  "popupSections": [{ "moduleId": "voice", "type": "voice", "component": "file:///path/to/VoicePopup.qml" }],
  "settingsPages": [{ "moduleId": "voice", "id": "voice", "title": "语音输入", "component": "file:///path/to/VoicePage.qml", "icon": "microphone", "order": 60 }]
}
```
- 设置环境变量 `SUMIKA_MODULE_REGISTRY=/tmp/sumika-module-registry.json`
- 读取用户 config.json 的 `modules.disabled` 黑名单，跳过禁用模块

**验证**：启动脚本运行后 `echo $QML_IMPORT_PATH` 包含模块路径，`cat /tmp/sumika-module-registry.json` 是有效 JSON

### 任务 3：改造 BarContent.qml

修改 `quickshell/modules/bar/BarContent.qml`（118-166 行）：
- 保留核心按钮：AudioButton、WifiButton、ClockWidget、SidebarIndicators
- 将模块按钮（InputMethodButton、ClipboardButton、SessionButton、DisplayButton、ToolsButton、SysTray）改为动态加载
- 在核心按钮后加 Repeater 加载 ModuleLoader.barButtons：
```qml
Repeater {
    model: ModuleLoader.barButtons
    delegate: Loader {
        required property var modelData
        source: modelData.component
        active: true
        Layout.alignment: Qt.AlignVCenter
        onStatusChanged: if (status === Loader.Error) {
            console.warn("[Module] Failed to load bar button:", modelData.component)
            active = false
        }
    }
}
```
- 在 shell.qml 加 `import qs`（如果还没有）以使用 ModuleLoader

**验证**：编译通过，bar 正常显示（无模块时 Repeater 为空，不影响）

### 任务 4：改造 BarStatusPopup.qml

这是最难的一步。`BarStatusPopup.qml` 有 2800 行，13 个 content section。

策略：**渐进式提取**——每次只提取一个 section 到模块：
1. 将目标 section（如 `toolsContent`）的 QML 代码提取为独立文件
2. 在原位置替换为 `Loader { active: barPopupType === "tools"; source: "..." }`
3. 编译验证
4. 重复下一个 section

Phase 0 只需要建立**框架**：
- 在 BarStatusPopup.qml 的 contentLoader 区域加一个 Repeater 加载 ModuleLoader.popupSections
- 保留所有现有 content section 不动（模块提取在后续 Phase 做）

```qml
// 在现有 content sections 之后加：
Repeater {
    model: ModuleLoader.popupSections
    delegate: Loader {
        required property var modelData
        active: barPopupType === modelData.type
        source: modelData.component
        onStatusChanged: if (status === Loader.Error) active = false
    }
}
```

**验证**：编译通过，弹窗功能不变（无模块时 Repeater 为空）

### 任务 5：改造 SettingsDialog

修改 `quickshell/modules/settings/SettingsDialog.qml` 或 `OverviewPage.qml`：
- 保留核心设置页导航（外观、网络、声音、系统）
- 在导航列表末尾加 Repeater 加载 ModuleLoader.settingsPages

```qml
Repeater {
    model: ModuleLoader.settingsPages
    delegate: SettingsNavItem {
        required property var modelData
        title: modelData.title
        icon: modelData.icon
        page: Loader {
            source: modelData.component
            active: false
        }
    }
}
```

**验证**：编译通过，设置页正常显示

### 任务 6：改造 Config.qml

修改 `quickshell/modules/common/Config.qml`：
- 新增 `modules` JsonObject（disabled 列表 + barButtonOrder）
- 新增 `property var moduleOptions: ({})` 用于动态模块配置
- 新增函数 `function moduleConfig(moduleId) { return moduleOptions[moduleId] ?? {} }`

在 `defaults/config/quickshell/config.json` 加：
```json
{
  "modules": {
    "disabled": [],
    "barButtonOrder": {}
  }
}
```

**验证**：编译通过，JSON 有效

### Phase 0 提交

```
module-system: Phase 0 infrastructure — ModuleLoader, dynamic loading framework

- ModuleLoader.qml singleton for discovering and loading external modules
- Startup script scans ~/development/sumika-modules/ and generates registry
- BarContent.qml supports dynamic module bar buttons via Repeater
- BarStatusPopup.qml supports dynamic module popup sections via Repeater
- SettingsDialog supports dynamic module settings pages via Repeater
- Config.qml adds modules section and moduleConfig() function
```

---

## Phase 1：文件备份模块（6 项）

**模块 ID**：`file-backup`
**当前文件**：
- `bin/omd-backup` — SMB 备份脚本
- `bin/omd-settings-backup-tui` — 备份 TUI
- `bin/omd-launch-settings-backup-tui` — TUI 启动器
- `share/polkit-1/rules.d/50-omd-backup.rules` — polkit 规则
- `BarStatusPopup.qml:493-497` — Tools 弹窗里的备份入口
- `OverviewPage.qml:46-50` — 设置概览里的备份入口

### 任务 7：创建模块目录

```bash
mkdir -p /home/tetsuya/development/sumika-modules/file-backup/{bin,popup,settings,scripts}
```

### 任务 8：移动 bin 脚本

将以下文件从 `~/development/OMD/bin/` 复制到 `~/development/sumika-modules/file-backup/bin/`：
- `omd-backup`
- `omd-settings-backup-tui`
- `omd-launch-settings-backup-tui`

从仓库删除原文件（`git rm`）。
polkit 规则 `share/polkit-1/rules.d/50-omd-backup.rules` 也移到模块 `scripts/` 下。

### 任务 9：提取 BarStatusPopup 备份入口

`BarStatusPopup.qml:493-497` 当前有一个 ToolsContentRow 条目：
```qml
ToolsContentRow {
    title: "File Share / Backup"
    subtitle: "SMB backup, sync and file sharing"
    onClicked: Quickshell.execDetached([`...omd-launch-settings-backup-tui`]);
}
```

提取为模块的 popup 组件：在 `sumika-modules/file-backup/popup/BackupEntry.qml` 创建一个 `ToolsContentRow`（或等价组件），在 `module.json` 注册为 popupSection。

从 `BarStatusPopup.qml` 删除该条目。

### 任务 10：提取 OverviewPage 备份入口

`OverviewPage.qml:46-50` 当前有一个设置入口条目。提取为模块的 settings 组件。

### 任务 11：编写 module.json + qmldir

`sumika-modules/file-backup/module.json`:
```json
{
  "id": "file-backup",
  "name": "文件备份",
  "description": "SMB 文件共享备份",
  "capabilities": {
    "popupSections": [{ "type": "file-backup", "component": "popup/BackupEntry.qml" }],
    "settingsPages": [{ "id": "file-backup", "title": "备份", "component": "settings/BackupPage.qml", "icon": "backup", "order": 70 }],
    "binScripts": "bin/"
  },
  "configDefaults": {}
}
```

`sumika-modules/file-backup/qmldir`:
```
module qs.modules.file-backup
```

### 任务 12：测试

- `timeout 8 qs -p apps/omd-bar` → Configuration Loaded
- bar 正常显示
- Tools 弹窗不再有备份入口（已移到模块）
- 如果模块目录存在且 module.json 有效，备份入口应通过 Repeater 动态出现

### Phase 1 提交

```
module: extract file-backup to sumika-modules/file-backup/
```

---

## Phase 2：OCR 模块（6 项）

**模块 ID**：`ocr`
**当前文件**：
- `bin/omd-ocr` — PaddleOCR 脚本
- `bin/omd-settings-ocr` — OCR 设置脚本
- `bin/omd-settings-ocr-tui` — OCR TUI
- `bin/omd-launch-settings-ocr-tui` — TUI 启动器
- `quickshell/modules/common/utils/ScreenshotAction.qml:53,113` — 截图后 OCR 动作
- `quickshell/modules/regionSelector/RegionSelection.qml:836-850` — 区域选择器 OCR 按钮
- `quickshell/modules/regionSelector/RegionSelector.qml:33` — OCR 模式枚举
- `BarStatusPopup.qml:466-470` — Tools 弹窗 OCR 入口

### 任务 13-18

13. 创建 `sumika-modules/ocr/` 目录
14. 移动 `bin/omd-ocr`、`bin/omd-settings-ocr*`、`bin/omd-launch-settings-ocr-tui` 到模块 `bin/`
15. `ScreenshotAction.qml` 中的 `omd-ocr` 调用改为通过 PATH 查找（命令名不变，PATH 注入后自动解析）。如果 OCR 模块禁用，截图动作应优雅降级（检查命令是否存在）
16. `BarStatusPopup.qml` 删除 OCR 入口条目（466-470），由模块通过 popupSection 注册
17. 写 `module.json` + `qmldir`
18. 测试

**注意**：`RegionSelector.qml` 的 OCR 模式枚举保留在核心（截图模块），但实际执行靠 `omd-ocr` 命令在 PATH 中是否存在。

---

## Phase 3：Windows 虚拟机模块（5 项）

**模块 ID**：`windows-vm`
**当前文件**：
- `bin/omd-settings-windows-vm` — VM 管理 TUI
- `bin/omd-settings-vm-tui` — 可能也是
- `quickshell/modules/settings/pages/WindowsVmPage.qml` — 设置页
- `quickshell/modules/settings/pages/qmldir` — 注册了 WindowsVmPage

### 任务 19-23

19. 创建 `sumika-modules/windows-vm/` 目录
20. 移动 `bin/omd-settings-windows-vm`、`bin/omd-settings-vm-tui` 到模块 `bin/`
21. 将 `WindowsVmPage.qml` 从 `quickshell/modules/settings/pages/` 移到模块 `settings/`。从 `pages/qmldir` 删除注册条目。在 `module.json` 注册为 settingsPage
22. 写 `module.json` + `qmldir`
23. 测试

---

## Phase 4：键盘重映射模块（7 项）

**模块 ID**：`keyboard-remap`
**当前文件**：
- `quickshell/services/KeyboardRemap.qml` — 服务单例（~650 行）
- `quickshell/modules/settings/pages/KeyboardRemapPage.qml` — 设置页
- `quickshell/modules/settings/pages/KeyboardEditorOverlay.qml` — 编辑器覆盖层
- `quickshell/modules/bar/BarContent.qml` — 无独立按钮，通过 ToolsButton 间接触发
- `BarStatusPopup.qml:636-677` — keyboardContent 弹窗 section
- `bin/omd-settings-keyboard` — 键盘设置脚本
- `bin/omd-settings-keyboard-tui` — 键盘 TUI
- `bin/omd-launch-settings-keyboard-tui` — TUI 启动器
- `share/bin/omarchy-keyboard-{apply,render,list,setup}` — 底层脚本
- `keyboard-remap/profiles.json` — 用户配置（已在 `~/.config/sumika-shell/`）

### 任务 24-30

24. 创建 `sumika-modules/keyboard-remap/` 目录
25. 移动 bin 脚本 + `share/bin/omarchy-keyboard-*` 到模块 `bin/`。更新 `bin/omd-settings-keyboard` 和 `bin/omd-settings-keyboard-tui` 中对 `omarchy-keyboard-*` 的直接路径引用，改为通过 PATH
26. 将 `KeyboardRemap.qml` 从 `quickshell/services/` 移到模块 `services/`。改为非 singleton 的普通 QML 组件。在 shell.qml 删除 `import "services"` 中对它的引用
27. 提取 `BarStatusPopup.qml:636-677`（keyboardContent）到模块 `popup/KeyboardPopup.qml`。在 module.json 注册
28. 将 `KeyboardRemapPage.qml` 和 `KeyboardEditorOverlay.qml` 移到模块 `settings/`。从 `pages/qmldir` 删除
29. 写 `module.json` + `qmldir`
30. 测试

**关键**：KeyboardRemap.qml 从 singleton 变为普通组件后，所有引用 `KeyboardRemap.xxx` 的地方需要改为通过 ModuleLoader 获取，或通过 Loader 创建后用属性传递。搜索所有引用：`grep -rn "KeyboardRemap" quickshell/ --include="*.qml"`

---

## Phase 5：语音输入模块（7 项）

**模块 ID**：`voice`
**当前文件**：
- `quickshell/services/VoiceInput.qml` — 服务单例（~340 行）
- `quickshell/modules/bar/modules/InputMethodButton.qml` — 实际这个文件同时处理语音和输入法，需要拆分
- `quickshell/modules/settings/pages/VoicePage.qml` — 设置页（~700 行）
- `quickshell/modules/bar/BarStatusPopup.qml:2529-end` — voiceContent 弹窗 section
- `bin/omd-voice-*`（通过 legacy dispatcher）→ `share/bin/omarchy-voice-*`
- `bin/omd-settings-voice`、`bin/omd-settings-voice-tui`
- `bin/omd-edit-voice-bindings`
- `scripts/voice-bind-tui`、`scripts/key-test`、`scripts/key-test-launcher`
- `scripts/key_capture_clipboard.py`、`scripts/key_evdev_names.py`

### 任务 31-37

31. 创建 `sumika-modules/voice/` 目录
32. 移动 bin 脚本 + `share/bin/omarchy-voice-*` + `scripts/voice-bind-tui` + `scripts/key-test*` + `scripts/key_*.py` 到模块
33. 将 `VoiceInput.qml` 从 `quickshell/services/` 移到模块 `services/`。改为非 singleton
34. 提取 `BarStatusPopup.qml` 的 voiceContent 到模块 `popup/VoicePopup.qml`
35. 将 `VoicePage.qml` 移到模块 `settings/`
36. 写 `module.json` + `qmldir`，注册 barButton（InputMethodButton 中的语音部分需要拆分）
37. 测试

**注意**：`InputMethodButton.qml` 同时处理语音和输入法。需要拆分：语音部分 → voice 模块的 bar 组件，输入法部分 → input-method 模块的 bar 组件。或者保留 InputMethodButton 在核心，但语音相关逻辑通过 ModuleLoader 获取 VoiceInput 服务。

---

## Phase 6：输入法模块（5 项）

**模块 ID**：`input-method`
**当前文件**：
- `quickshell/services/InputMethod.qml` — 服务单例
- `quickshell/modules/bar/modules/InputMethodButton.qml` — bar 按钮（与语音共享）
- `BarStatusPopup.qml:504-635` — inputMethodContent 弹窗
- `bin/omd-input-method` — 输入法状态/切换脚本
- `defaults/config/input-method/schemas.json` — schema 模板
- `~/.config/sumika-shell/input-method/schemas.json` — 用户 schema

### 任务 38-42

38. 创建 `sumika-modules/input-method/` 目录
39. 移动 `bin/omd-input-method` + `defaults/config/input-method/` 到模块
40. 将 `InputMethod.qml` 移到模块 `services/`，提取 InputMethodButton 的输入法部分
41. 提取 `BarStatusPopup.qml:504-635` 到模块 `popup/InputMethodPopup.qml`
42. 写 `module.json` + `qmldir` + 测试

---

## Phase 7：剪贴板模块（5 项）

**模块 ID**：`clipboard`
**当前文件**：
- `apps/omd-clipboard/` — 独立 Quickshell 进程
- `quickshell/modules/bar/modules/ClipboardButton.qml` — bar 按钮
- `bin/omd-clipboard`、`bin/omd-clipboard-store`
- `bin/omd-kitty-smart-paste`

### 任务 43-47

43. 创建 `sumika-modules/clipboard/` 目录
44. 移动 bin 脚本到模块
45. 提取 `ClipboardButton.qml` 到模块 `bar/`
46. 写 `module.json` + `qmldir`
47. 测试

**注意**：`apps/omd-clipboard/` 是独立 Quickshell 进程，可以保留在仓库或移到模块。建议保留在仓库（因为是独立进程，不是 bar 的子组件），只移动 bar 按钮和 bin 脚本。

---

## Phase 8：显示器设置模块（5 项）

**模块 ID**：`display`
**当前文件**：
- `quickshell/modules/bar/modules/DisplayButton.qml` — bar 按钮
- `BarStatusPopup.qml:1922-2016` — displayContent 弹窗
- `quickshell/modules/settings/display/` — 显示器设置目录
- `bin/omd-display-config` — 显示器配置脚本
- `bin/omd-ddc-detect` — DDC 检测
- `share/bin/omarchy-hyprland-monitor-*` — 显示器管理脚本

### 任务 48-52

48. 创建 `sumika-modules/display/` 目录
49. 移动 bin 脚本 + `share/bin/omarchy-hyprland-monitor-*` + `share/bin/omarchy-hw-external-monitors` 到模块
50. 提取 DisplayButton + displayContent 弹窗
51. 移动 `quickshell/modules/settings/display/` 到模块
52. 写 `module.json` + `qmldir` + 测试

---

## Phase 9：电源/电池模块（5 项）

**模块 ID**：`battery-power`
**当前文件**：
- `quickshell/services/Battery.qml` — 电池服务
- `quickshell/services/PowerProfiles.qml` — 电源配置服务
- `quickshell/modules/bar/BarBatteryIcon.qml` — bar 电池图标
- `quickshell/modules/bar/PowerContextMenu.qml` — 电源菜单
- `BarStatusPopup.qml:2017-2427` — batteryContent 弹窗
- `quickshell/modules/settings/pages/PowerPage.qml` — 设置页

### 任务 53-57

53. 创建 `sumika-modules/battery-power/` 目录
54. 移动 Battery + PowerProfiles 服务到模块
55. 提取 BarBatteryIcon + batteryContent 弹窗
56. 移动 PowerPage 到模块 settings
57. 写 `module.json` + `qmldir` + 测试

---

## Phase 10：亮度/夜间模式模块（4 项）

**模块 ID**：`brightness-gamma`
**当前文件**：
- `quickshell/services/Brightness.qml` — 亮度服务
- `quickshell/services/Hyprsunset.qml` — 夜间模式服务
- `quickshell/modules/onScreenDisplay/indicators/BrightnessIndicator.qml` — OSD
- `quickshell/modules/onScreenDisplay/indicators/GammaIndicator.qml` — OSD
- `DisplayButton.qml` 中的亮度部分
- `bin/omd-brightness-*`（通过 legacy dispatcher）→ `share/bin/omarchy-brightness-*`
- `hypr/hyprsunset.conf`

### 任务 58-61

58. 创建 `sumika-modules/brightness-gamma/` 目录
59. 移动 Brightness + Hyprsunset 服务 + OSD 指示器
60. 移动 `share/bin/omarchy-brightness-*` + `hypr/hyprsunset.conf` 到模块
61. 写 `module.json` + `qmldir` + 测试

---

## Phase 11：MPRIS 媒体控制模块（4 项）

**模块 ID**：`mpris`
**当前文件**：
- `quickshell/services/MprisController.qml` — MPRIS 控制器
- `quickshell/services/TrackArt.qml` — 专辑封面
- `BarStatusPopup.qml:1376-1712` — mediaContent 弹窗（~340 行）

### 任务 62-65

62. 创建 `sumika-modules/mpris/` 目录
63. 移动 MprisController + TrackArt 服务
64. 提取 mediaContent 弹窗（1376-1712 行，最长的 section）
65. 写 `module.json` + `qmldir` + 测试

---

## Phase 12：系统托盘模块（4 项）

**模块 ID**：`systray`
**当前文件**：
- `quickshell/modules/bar/SysTray.qml`
- `quickshell/modules/bar/SysTrayItem.qml`
- `quickshell/modules/bar/SysTrayMenu.qml`
- `quickshell/modules/bar/SysTrayMenuEntry.qml`
- `quickshell/services/TrayService.qml`

### 任务 66-69

66. 创建 `sumika-modules/systray/` 目录
67. 移动 TrayService + SysTray* 组件
68. 写 `module.json` + `qmldir`
69. 测试

---

## Phase 13：会话快照模块（5 项）

**模块 ID**：`session`
**当前文件**：
- `quickshell/modules/common/functions/Session.qml` — 会话服务
- `quickshell/modules/bar/SessionRestoreOverlay.qml`
- `quickshell/modules/bar/SessionAutoRestore.qml`
- `quickshell/modules/bar/SessionConfirmOverlay.qml`
- `BarStatusPopup.qml:678-748` — sessionContent 弹窗
- `bin/omd-session` — 会话保存/恢复脚本
- `SessionButton.qml` — bar 按钮

### 任务 70-74

70. 创建 `sumika-modules/session/` 目录
71. 移动 Session 服务 + overlay 组件
72. 提取 sessionContent 弹窗
73. 移动 `bin/omd-session` + `SessionButton.qml` 到模块
74. 写 `module.json` + `qmldir` + 测试

---

## Phase 14：截图模块（5 项）

**模块 ID**：`screenshot`
**当前文件**：
- `quickshell/modules/regionSelector/` — 整个目录
- `quickshell/modules/common/utils/ScreenshotAction.qml`
- `bin/omd-screenshot` — 截图脚本
- `bin/omd-notification` — 截图通知（可能共享）

### 任务 75-79

75. 创建 `sumika-modules/screenshot/` 目录
76. 移动 `bin/omd-screenshot` 到模块
77. 移动 `quickshell/modules/regionSelector/` 整个目录到模块
78. 移动 `ScreenshotAction.qml` 到模块
79. 写 `module.json` + `qmldir` + 测试

**注意**：截图模块与 OCR 模块有耦合（ScreenshotAction 调 `omd-ocr`）。通过 PATH 查找解耦——OCR 模块禁用时 `omd-ocr` 不在 PATH，截图动作优雅降级。

---

## 最终验证（3 项）

### 任务 80：全量编译测试

```bash
cd ~/development/OMD
for app in omd-bar omd-overview omd-applauncher omd-clipboard; do
  echo -n "$app: "
  timeout 8 qs -p apps/$app 2>&1 | grep -oE "ERROR|Configuration Loaded" | head -1
done
```

全部应显示 Configuration Loaded。

### 任务 81：写汇总文档

在 `docs/module-split-summary.md` 写：
- 拆分了哪些模块
- 每个模块的文件清单
- 核心保留的文件
- 已知问题 / 未完成项
- 禁用模块的方法

### 任务 82：提交

```bash
cd ~/development/OMD
git add -A
git commit -m "module-system: complete 14 module extraction"
```

---

## 核心保留清单（不拆）

| 文件 | 保留原因 |
|---|---|
| `quickshell/modules/bar/Bar.qml` | bar 骨架 |
| `quickshell/modules/bar/BarContent.qml` | 改造后保留（核心按钮 + Repeater） |
| `quickshell/modules/bar/BarStatusPopup.qml` | 改造后保留（核心 sections + Repeater） |
| `quickshell/modules/bar/AudioButton.qml` | 音量是基础功能 |
| `quickshell/modules/bar/WifiButton.qml` | 网络是基础功能 |
| `quickshell/modules/bar/ClockWidget.qml` | 时钟是基础功能 |
| `quickshell/modules/bar/SidebarIndicators.qml` | 核心指示器 |
| `quickshell/modules/overview/*` | 工作区概览 |
| `quickshell/modules/common/*` | 核心 API |
| `quickshell/modules/lock/*` | 锁屏 |
| `quickshell/modules/notificationPopup/*` | 通知弹窗 |
| `quickshell/modules/onScreenDisplay/` 框架 | OSD 框架 |
| `quickshell/modules/polkit/*` | PolKit |
| `quickshell/modules/schedulePopup/*` | 通知中心 |
| `quickshell/modules/settings/` 框架 | 设置框架 |
| `quickshell/services/Audio.qml` | 音频核心 |
| `quickshell/services/HyprlandData.qml` | 窗口数据 |
| `quickshell/services/Network.qml` | 网络核心 |
| `quickshell/services/Notifications.qml` | 通知核心 |
| `quickshell/services/Wallpaper.qml` | 壁纸核心 |
| `quickshell/services/GlobalStates.qml` | 全局状态 |
| `quickshell/services/Config.qml` | 配置核心 |
| `quickshell/services/Appearance.qml` | 主题核心 |
| `quickshell/services/Directories.qml` | 路径核心 |

---

## 模块标准结构模板

每个模块目录：

```
sumika-modules/<module-id>/
├── module.json          # 模块清单
├── qmldir               # QML 模块声明 (module qs.modules.<module-id>)
├── services/            # QML 服务组件（非 singleton）
├── bar/                  # bar 按钮组件
├── popup/                # BarStatusPopup section 组件
├── settings/             # 设置页组件
├── osd/                  # OSD 指示器（可选）
├── bin/                  # 可执行脚本
├── scripts/              # 辅助脚本
│   └── install.sh       # 依赖安装（可选）
└── config.schema.json    # 配置 schema（可选）
```

### module.json 模板

```json
{
  "id": "<module-id>",
  "name": "<显示名>",
  "description": "<描述>",
  "capabilities": {
    "services": ["<ServiceName>"],
    "barButtons": [{ "component": "bar/<Button>.qml", "slot": "right", "order": 50 }],
    "popupSections": [{ "type": "<popup-type>", "component": "popup/<Popup>.qml" }],
    "settingsPages": [{ "id": "<module-id>", "title": "<标题>", "component": "settings/<Page>.qml", "icon": "<icon>", "order": 60 }],
    "binScripts": "bin/"
  },
  "configDefaults": {
    "<module-id>": { "enabled": true }
  }
}
```

### qmldir 模板

```
module qs.modules.<module-id>
```

---

## 进度跟踪

| Phase | 模块 | 任务数 | 状态 |
|---|---|---|---|
| Phase 0 | 基础设施 | 6 | ⬜ 待执行 |
| Phase 1 | file-backup | 6 | ⬜ |
| Phase 2 | ocr | 6 | ⬜ |
| Phase 3 | windows-vm | 5 | ⬜ |
| Phase 4 | keyboard-remap | 7 | ⬜ |
| Phase 5 | voice | 7 | ⬜ |
| Phase 6 | input-method | 5 | ⬜ |
| Phase 7 | clipboard | 5 | ⬜ |
| Phase 8 | display | 5 | ⬜ |
| Phase 9 | battery-power | 5 | ⬜ |
| Phase 10 | brightness-gamma | 4 | ⬜ |
| Phase 11 | mpris | 4 | ⬜ |
| Phase 12 | systray | 4 | ⬜ |
| Phase 13 | session | 5 | ⬜ |
| Phase 14 | screenshot | 5 | ⬜ |
| Final | 验证 | 3 | ⬜ |
| **合计** | | **88** | |