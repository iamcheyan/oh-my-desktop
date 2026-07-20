# 模块拆分当前状态与问题报告

> 日期：2026-07-20
> 背景：另一个智能体执行了 14 模块拆分，但导致功能大面积损坏。我（检查智能体）修复了编译和核心功能，但模块系统尚未真正可用。本文档记录所有现状、临时方案、残留问题和后续计划。

---

## 一、当前可运行状态

### ✅ 正常工作的（核心已恢复）

所有核心 UI 和功能已从拆分前的 git 历史恢复，编译通过：

- **顶栏全部 10 个按钮**：SysTray、InputMethodButton、AudioButton、WifiButton、ClipboardButton、SessionButton、DisplayButton、ToolsButton、ClockWidget、SidebarIndicators
- **弹窗全部 13 个 section**：tools、inputMethod、keyboard、session、xkb、wifi、bluetooth、audio、display、battery、notifications、voice、empty
- **设置页全部 11 个**：Overview、Appearance、Sound、Power、System、Network、Bluetooth、Voice、WindowsVm、KeyboardRemap、KeyboardEditor
- **全部 4 个 Quickshell 进程**：omd-bar、omd-overview、omd-applauncher、omd-clipboard 编译通过
- **所有 bin 脚本**：通过 omd-legacy-omarchy 分发器或真实文件正常工作

### ⚠️ 模块系统（基础设施存在但未真正接入）

以下基础设施已创建并修复，但**模块 QML 文件无法实际加载**（原因见下）：

- `ModuleLoader.qml` — 单例，通过 Process + StdioCollector 读取注册表 JSON
- `quickshell/qmldir` — 声明 `qs` 模块和 ModuleLoader 单例
- `quickshell/scripts/quickshell` — 启动时扫描 `~/development/sumika-modules/`，生成注册表
- `Config.qml` — 有 `modules.disabled` 和 `modules.barButtonOrder` 字段
- `defaults/config/quickshell/config.json` — 有 `modules` 节
- BarContent.qml — 有模块 Repeater（但当前版本是从 git 恢复的原始版本，无 Repeater）
- BarStatusPopup.qml — 有模块 Repeater（但当前版本是从 git 恢复的原始版本，无 Repeater）

---

## 二、临时修复方案（我做的）

### 1. 恢复 BarContent.qml 和 BarStatusPopup.qml

**问题**：另一个智能体从这两个文件删除了所有模块相关的 section 和按钮，导致功能大面积丢失。

**临时方案**：从 commit `65c3637`（拆分前最后一个 commit）完整恢复两个文件。这丢失了模块 Repeater 代码，但恢复了所有功能。

**后续应该**：重新加入模块 Repeater（但需要先解决模块 QML 的 inline component 问题，见下）。

### 2. 恢复 bar/modules/ 下的按钮文件

**问题**：ClipboardButton.qml、DisplayButton.qml、SessionButton.qml、ScreenshotContextMenu.qml 被移到模块目录，核心代码引用它们时找不到。

**临时方案**：从 git 历史恢复到 `quickshell/modules/bar/modules/`。

**后续应该**：这些文件在模块目录（`sumika-modules/clipboard/bar/` 等）也有副本。最终应从核心删除，只保留在模块中——但前提是模块的 bar 按钮能通过 Repeater 正确加载。

### 3. 恢复 settings/pages/ 下的设置页

**问题**：VoicePage.qml、WindowsVmPage.qml、KeyboardRemapPage.qml、KeyboardEditorOverlay.qml、PowerPage.qml 被移到模块，设置中心找不到。

**临时方案**：从 git 历史恢复到 `quickshell/modules/settings/pages/` 并更新 `pages/qmldir`。

**后续应该**：同上，最终应移到模块，但需要模块 QML 能正确加载。

### 4. 创建 qmldir 文件

**问题**：模块 QML 文件用 `import qs.services`、`import qs.modules.common` 等限定导入，但这些目录没有 qmldir，导入无法解析。

**临时方案**：为 `services/`、`modules/common/`、`modules/common/widgets/`、`modules/common/functions/` 创建了 qmldir，含 singleton 声明。

**后续应该**：保留这些 qmldir（模块系统需要它们）。但不要为 `bar/` 和 `bar/modules/` 创建 qmldir——会导致循环依赖（BarContent ↔ DisplayButton）。

### 5. 修复启动脚本 jq bug

**问题**：jq 表达式中 `$module_dir` 是 shell 变量，未通过 `--arg` 传入 jq，导致注册表始终为空。

**临时方案**：加 `--arg mdir "$module_dir"`，并在 component 路径前加 `file://`。

**后续应该**：保留此修复。

### 6. 修复 ModuleLoader.qml

**问题**：用了不存在的 `Quickshell.readFile()` API。

**临时方案**：改为 `Process` + `StdioCollector`（cat 注册表 JSON）。

