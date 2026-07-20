> **更新日志**：
> - ✅ 问题 1（inline component 依赖）— 创建 `popup-components` 共享模块（10 个组件提取为独立文件）
> - ✅ 问题 2（bar qmldir 循环依赖）— 绕过（不为 bar/ 创建 qmldir）
> - ✅ 问题 3（服务重复）— 删除 10 个模块服务副本，统一用核心 `qs.services` singleton
> - ⬜ 问题 4（bin 脚本重复）— 不影响功能，后续清理
> - ✅ 问题 5（bin 脚本缺失）— 7 个脚本恢复到核心作为 fallback
> - ✅ 问题 6（module.json 格式）— 修复 barButtons 格式、移除重复 settingsPages、核对 type 值
> - ✅ 问题 7（qmldir 手动维护）— 创建 `scripts/generate-qmldir.sh` 自动生成脚本
> - ✅ BarStatusPopup 模块 Repeater — 动态加载模块弹窗 section
> - ✅ SettingsDialog 模块支持 — 动态加载模块设置页
> - ✅ ModuleLoader — 移到 services/，修复 Config import
> - ✅ 启动脚本 jq bug + file:// 前缀 — 修复
> - ✅ 3 个被误删的服务恢复（FirstRunExperience、ConflictKiller、Updates）
> - ✅ display/ 设置目录恢复
> - ✅ 模块 qmldir 修复（移除已删除服务的引用）
> - ⬜ 模块 QML 运行时测试 — 需用户手动测试
> - ⬜ BarContent 模块 Repeater — 待按钮从核心移到模块后添加
> - ⬜ 问题 4（bin 脚本重复）— 不影响功能，后续清理

# 模块拆分当前状态与问题报告（详细版）

> 日期：2026-07-20
> 背景：另一个智能体执行了 14 模块拆分，但导致功能大面积损坏。我（检查智能体）修复了编译和核心功能，但模块系统尚未真正可用。本文档记录所有现状、临时方案、残留问题、架构分析和后续计划。

---

## 一、当前可运行状态

### ✅ 正常工作的（核心已恢复）

所有核心 UI 和功能已从拆分前的 git 历史恢复（commit `65c3637`），4 个 Quickshell 进程编译通过：

| 组件 | 状态 | 说明 |
|---|---|---|
| 顶栏 10 个按钮 | ✅ 全部恢复 | SysTray、InputMethodButton、AudioButton、WifiButton、ClipboardButton、SessionButton、DisplayButton、ToolsButton、ClockWidget、SidebarIndicators |
| 弹窗 13 个 section | ✅ 全部恢复 | tools、inputMethod、keyboard、session、xkb、wifi、bluetooth、audio、display、battery、notifications、voice、empty |
| 设置页 11 个 | ✅ 全部恢复 | Overview、Appearance、Sound、Power、System、Network、Bluetooth、Voice、WindowsVm、KeyboardRemap、KeyboardEditor |
| bin 脚本 | ✅ 正常 | 通过 omd-legacy-omarchy 分发器或真实文件 |
| 4 个 QS 进程 | ✅ 编译通过 | omd-bar、omd-overview、omd-applauncher、omd-clipboard |

### ⚠️ 模块系统（基础设施存在但未真正接入）

| 基础设施文件 | 状态 | 问题 |
|---|---|---|
| `ModuleLoader.qml` | 存在，已修复 | 用 Process 异步读注册表；当前无代码调用它 |
| `quickshell/qmldir` | 存在 | 声明 qs 模块 + ModuleLoader singleton |
| `quickshell/scripts/quickshell` | 存在，已修复 | jq bug 已修；扫描模块生成注册表；注入 PATH 和 QML_IMPORT_PATH |
| `Config.qml` | 有 modules 字段 | `modules.disabled` + `modules.barButtonOrder`；当前无代码读取 |
| `defaults/config/quickshell/config.json` | 有 modules 节 | `{"disabled": [], "barButtonOrder": {}}` |
| BarContent.qml | **原始版本**（无 Repeater） | 从 git 恢复，丢失了模块 Repeater 代码 |
| BarStatusPopup.qml | **原始版本**（无 Repeater） | 从 git 恢复，2811 行，丢失了模块 Repeater 代码 |
| qmldir 文件 | 9 个已创建 | services/、common/、common/widgets/、common/functions/ 等 |

### ⚠️ 模块目录（`~/development/sumika-modules/`）

14 个模块目录全部存在，但**所有 QML 文件不可用**（inline component 依赖问题，详见问题 1）。bin 脚本和 services 是核心的副本。

---

## 二、临时修复方案（我做的，共 6 项）

### 修复 1：恢复 BarContent.qml 和 BarStatusPopup.qml

**问题**：另一个智能体从这两个文件删除了所有模块相关的 section 和按钮，导致：
- BarContent 只剩 4 个核心按钮（AudioButton、WifiButton、ClockWidget、SidebarIndicators）
- BarStatusPopup 只剩 6 个 section（empty、xkb、wifi、bluetooth、audio、notifications）
- 工具箱、输入法弹窗、键盘弹窗、会话弹窗、显示器弹窗、电池弹窗、语音弹窗全部消失

**临时方案**：从 commit `65c3637` 完整恢复两个文件。BarStatusPopup 恢复为 2811 行，BarContent 恢复为 10 个硬编码按钮。丢失了模块 Repeater 代码。

**后续**：重新加入模块 Repeater——但需要先解决 inline component 提取（问题 1）和循环依赖（问题 2）。Repeater 的设计应该是：

```qml
// BarContent.qml — 在核心按钮之后
Repeater {
    model: ModuleLoader.barButtons
    delegate: Loader {
        required property var modelData
        source: modelData.component  // file:// URL
        active: true
        Layout.alignment: Qt.AlignVCenter
        onStatusChanged: if (status === Loader.Error) {
            console.warn("[Module] Bar button load failed:", modelData.component)
            active = false
        }
    }
}
```

```qml
// BarStatusPopup.qml — 在 contentLoader 之后
Repeater {
    model: ModuleLoader.popupSections
    delegate: Loader {
        required property var modelData
        active: root.activeType === modelData.type
        source: modelData.component
        onStatusChanged: if (status === Loader.Error) active = false
    }
}
```

### 修复 2：恢复 bar/modules/ 下的 4 个按钮文件

| 文件 | 原因 |
|---|---|
| ClipboardButton.qml | 被移到 `sumika-modules/clipboard/bar/`，核心找不到 |
| DisplayButton.qml | 被移到 `sumika-modules/display/bar/`，核心找不到 |
| SessionButton.qml | 被移到 `sumika-modules/session/`（没有 bar/ 子目录），完全删除 |
| ScreenshotContextMenu.qml | 被移到 `sumika-modules/screenshot/`，DisplayButton 引用它 |

**后续**：这些文件在模块目录也有副本。最终应从核心删除——但前提是模块的 bar 按钮能通过 Repeater 正确加载。当前保留在核心是因为模块 QML 不可用。

### 修复 3：恢复 settings/pages/ 下的 5 个设置页

| 文件 | 模块副本 |
|---|---|
| VoicePage.qml | `sumika-modules/voice/settings/` |
| WindowsVmPage.qml | `sumika-modules/windows-vm/settings/` |
| KeyboardRemapPage.qml | `sumika-modules/keyboard-remap/settings/` |
| KeyboardEditorOverlay.qml | `sumika-modules/keyboard-remap/settings/` |
| PowerPage.qml | `sumika-modules/battery-power/settings/` |

同时恢复了 `pages/qmldir` 的完整注册（11 个页面）。

**后续**：同修复 2，最终移到模块。

### 修复 4：创建 qmldir 文件

为以下目录创建了 qmldir（含 singleton 声明）：

| qmldir 路径 | 模块名 | singleton 数量 |
|---|---|---|
| `services/qmldir` | `qs.services` | 27 个 singleton |
| `modules/common/qmldir` | `qs.modules.common` | 5 个 singleton |
| `modules/common/widgets/qmldir` | `qs.modules.common.widgets` | 1 个 singleton (NerdIconMap) |
| `modules/common/functions/qmldir` | `qs.modules.common.functions` | 9 个 singleton |

**为什么需要**：模块 QML 文件用 `import qs.services`、`import qs.modules.common` 等限定导入。没有 qmldir，QML 引擎无法解析这些导入。

**注意**：**不要**为 `bar/` 和 `bar/modules/` 创建 qmldir——会导致循环依赖（详见问题 2）。

**后续**：qmldir 需要手动维护。新增 QML 文件时必须更新对应 qmldir。可以考虑写一个脚本自动生成。

### 修复 5：启动脚本 jq bug

**问题**：`quickshell/scripts/quickshell` 第 78 行：
```bash
# 错误代码（$module_dir 是 shell 变量，jq 不认识）
registry=$(jq -c --slurpfile mod "$module_json" \
    '.modules += [{"id": $mod[0].id, "path": $module_dir}] | ...' \
    "$tmp_reg" 2>/dev/null || echo "$registry")
```

jq 表达式中的 `$module_dir` 是 shell 变量，但 jq 的变量需要通过 `--arg` 传入。所有 jq 调用都静默失败（`2>/dev/null`），注册表始终为空。

**修复**：
```bash
# 修复后
registry=$(jq -c --slurpfile mod "$module_json" --arg mdir "$module_dir" \
    '.modules += [{"id": $mod[0].id, "path": $mdir}] | ...' \
    "$tmp_reg" 2>&1 || echo "$registry")
```

同时在 component 路径前加 `file://` 前缀（QML Loader.source 需要 URL 格式）。

### 修复 6：ModuleLoader.qml API 修复

**问题**：用了 `Quickshell.readFile()` — 这个 API 不存在。

**修复**：改为 `Process` + `StdioCollector`（项目已有的模式）：
```qml
Process {
    command: ["cat", loader.registryPath]
    stdout: StdioCollector {
        onStreamFinished: {
            loader._registry = JSON.parse(this.text.trim())
        }
    }
    running: true
}
```

**局限**：Process 是异步的。ModuleLoader 的 `barButtons`、`popupSections` 等属性在进程完成前是空数组。如果 Repeater 在进程完成前就创建了，可能需要 `model` 变化时自动刷新——QML 的绑定机制应该能处理这个。

---

## 三、模块目录的问题（`~/development/sumika-modules/`）

### 问题 1：所有模块弹窗 QML 使用核心的 inline component 🔴