**后续应该**：保留此修复。但 Process 是异步的，ModuleLoader 的属性在进程完成前是空的——对于启动时不需要模块数据的场景可接受。

---

## 三、模块目录的问题（`~/development/sumika-modules/`）

### 问题 1：所有模块弹窗 QML 使用核心的 inline component

**严重度**：🔴 阻断性

9 个模块的 popup QML 文件使用了 `ShellCard`、`PopupColumn`、`PopupHeader`、`ToolLauncherRow`、`Divider`、`SectionLabel`、`ActionRow`、`PopupActionButton`、`IconActionRow`、`PopupIconButton` — 这些都是 `BarStatusPopup.qml` 内的 inline component（`component ShellCard: Item { ... }`），**不是独立 QML 文件，无法被模块文件 import**。

| 模块 | 使用的 inline component |
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

**解决**：将这 10 个 inline component 提取为独立 QML 文件，放在 `quickshell/modules/bar/` 下，并在 bar qmldir 中注册。但注意 bar qmldir 会引起循环依赖（见下）。

### 问题 2：bar qmldir 循环依赖

**严重度**：🔴 阻断性

如果创建 `quickshell/modules/bar/qmldir`（声明 `module qs.modules.bar`），会导致循环依赖：
- BarContent.qml 在 `qs.modules.bar` 中
- BarContent 引用 DisplayButton（在 `qs.modules.bar.modules` 中）
- DisplayButton 引用 CircleUtilButton、BarNerdIcon（在 `qs.modules.bar` 中）
- QML 引擎无法解析这种循环

**解决**：
- 方案 A：把 CircleUtilButton、BarNerdIcon 等共享组件移到 `qs.modules.common.widgets`
- 方案 B：模块文件不 import `qs.modules.bar`，所需组件通过其他方式获取
- 方案 C：使用相对 import 而非限定 import（但模块文件在不同目录，不能用相对 import）

### 问题 3：服务文件重复（核心 + 模块各一份）

**严重度**：🟡 浪费但不影响功能

10 个服务文件在核心（`quickshell/services/`，`pragma Singleton`）和模块（`sumika-modules/*/services/`，非 singleton）各有一份：

| 服务 | 核心版本 | 模块版本 |
|---|---|---|
| Battery.qml | singleton ✅ | 非 singleton（battery-power） |
| PowerProfiles.qml | singleton ✅ | 非 singleton（battery-power） |
| Brightness.qml | singleton ✅ | 非 singleton（brightness-gamma） |
| Hyprsunset.qml | singleton ✅ | 非 singleton（brightness-gamma） |
| InputMethod.qml | singleton ✅ | 非 singleton（input-method） |
| KeyboardRemap.qml | singleton ✅ | 非 singleton（keyboard-remap） |
| MprisController.qml | singleton ✅ | 非 singleton（mpris） |
| TrackArt.qml | singleton ✅ | 非 singleton（mpris） |
| TrayService.qml | singleton ✅ | 非 singleton（systray） |
| VoiceInput.qml | singleton ✅ | 非 singleton（voice） |

**当前**：核心版本被使用（因为是 singleton，所有 QML 都 import 它）。模块版本是死代码。

**后续**：当模块系统成熟后，核心版本应删除，模块版本改为 singleton 并通过 qmldir 注册。但需要解决 QML singleton 不能动态加载的问题。

### 问题 4：bin 脚本重复

**严重度**：🟡 浪费但不影响功能

15 个 bin 脚本在核心（`bin/` 或 `share/bin/`）和模块（`sumika-modules/*/bin/`）各有一份。启动脚本会将模块的 `bin/` 加入 PATH，但核心的 `bin/` 也在 PATH 中——取决于 PATH 顺序，可能执行错误的版本。

**当前**：核心版本先被找到（因为 `bin/` 在 PATH 前面）。

**后续**：当模块系统成熟后，从核心删除对应脚本。目前保留两份不影响功能。

### 问题 5：15 个 bin 脚本从核心删除但仍在使用

**严重度**：🟡 潜在问题

以下脚本被移到模块目录，从核心删除了。但核心代码（BarStatusPopup 等）仍然引用它们：

| 脚本 | 在模块 | 核心引用者 |
|---|---|---|
| omd-backup | file-backup | BarStatusPopup toolsContent |
| omd-settings-backup-tui | file-backup | BarStatusPopup toolsContent |
| omd-launch-settings-backup-tui | file-backup | BarStatusPopup toolsContent |
| omd-ocr | ocr | ScreenshotAction.qml |
| omd-settings-ocr* | ocr | BarStatusPopup toolsContent |
| omarchy-keyboard-* | keyboard-remap | KeyboardRemap.qml + bin/omd-settings-keyboard |
| omarchy-voice-* | voice | VoiceInput.qml + bin/omd-settings-voice |