**严重度**：阻断性——模块弹窗完全无法加载

`BarStatusPopup.qml` 内定义了 10 个 inline component（`component ShellCard: Item { ... }`）。这些不是独立 QML 文件，无法被外部文件 import。9 个模块的 popup QML 文件全部依赖它们。

#### 10 个 inline component 及其依赖分析

| Component | 行号 | 类型 | 依赖的核心组件 | 依赖的服务 |
|---|---|---|---|---|
| PopupColumn | 210 | ColumnLayout | 无 | 无 |
| ToolLauncherRow | 215 | SettingsNavigationRow | SettingsNavigationRow（settings/widgets） | 无 |
| ShellCard | 227 | Item | StyledRectangularShadow, StyledText | Appearance, TuiStyle |
| Divider | 279 | Rectangle | 无 | TuiStyle |
| SectionLabel | 287 | StyledText | StyledText | Appearance, TuiStyle |
| ActionRow | 300 | RowLayout | 无 | 无 |
| PopupActionButton | 308 | SettingsButton | SettingsButton（settings/widgets） | 无 |
| IconActionRow | 315 | Item | 无 | 无 |
| PopupIconButton | 333 | Item | NerdIcon, StyledText | SettingsTokens, NerdIconMap |
| PopupHeader | (在文件中) | Item | NerdIcon, StyledText | Appearance, NerdIconMap |

#### 每个模块使用了哪些 inline component

| 模块 | 使用的 component |
|---|---|
| battery-power | ShellCard, PopupHeader, SectionLabel |
| file-backup | PopupColumn, PopupHeader, ToolLauncherRow |
| ocr | PopupColumn, PopupHeader, ToolLauncherRow |
| windows-vm | PopupColumn, PopupHeader, ToolLauncherRow, Divider |
| keyboard-remap | PopupColumn, PopupHeader |
| voice | PopupColumn, PopupHeader, ActionRow, PopupActionButton |
| input-method | PopupColumn, PopupHeader |
| display | PopupColumn, PopupHeader, ToolLauncherRow |
| session | PopupColumn, PopupHeader, IconActionRow, PopupIconButton |

#### 解决方案

将 10 个 inline component 提取为独立 QML 文件。放置位置需要满足：
1. 模块文件能 import 到（通过限定 import）
2. 不引起循环依赖
3. 核心的 BarStatusPopup.qml 也能使用

**推荐位置**：`quickshell/modules/bar/components/`，qmldir 声明 `module qs.modules.bar.components`。

**为什么不是 `qs.modules.bar`**：因为 `qs.modules.bar` 包含 BarContent.qml，而 BarContent 引用 DisplayButton（在 `bar/modules/` 中），DisplayButton 又引用 `qs.modules.bar` 中的 CircleUtilButton——形成循环。`qs.modules.bar.components` 是独立子模块，不参与循环。

**提取后的文件结构**：
```
quickshell/modules/bar/components/
├── qmldir                    # module qs.modules.bar.components
├── PopupColumn.qml
├── ToolLauncherRow.qml
├── ShellCard.qml
├── Divider.qml
├── SectionLabel.qml
├── ActionRow.qml
├── PopupActionButton.qml
├── IconActionRow.qml
├── PopupIconButton.qml
└── PopupHeader.qml
```

**每个文件的 import**：
```qml
// ShellCard.qml — 依赖 Appearance, TuiStyle, StyledRectangularShadow
import qs.modules.common        // Appearance, TuiStyle
import qs.modules.common.widgets // StyledRectangularShadow, StyledText
import QtQuick
import QtQuick.Layouts

Item {
    // ... 从 BarStatusPopup.qml 的 inline component 复制
}
```

**BarStatusPopup.qml 改造**：
```qml
// 原来：component ShellCard: Item { ... }
// 改为：import qs.modules.bar.components
// 然后直接使用 ShellCard { ... }
```

**模块文件改造**：
```qml
// sumika-modules/battery-power/popup/BatteryPopup.qml
import qs.modules.bar.components  // 新增
import qs.modules.common
import qs.modules.common.widgets
import qs.services
// ... 不再依赖 BarStatusPopup 的 inline component
```

### 问题 2：bar qmldir 循环依赖 🔴

**严重度**：阻断性——如果创建 bar qmldir，omd-bar 无法编译

#### 循环链路

```
qs.modules.bar (BarContent.qml)
    ↓ 引用 DisplayButton
qs.modules.bar.modules (DisplayButton.qml)
    ↓ 引用 CircleUtilButton, BarNerdIcon
qs.modules.bar (CircleUtilButton.qml, BarNerdIcon.qml)
    ← 循环回到 qs.modules.bar
```

QML 引擎在解析 `qs.modules.bar` 时发现它依赖 `qs.modules.bar.modules`，而后者又依赖前者——无法确定加载顺序。

#### 三个解决方案对比

| 方案 | 做法 | 优点 | 缺点 |
|---|---|---|---|
| A. 移动共享组件 | CircleUtilButton、BarNerdIcon 移到 `qs.modules.common.widgets` | 彻底解决循环；组件可被任何模块使用 | 需要修改所有引用这些组件的文件 |
| B. 模块不 import bar | 模块文件不 import `qs.modules.bar`，所需组件从 `components` 子模块获取 | 不动核心代码 | 模块无法使用 bar 目录的组件（只能用 components 和 common） |
| C. 不用 bar qmldir | bar/ 和 bar/modules/ 不创建 qmldir，继续用相对 import | 零改动；核心代码不受影响 | 模块文件无法 import `qs.modules.bar` 中的任何东西 |

**推荐**：**方案 A + C 结合**——不为 `bar/` 和 `bar/modules/` 创建 qmldir（方案 C），同时将共享组件移到 `common/widgets`（方案 A）。这样：
- 核心代码继续用相对 import（不受影响）
- 模块文件通过 `qs.modules.common.widgets` 获取共享组件
- 模块文件通过 `qs.modules.bar.components` 获取 popup 组件
- 无循环依赖

#### 需要移动到 common/widgets 的组件

| 组件 | 当前位置 | 被谁引用 |
|---|---|---|
| CircleUtilButton.qml | bar/ | DisplayButton, InputMethodButton, ClipboardButton, SessionButton, ToolsButton, SidebarIndicators |
| BarNerdIcon.qml | bar/ | DisplayButton, AudioButton, WifiButton, ClipboardButton, SysTray |
| BarTextButton.qml | bar/ | 可能被其他引用 |

这些组件本质上是"通用 bar 按钮基础设施"，不是 bar 特有的，放在 common/widgets 更合理。

### 问题 3：服务文件重复（核心 singleton + 模块非 singleton）🟡

10 个服务在核心和模块各一份。核心是 `pragma Singleton`，模块是非 singleton 的普通组件。

#### 为什么不能直接删除核心版本

QML 的 `pragma Singleton` 机制要求：
1. singleton 必须在 qmldir 中声明 `singleton XxxService 1.0 XxxService.qml`
2. singleton 在模块 import 时自动创建唯一实例
3. 所有引用 `XxxService.xxx` 的代码都访问同一个实例
4. **singleton 不能通过 Loader 动态加载**——它是编译时绑定的

如果删除核心的 singleton 版本，所有 `import qs.services` 的代码都会报错（找不到 singleton）。模块的非 singleton 版本无法替代——因为外部代码用 `Services.VoiceInput.xxx` 访问 singleton 属性，而非 singleton 组件需要先实例化（`VoiceInput { id: voice }`）才能使用。

#### 迁移策略

**阶段 1（当前）**：核心保留 singleton，模块的非 singleton 版本是死代码。不影响功能。

**阶段 2**：模块的 service 改为 `pragma Singleton` + qmldir 声明。在模块的 qmldir 中：
```
module qs.modules.voice
singleton VoiceInput 1.0 services/VoiceInput.qml
```
然后模块的 QML 文件 `import qs.modules.voice` 并使用 `VoiceInput.xxx`。但核心代码仍然 `import qs.services`——两个不同的 singleton 实例会冲突。

**阶段 3**：从核心删除 singleton，所有代码改为 `import qs.modules.voice`。但禁用模块时找不到 singleton——需要"核心 fallback singleton"（空实现）或条件 import（QML 不支持）。

**结论**：服务的完全模块化是**最难的部分**，可能需要重新设计服务架构。短期保持现状（核心 singleton + 模块死代码）。

### 问题 4：bin 脚本重复 🟡

15 个 bin 脚本在核心和模块各一份。启动脚本将模块的 `bin/` 加入 PATH 前面，所以模块版本会优先执行。但核心版本也在 PATH 中——如果模块目录被删除，核心版本仍然是 fallback。

#### 具体重复清单

| 脚本名 | 核心位置 | 模块 | 是否通过 legacy 分发 |
|---|---|---|---|
| omd-clipboard | bin/ | clipboard | 否（真实文件） |
| omd-clipboard-store | bin/ | clipboard | 否 |
| omd-kitty-smart-paste | bin/ | clipboard | 否 |
| omd-display-config | bin/ | display | 否 |
| omd-ddc-detect | bin/ | display | 否 |
| omd-screenshot | bin/ | screenshot | 否 |
| omd-input-method | bin/ | input-method | 否 |
| omd-settings-windows-vm | bin/ | windows-vm | 否 |
| omd-settings-vm-tui | bin/ | windows-vm | 否 |
| omd-settings-keyboard | bin/ | keyboard-remap | 否 |
| omd-settings-keyboard-tui | bin/ | keyboard-remap | 否 |
| omd-launch-settings-keyboard-tui | bin/ | keyboard-remap | 否 |
| omd-settings-voice | bin/ | voice | 否 |
| omd-settings-voice-tui | bin/ | voice | 否 |
| omd-edit-voice-bindings | bin/ | voice | 否 |

**后续**：当模块系统成熟后，从核心删除这些脚本。当前保留两份不影响功能（PATH 顺序决定优先级）。

### 问题 5：15 个 bin 脚本从核心删除但核心代码仍引用 🟡

另一类问题：以下脚本**只**在模块目录中存在（核心没有），但核心 QML 代码引用它们：