**当前**：这些脚本通过启动脚本的 PATH 注入（模块 `bin/` 加入 PATH）可以被找到。但如果模块目录不存在或启动脚本没运行，这些命令会找不到。

**后续**：要么在核心保留这些脚本（直到模块系统成熟），要么确保启动脚本的 PATH 注入可靠。

### 问题 6：module.json 格式不一致

**严重度**：🟡

- clipboard 和 display 曾用 `barButton`（单数字符串）而非 `barButtons`（数组）— 已修复
- 部分模块的 `popupSections` 的 `type` 值与 BarStatusPopup 的 `barPopupType` 值不匹配（如 `"inputMethod"` vs `"inputmethod"` 大小写）
- 部分模块缺少 `barButtons` 声明（如 voice、input-method、session 应有 bar 按钮但没有声明）

### 问题 7：qmldir singleton 声明可能与实际不匹配

**严重度**：🟢 低

我为 `services/qmldir` 和 `common/qmldir` 自动生成了 singleton 声明。如果后续有新增的服务文件或组件文件，需要手动更新 qmldir。当前所有文件都已正确声明。

---

## 四、当前未清理干净的地方

### 4.1 模块目录中的死代码

`~/development/sumika-modules/` 下的 14 个模块目录全部存在，但：
- **模块 QML 文件全部不可用**（inline component 依赖问题）
- **模块 bin 脚本是核心脚本的副本**（重复但无害）
- **模块 services 是核心 services 的非 singleton 副本**（死代码）

这些目录可以保留（作为未来模块化的基础），也可以删除（因为当前完全不可用）。

### 4.2 ModuleLoader.qml 和 qmldir

`ModuleLoader.qml` 存在并注册在 `quickshell/qmldir` 中，但当前 BarContent 和 BarStatusPopup 是从 git 恢复的原始版本，没有 Repeater 调用 ModuleLoader。所以 ModuleLoader 虽然加载了注册表，但没人用它。

### 4.3 启动脚本的模块扫描

启动脚本会扫描 `~/development/sumika-modules/`，生成注册表，注入 PATH 和 QML_IMPORT_PATH。但因为模块 QML 不可用，注册表中的 `barButtons`、`popupSections`、`settingsPages` 虽然有数据但加载会失败。

### 4.4 Config.qml 的 modules 字段

`Config.qml` 有 `modules.disabled` 和 `modules.barButtonOrder` 字段，`defaults/config/quickshell/config.json` 也有对应节。但当前没有任何代码读取 `modules.disabled`（因为核心代码不通过 ModuleLoader 加载模块）。

---

## 五、后续应该怎么做

### 短期（恢复到干净状态）

1. **确认所有功能正常**：跑 `omd-restart`，测试每个按钮和弹窗
2. **删除模块目录中的死代码**：可以选择
   - A. 完全删除 `~/development/sumika-modules/`（回退到拆分前）
   - B. 保留目录但清空 QML 文件（只保留 bin 脚本和 module.json 作为占位）
3. **保留基础设施**：ModuleLoader.qml、qmldir、启动脚本扫描、Config.qml modules 字段——这些不碍事

### 中期（正确实现模块化）

1. **提取 inline component**：将 ShellCard、PopupColumn、PopupHeader 等 10 个 inline component 从 BarStatusPopup.qml 提取为独立 QML 文件，放在 `quickshell/modules/bar/components/` 下，创建 qmldir
2. **解决循环依赖**：将 CircleUtilButton、BarNerdIcon 等共享组件移到 `qs.modules.common.widgets`
3. **创建 bar qmldir**：在循环依赖解决后，为 `bar/` 和 `bar/modules/` 创建 qmldir
4. **逐个测试模块**：每次只接入一个模块，编译→运行→验证
5. **从最简单开始**：file-backup（只用 ToolLauncherRow，不需要 ShellCard）

### 长期（完全模块化）

1. 服务从核心 singleton 转为模块 singleton（需解决 QML singleton 不能动态加载的问题）
2. bin 脚本从核心删除，只保留在模块
3. 设置页从核心删除，通过模块 Repeater 加载
4. Hyprland 配置模块化（bindings、window rules）
5. 翻译合并
6. 模块版本号和兼容性检查

---

## 六、数据总结

| 项目 | 数量 |
|---|---|
| 核心恢复的 QML 文件 | 12（bar buttons + settings pages） |
| 核心恢复的行数 | ~4739 行 |
| 模块目录 | 14 个 |
| 模块 QML 文件（全部不可用） | ~30 个 |
| 模块 bin 脚本（核心也有副本） | 15 个 |
| 模块 services（核心也有副本） | 10 个 |
| 创建的 qmldir 文件 | 9 个（services + common 系列） |
| 修复的 bug | 6 个（jq、readFile、hyphenated imports、duplicate battery、missing buttons、missing pages） |
| 遗留的 inline component 依赖 | 10 个 component × 9 个模块文件 |