| 脚本 | 只在模块 | 核心引用者 | 风险 |
|---|---|---|---|
| omd-backup | file-backup | BarStatusPopup toolsContent | 启动脚本 PATH 注入后可用 |
| omd-settings-backup-tui | file-backup | BarStatusPopup toolsContent | 同上 |
| omd-launch-settings-backup-tui | file-backup | BarStatusPopup toolsContent | 同上 |
| omd-ocr | ocr | ScreenshotAction.qml | 同上 |
| omd-settings-ocr | ocr | BarStatusPopup toolsContent | 同上 |
| omd-settings-ocr-tui | ocr | BarStatusPopup toolsContent | 同上 |
| omd-launch-settings-ocr-tui | ocr | BarStatusPopup toolsContent | 同上 |
| omarchy-keyboard-apply | keyboard-remap | KeyboardRemap.qml + bin/omd-settings-keyboard | 同上 |
| omarchy-keyboard-list | keyboard-remap | KeyboardRemap.qml | 同上 |
| omarchy-keyboard-render | keyboard-remap | KeyboardRemap.qml + bin/omd-settings-keyboard | 同上 |
| omarchy-keyboard-setup | keyboard-remap | KeyboardRemap.qml + bin/omd-settings-keyboard | 同上 |
| omarchy-voice-download | voice | VoiceInput.qml + bin/omd-settings-voice | 同上 |
| omarchy-voice-record | voice | VoiceInput.qml | 同上 |
| omarchy-voice-setup | voice | VoiceInput.qml + bin/omd-settings-voice | 同上 |
| omarchy-voice-transcribe | voice | VoiceInput.qml + bin/omd-settings-voice | 同上 |

**风险**：如果 `~/development/sumika-modules/` 目录不存在，或启动脚本没有正确运行模块扫描，这些命令会找不到。但启动脚本有 `[ -d "$SUMIKA_MODULES_HOME" ]` 守卫——目录不存在时跳过整个模块扫描。

**后续**：在模块系统成熟前，应该将这些脚本**也保留在核心**（复制一份到 `bin/` 或 `share/bin/`），作为 fallback。这样即使模块目录不存在，核心功能也不受影响。

### 问题 6：module.json 格式不一致 🟡

| 问题 | 涉及模块 | 已修复? |
|---|---|---|
| `barButton`（单数字符串）vs `barButtons`（数组） | clipboard, display | ✅ 已修复 |
| `popupSections.type` 大小写不一致 | 需要逐一核对 | ⬜ |
| 缺少 `barButtons` 声明 | voice, input-method, session, systray, battery-power, mpris, keyboard-remap | ⬜ |
| 缺少 `configDefaults` | 多个模块 | ⬜ |

**后续**：需要逐一审查 14 个 module.json，确保格式统一。特别是 `popupSections.type` 必须与 BarStatusPopup 的 `barPopupType` 值完全匹配（大小写敏感）。

### 问题 7：qmldir 维护问题 🟢

已创建的 9 个 qmldir 需要手动维护。新增 QML 文件时必须更新对应 qmldir，否则 import 找不到新组件。

**后续**：可以写一个 `scripts/generate-qmldir.sh` 脚本，扫描目录下所有 .qml 文件，自动生成 qmldir（含 singleton 声明）。

---

## 四、架构分析

### 4.1 QML 模块系统的工作原理

Quickshell 使用 Qt 6 的 QML 引擎。QML 有两种 import 方式：

| 方式 | 语法 | 需要 qmldir? | 适用场景 |
|---|---|---|---|
| 相对目录 import | `import "modules/common"` | 否 | 核心代码（文件在同一个项目目录树内） |
| 限定模块 import | `import qs.modules.common` | 是 | 外部模块（文件在不同目录树） |

核心代码用相对 import（不需要 qmldir），外部模块用限定 import（需要 qmldir）。这就是为什么核心一直没 qmldir 也能工作，但模块需要。

### 4.2 Singleton 的限制

QML singleton 有严格的限制：
- 必须在 qmldir 中声明 `singleton`
- **编译时绑定**——不能运行时决定是否加载
- 不能通过 Loader 动态创建
- 一个模块名只能有一个 qmldir，一个 qmldir 中的 singleton 是全局唯一的

这意味着：
- **不能**"如果模块存在就 import 模块的 singleton，否则 import 核心的 singleton"
- **不能**运行时禁用 singleton（只能不 import 它的模块）
- 如果两个 qmldir 声明了同名 singleton（如核心 `qs.services.VoiceInput` 和模块 `qs.modules.voice.VoiceInput`），它们是**两个不同的实例**，状态不共享

### 4.3 Loader 动态加载的限制

Loader 是 QML 唯一的动态加载机制：
- `source` 可以是 `file://` URL 或相对路径
- 加载失败时 `status === Loader.Error`
- **不能**加载 singleton——只能加载普通组件
- Loader 加载的文件中的 `import` 语句必须能解析（需要 qmldir 或相对路径）

这意味着模块的服务如果要从 singleton 变为 Loader 加载，需要：
1. 删除 `pragma Singleton`
2. 改为普通 QML 组件
3. 通过 `Loader { source: "..." }` 或 `Qt.createComponent()` 加载
4. 所有引用 `XxxService.xxx` 的地方改为引用 Loader 的 item

这是一个**大规模重构**，影响每个引用该服务的文件。

### 4.4 循环依赖的本质

QML 模块系统的循环依赖源于"双向引用"：
- 父模块引用子模块的组件
- 子模块引用父模块的组件

在核心代码中这不是问题（相对 import 是扁平的，所有文件在同一目录树）。但限定 import 要求严格的模块层级——父模块先加载，子模块后加载，不能反向。

**解决方案的本质**：打破双向引用。要么把共享组件提到更高的层级（两边都依赖它），要么让一方不依赖另一方。

### 4.5 "工具箱"弹窗在模块化后的设计

当前"工具箱"（ToolsButton → toolsContent）是一个集中式入口，包含主题、语音、OCR、键盘、虚拟机、备份的启动按钮。

在模块化后，有两种设计：

**方案 A：保留工具箱作为核心**（当前临时方案）
- ToolsButton 和 toolsContent 保留在核心
- 工具箱里的每个条目启动对应的 TUI 设置程序
- 模块只提供 TUI 程序（bin 脚本），不提供弹窗 section
- 优点：简单，不需要模块的 popup QML
- 缺点：新增模块不能自动出现在工具箱中

**方案 B：工具箱条目由模块注册**
- ToolsButton 保留在核心
- toolsContent 改为 Repeater，加载模块注册的 `toolsEntry`
- 每个模块在 module.json 声明一个 `toolsEntry`（图标 + 标题 + 启动命令）
- 优点：新模块自动出现在工具箱
- 缺点：需要扩展 module.json 格式和 BarStatusPopup

**推荐**：短期用方案 A（保持当前恢复状态），中期切换到方案 B。

### 4.6 InputMethodButton 共享问题

`InputMethodButton.qml` 同时处理输入法和语音输入：
- 非录音状态：显示输入法状态（中/日/英 badge）
- 录音状态：显示语音录制 UI（麦克风图标 + 脉冲动画）

这是因为输入法和语音共用一个 bar 按钮槽位。拆分时不能简单地把按钮分到两个模块。

**解决方案**：
- **方案 A**：InputMethodButton 保留在核心，同时 `import qs.services` 使用 VoiceInput 和 InputMethod singleton。模块只提供服务，不提供按钮。
- **方案 B**：创建一个"语音+输入法"联合模块，包含 InputMethodButton。但这两个功能逻辑上不属于同一模块。
- **方案 C**：把 InputMethodButton 拆成两个按钮——一个输入法按钮（input-method 模块），一个语音按钮（voice 模块）。但用户已经习惯了它们合在一起。

**推荐**：方案 A（保留在核心），直到找到更好的 UI 设计。

### 4.7 DisplayButton + ScreenshotContextMenu 耦合

DisplayButton.qml 内嵌了 ScreenshotContextMenu（右键菜单）。截图功能从 DisplayButton 右键触发。这意味着：
- display 模块和 screenshot 模块有耦合
- 如果 screenshot 模块禁用，DisplayButton 的右键菜单应该消失或降级

**解决方案**：
- ScreenshotContextMenu 保留在核心（作为 DisplayButton 的一部分）
- screenshot 模块只提供 bin 脚本（omd-screenshot）和截图区域选择 UI
- DisplayButton 检查 `omd-screenshot` 是否在 PATH 中，不存在则隐藏右键菜单

---

## 五、每个模块的详细状态

### 5.1 file-backup（最简单，建议第一个完善）

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 3 个脚本在模块 |
| popup/ | ❌ BackupPopupSection.qml 用了 PopupColumn, PopupHeader, ToolLauncherRow（inline） |
| settings/ | ❌ BackupPage.qml（需要检查依赖） |
| services/ | 无（不需要服务） |
| bar/ | 无（不需要 bar 按钮，通过工具箱入口） |
| module.json | ✅ 存在 |

**需要修复**：提取 PopupColumn, PopupHeader, ToolLauncherRow 为独立文件后，更新 BackupPopupSection.qml 的 import。

### 5.2 ocr

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 4 个脚本在模块 |
| popup/ | ❌ OCRPopupSection.qml 用了 PopupColumn, PopupHeader, ToolLauncherRow |
| settings/ | ❌ OCRPage.qml |
| 核心耦合 | ScreenshotAction.qml 调用 `omd-ocr`，RegionSelector 有 OCR 模式 |

**需要修复**：同 file-backup + 确保 ScreenshotAction 的 `omd-ocr` 调用通过 PATH 解析。

### 5.3 windows-vm

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 2 个脚本在模块 |
| popup/ | ❌ WindowsVmPopup.qml 用了 PopupColumn, PopupHeader, ToolLauncherRow, Divider |
| settings/ | ❌ WindowsVmPage.qml（核心也有恢复副本） |

### 5.4 keyboard-remap

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 7 个脚本在模块 |
| services/ | ❌ KeyboardRemap.qml（非 singleton，核心有 singleton 副本） |
| popup/ | ❌ KeyboardPopup.qml 用了 PopupColumn, PopupHeader |
| settings/ | ❌ KeyboardRemapPage.qml + KeyboardEditorOverlay.qml（核心也有恢复副本） |
| 核心耦合 | KeyboardRemap.qml 被 shell.qml 和多个 QML 引用 |

**额外问题**：`bin/omd-settings-keyboard` 直接调用 `share/bin/omarchy-keyboard-*`（绝对路径），需要改为通过 PATH。

### 5.5 voice

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 7 个脚本在模块 |
| services/ | ❌ VoiceInput.qml（非 singleton，核心有 singleton 副本） |
| popup/ | ❌ VoicePopup.qml 用了 PopupColumn, PopupHeader, ActionRow, PopupActionButton |
| settings/ | ❌ VoicePage.qml（核心也有恢复副本，~700 行） |
| scripts/ | ✅ voice-bind-tui, key-test, key-test-launcher, key_*.py |
| 核心耦合 | VoiceInput 被 InputMethodButton 引用 |

### 5.6 input-method

| 项目 | 状态 |
|---|---|
| bin/ | ✅ omd-input-method 在模块 |
| services/ | ❌ InputMethod.qml（非 singleton，核心有 singleton 副本） |
| popup/ | ❌ InputMethodPopup.qml 用了 PopupColumn, PopupHeader |
| config/ | ✅ schemas.json 在模块 |
| 核心耦合 | InputMethod 被 InputMethodButton 引用；Config.qml 有 inputMethod 配置节 |

### 5.7 clipboard

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 3 个脚本在模块 |
| bar/ | ❌ ClipboardButton.qml（核心也有恢复副本） |
| 独立进程 | apps/omd-clipboard/ 仍在核心 |

### 5.8 display

| 项目 | 状态 |
|---|---|
| bin/ | ✅ 2 个脚本在模块 |
| bar/ | ❌ DisplayButton.qml（核心也有恢复副本） |
| popup/ | ❌ DisplayPopup.qml 用了 PopupColumn, PopupHeader, ToolLauncherRow |
| settings/ | ❌ DisplayConfigState.qml, DisplayPage.qml, MonitorCanvas.qml 等 |
| scripts/ | ✅ omarchy-hyprland-monitor-* 在模块 |
| 核心耦合 | DisplayButton 内嵌 ScreenshotContextMenu |

### 5.9 battery-power

| 项目 | 状态 |
|---|---|
| services/ | ❌ Battery.qml + PowerProfiles.qml（非 singleton，核心有 singleton 副本） |
| popup/ | ❌ BatteryPopup.qml 用了 ShellCard, PopupHeader, SectionLabel（~400 行） |
| settings/ | ❌ PowerPage.qml（核心也有恢复副本） |
| bar/ | 无（BarBatteryIcon 在 SidebarIndicators 内部，不是独立按钮） |

### 5.10 brightness-gamma

| 项目 | 状态 |
|---|---|
| services/ | ❌ Brightness.qml + Hyprsunset.qml |
| osd/ | ❌ BrightnessIndicator.qml + GammaIndicator.qml |
| scripts/ | omarchy-brightness-* 在模块 |
| 核心耦合 | Brightness 被 DisplayButton、batteryContent、hypridle 引用 |

### 5.11 mpris

| 项目 | 状态 |
|---|---|
| services/ | ❌ MprisController.qml + TrackArt.qml |
| popup/ | 无（媒体控制在 BarStatusPopup 的 mediaContent，~340 行，未提取到模块） |
| bar/ | 无 |

**注意**：mpris 模块的 popup section 没有被提取——媒体控制仍在 BarStatusPopup 核心代码中。

### 5.12 systray

| 项目 | 状态 |
|---|---|
| services/ | ❌ TrayService.qml |
| bar/ | ❌ SysTray.qml + SysTrayItem.qml + SysTrayMenu.qml + SysTrayMenuEntry.qml（仍在核心） |

**注意**：SysTray 组件仍在核心，没有被移到模块。

### 5.13 session

| 项目 | 状态 |
|---|---|
| services/ | 空（Session.qml 保留在 core/modules/common/functions/） |
| popup/ | ❌ SessionPopup.qml 用了 PopupColumn, PopupHeader, IconActionRow, PopupIconButton |
| 核心耦合 | SessionButton、SessionRestoreOverlay、SessionAutoRestore、SessionConfirmOverlay 仍在核心 |

### 5.14 screenshot

| 项目 | 状态 |
|---|---|
| bin/ | ✅ omd-screenshot 在模块 |
| utils/ | ❌ ScreenshotAction.qml（仍在核心） |
| 核心耦合 | regionSelector/ 仍在核心；DisplayButton 内嵌 ScreenshotContextMenu |

---

## 六、当前未清理干净的地方

### 6.1 模块目录中的死代码

`~/development/sumika-modules/` 下 14 个模块目录：
- **所有 QML 文件不可用**（inline component 依赖）
- **bin 脚本是核心副本**（重复但无害）
- **services 是核心的非 singleton 副本**（死代码）

### 6.2 ModuleLoader.qml 未被使用

存在并注册在 qmldir 中，但 BarContent 和 BarStatusPopup 是原始版本（无 Repeater），没人调用 ModuleLoader。

### 6.3 启动脚本扫描结果未被使用

生成注册表并注入 PATH/QML_IMPORT_PATH，但因为模块 QML 不可用，注册表中的数据虽然正确但无人消费。

### 6.4 Config.qml modules 字段未被使用

`modules.disabled` 和 `modules.barButtonOrder` 存在但无代码读取。

### 6.5 qmldir 文件可能影响核心代码

已创建的 9 个 qmldir 改变了 QML 的模块解析方式。核心代码用相对 import 不受影响，但如果某个核心文件意外使用了限定 import（如 `import qs.services`），行为可能变化。需要验证。

### 6.6 git 历史中的模块拆分 commit

commit `37f7724` 到 `ed69775` 是另一个智能体的拆分 commit。这些 commit 删除了核心文件、修改了 QML 代码。我后续的修复 commit 恢复了大部分。但 git 历史比较混乱——如果需要 clean history，可以考虑 squash 或 rebase。

---

## 七、后续计划

### 阶段 1：完善模块 QML 文件（当前优先）

**目标**：让模块 QML 文件能独立编译通过，即使还不接入核心。

**步骤**：

1. **提取 10 个 inline component** 为独立 QML 文件
   - 创建 `quickshell/modules/bar/components/` 目录
   - 每个 component 一个文件，从 BarStatusPopup.qml 复制代码
   - 创建 `components/qmldir`（`module qs.modules.bar.components`）
   - BarStatusPopup.qml 改为 import components 并使用独立文件

2. **移动共享 bar 组件到 common/widgets**
   - CircleUtilButton.qml → common/widgets/
   - BarNerdIcon.qml → common/widgets/
   - 更新 common/widgets/qmldir
   - 更新所有引用这些组件的文件（改 import 路径）

3. **逐个修复模块 QML 文件的 import**
   - 从 file-backup 开始（最简单）
   - 确保每个模块 QML 文件能独立编译
   - 测试方法：`qs -p <module_dir>` 单独加载

4. **验证模块 popup 通过 Loader 加载**
   - 在 BarStatusPopup.qml 中加入 Repeater
   - 逐一启用模块，测试弹窗功能

### 阶段 2：接入模块到核心

1. BarContent.qml 加入模块 bar 按钮 Repeater
2. BarStatusPopup.qml 加入模块 popup section Repeater
3. SettingsDialog 加入模块设置页 Repeater
4. 逐个从核心删除已模块化的代码
5. 每删一个就编译 + 运行测试

### 阶段 3：服务模块化

1. 设计"核心 fallback singleton"模式
2. 逐个将服务从核心迁移到模块
3. 解决两份 singleton 实例的问题

### 阶段 4：完善模块系统

1. module.json 格式统一
2. 配置合并机制
3. 翻译合并
4. Hyprland binding 模块化
5. 模块版本号和兼容性检查
6. 模块安装脚本（install.sh）
7. omd-doctor 模块健康检查

---

## 八、优化建议

### 8.1 qmldir 自动生成脚本

创建 `scripts/generate-qmldir.sh`：
```bash
#!/bin/bash
# 为指定目录生成 qmldir（含 singleton 声明）
dir="$1"
module_name="$2"
echo "module $module_name" > "$dir/qmldir"
for f in "$dir"/*.qml; do
    name=$(basename "$f" .qml)
    if grep -q "pragma Singleton" "$f"; then
        echo "singleton $name 1.0 $(basename $f)" >> "$dir/qmldir"
    else
        echo "$name 1.0 $(basename $f)" >> "$dir/qmldir"
    fi
done
```

### 8.2 模块 QML 编译测试脚本

创建 `scripts/test-module-compile.sh`：
```bash
#!/bin/bash
# 单独编译测试一个模块的 QML 文件
module_dir="$1"
for qml in "$module_dir"/**/*.qml; do
    echo -n "Testing $(basename $qml): "
    # 用 qs --check 或类似命令验证语法
    timeout 5 qs -p "$module_dir" 2>&1 | grep -oE "ERROR|OK" | head -1
done
```

### 8.3 ModuleLoader 改进

当前用 Process 异步读取注册表。可以改进为：
- 使用 `FileView` + `JsonAdapter`（像 Config.qml 一样），支持文件监听
- 或在启动脚本中将注册表内容直接写入环境变量

### 8.4 启动脚本改进

- 添加模块健康检查（module.json 格式验证、必需文件存在性检查）
- 模块加载失败时的用户通知（notify-send）
- 模块依赖检查（module.json 的 dependencies 字段）

### 8.5 bar 按钮排序

当前 `barButtonOrder` 配置存在但未实现。应该在 ModuleLoader.barButtons 中读取用户配置的顺序，覆盖 module.json 的 defaultOrder。

### 8.6 模块禁用的运行时反馈

当用户在 config.json 中禁用模块时，应该有视觉反馈（如设置页显示"X 个模块已禁用"）。当前 modules.disabled 存在但无 UI。

---

## 九、数据总结

| 项目 | 数量 |
|---|---|
| 核心恢复的 QML 文件 | 12（bar buttons + settings pages） |
| 核心恢复的行数 | ~4739 行 |
| 模块目录 | 14 个 |
| 模块 QML 文件（全部不可用） | ~30 个 |
| 模块 bin 脚本（核心也有副本） | 15 个 |
| 模块 bin 脚本（核心没有，仅模块有） | 15 个 |
| 模块 services（核心也有副本） | 10 个 |
| 创建的 qmldir 文件 | 9 个 |
| 修复的 bug | 6 个 |
| 遗留的 inline component | 10 个 |
| 依赖 inline component 的模块文件 | 9 个 |
| bar 按钮循环依赖 | 1 组（BarContent ↔ DisplayButton） |
| 共享组件需移动到 common | 2-3 个（CircleUtilButton, BarNerdIcon, BarTextButton） |