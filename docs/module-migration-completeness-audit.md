# 模块迁移完整性审计报告

> 日期：2026-07-20
> 结论：**绝大多数模块迁移不完整**。模块目录里只有壳（module.json + 1-2 个 QML 文件），实际代码几乎全部还在主仓库。

---

## 完整度总览

| 模块 | 模块内文件 | 核心残留文件 | 完整度 | 严重度 |
|---|---|---|---|---|
| popup-components | 12 | 0 | ✅ 100% | — |
| file-backup | 5 | 4 | 🟡 55% | 🟡 |
| ocr | 5 | 4 | 🟡 55% | 🟡 |
| windows-vm | 4 | 2 | 🟡 67% | 🟡 |
| keyboard-remap | 3 | 9 | 🔴 25% | 🔴 |
| voice | 4 | 15 | 🔴 21% | 🔴 |
| input-method | 4 | 5 | 🟡 44% | 🟡 |
| clipboard | 1 | 15 | 🔴 6% | 🔴 |
| display | 3 | 17 | 🔴 15% | 🔴 |
| battery-power | 3 | 9 | 🔴 25% | 🔴 |
| brightness-gamma | 1 | 10 | 🔴 9% | 🔴 |
| mpris | 1 | 4 | 🔴 20% | 🔴 |
| systray | 1 | 6 | 🔴 14% | 🔴 |
| session | 2 | 6 | 🔴 25% | 🔴 |
| screenshot | 1 | 21 | 🔴 5% | 🔴 |

**整体完整度：约 20%**。14 个功能模块中，只有 popup-components（共享模块）是完整的。其余 13 个模块平均只有壳，90%+ 的代码还在主仓库。

---

## 逐模块详细审计

### 1. screenshot — 🔴 几乎没移（5%）

**模块内**：只有 `module.json` + `qmldir`（空壳）

**核心残留**（21 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `apps/omd-screenshot/` (整个目录) | 独立进程 | 截图进程的 shell.qml + services + translations |
| `apps/omd-screenshot/modules/regionSelector/` | QML | 区域选择器（截图核心 UI） |
| `apps/omd-screenshot/services/` | QML | 截图进程的服务副本 |
| `bin/omd-screenshot` | 脚本 | 截图启动命令 |
| `quickshell/modules/regionSelector/` (8 个文件) | QML | CircleSelectionDetails, CursorGuide, OptionsToolbar, RectCornersSelectionDetails, RegionFunctions, RegionSelection, RegionSelector, TargetRegion |
| `quickshell/modules/common/utils/ScreenshotAction.qml` | QML | 截图后动作（OCR/复制/保存） |
| `quickshell/modules/bar/modules/ScreenshotContextMenu.qml` | QML | DisplayButton 右键截图菜单 |

**结论**：screenshot 模块完全没移。区域选择器、截图进程、截图动作、右键菜单全在核心。

---

### 2. clipboard — 🔴 几乎没移（6%）

**模块内**：只有 `module.json`（空壳）

**核心残留**（15 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `apps/omd-clipboard/` (整个目录) | 独立进程 | 剪贴板进程 shell.qml + services + widgets |
| `apps/omd-clipboard/modules/clipboard/` | QML | ClipboardDialog, ClipboardItem, ClipboardStyle, CliphistImage, Fuzzy, fuzzysort.js |
| `apps/omd-clipboard/services/Cliphist.qml` | QML | 剪贴板历史服务 |
| `bin/omd-clipboard` | 脚本 | 剪贴板启动 |
| `bin/omd-clipboard-store` | 脚本 | 剪贴板存储 |
| `bin/omd-kitty-smart-paste` | 脚本 | kitty 智能粘贴 |
| `hypr/default/hypr/bindings/clipboard.lua` | Lua | 剪贴板 Hyprland 绑定 |
| `quickshell/modules/bar/modules/ClipboardButton.qml` | QML | bar 按钮 |
| `scripts/key_capture_clipboard.py` | Python | 按键捕获辅助 |

**结论**：clipboard 模块完全没移。独立进程、bar 按钮、bin 脚本、Hyprland 绑定全在核心。

---

### 3. brightness-gamma — 🔴 几乎没移（9%）

**模块内**：只有 `module.json`（空壳）

**核心残留**（10 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/Brightness.qml` | QML singleton | 亮度服务 |
| `quickshell/services/Hyprsunset.qml` | QML singleton | 夜间模式服务 |
| `quickshell/modules/onScreenDisplay/indicators/BrightnessIndicator.qml` | QML | 亮度 OSD |
| `quickshell/modules/onScreenDisplay/indicators/GammaIndicator.qml` | QML | 色温 OSD |
| `bin/omd-brightness-display` | symlink | → omarchy-brightness-display |
| `bin/omd-brightness-keyboard` | symlink | → omarchy-brightness-keyboard |
| `share/bin/omarchy-brightness-display` | 脚本 | 亮度控制底层 |
| `share/bin/omarchy-brightness-keyboard` | 脚本 | 键盘背光底层 |
| `hypr/hyprsunset.conf` | 配置 | hyprsunset 配置 |
| `apps/omd-settings/services/Brightness.qml` + `Hyprsunset.qml` | QML | 设置进程中的服务副本 |

**结论**：brightness-gamma 模块完全没移。服务、OSD、脚本、配置全在核心。

---

### 4. systray — 🔴 几乎没移（14%）

**模块内**：只有 `module.json`（空壳）

**核心残留**（6 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/TrayService.qml` | QML singleton | 托盘服务 |
| `quickshell/modules/bar/SysTray.qml` | QML | 托盘组件 |
| `quickshell/modules/bar/SysTrayItem.qml` | QML | 托盘项 |
| `quickshell/modules/bar/SysTrayMenu.qml` | QML | 托盘菜单 |
| `quickshell/modules/bar/SysTrayMenuEntry.qml` | QML | 托盘菜单项 |
| `apps/omd-settings/services/TrayService.qml` | QML | 设置进程中的服务副本 |

**结论**：systray 模块完全没移。服务和全部 4 个 bar 组件在核心。

---

### 5. display — 🔴 大量残留（15%）

**模块内**：`module.json` + `popup/DisplayPopup.qml` + `qmldir`

**核心残留**（17 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/modules/bar/modules/DisplayButton.qml` | QML | bar 按钮 |
| `quickshell/modules/bar/modules/ScreenshotContextMenu.qml` | QML | 右键截图菜单 |
| `quickshell/modules/settings/display/` (7 个文件) | QML | DisplayConfigState, DisplayPage, MonitorCanvas, MonitorIdentifyOverlay, MonitorRect, OutputDetailPane, OutputSummaryCard |
| `quickshell/modules/onScreenDisplay/` (6 个文件) | QML | OnScreenDisplay, OsdValueIndicator + 4 个 indicators |
| `bin/omd-display-config` | 脚本 | 显示器配置 |
| `bin/omd-ddc-detect` | 脚本 | DDC 检测 |
| `bin/omd-brightness-display` | symlink | 亮度控制（与 brightness-gamma 重叠） |
| `share/bin/omarchy-brightness-display` | 脚本 | 亮度底层 |

**结论**：display 模块只移了 popup QML。bar 按钮、7 个设置页、6 个 OSD 组件、3 个 bin 脚本全在核心。

---

### 6. mpris — 🔴 大量残留（20%）

**模块内**：只有 `module.json`（空壳）

**核心残留**（4 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/MprisController.qml` | QML singleton | MPRIS 控制器 |
| `quickshell/services/TrackArt.qml` | QML singleton | 专辑封面 |
| `quickshell/modules/bar/BarStatusPopup.qml` | QML | 媒体控制弹窗 section（~340 行，内嵌在 BarStatusPopup 中） |
| `apps/omd-settings/services/MprisController.qml` | QML | 设置进程中的服务副本 |

**结论**：mpris 模块完全没移。2 个服务在核心，媒体弹窗 section 内嵌在 BarStatusPopup 中（未提取）。

---

### 7. voice — 🔴 大量残留（21%）

**模块内**：`module.json` + `popup/VoicePopup.qml` + `settings/VoicePage.qml`

**核心残留**（15 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/VoiceInput.qml` | QML singleton | 语音服务 |
| `quickshell/modules/settings/pages/VoicePage.qml` | QML | 设置页（与模块重复） |
| `quickshell/modules/bar/modules/InputMethodButton.qml` | QML | 共享按钮（语音+输入法） |
| `bin/omd-voice-download` | symlink | → omarchy-voice-download |
| `bin/omd-voice-record` | symlink | → omarchy-voice-record |
| `bin/omd-voice-setup` | symlink | → omarchy-voice-setup |
| `bin/omd-voice-transcribe` | symlink | → omarchy-voice-transcribe |
| `share/bin/omarchy-voice-download` | 脚本 | 语音下载 |
| `share/bin/omarchy-voice-record` | 脚本 | 语音录制 |
| `share/bin/omarchy-voice-setup` | 脚本 | 语音安装 |
| `share/bin/omarchy-voice-transcribe` | 脚本 | 语音转文字 |
| `bin/omd-settings-voice` + `omd-settings-voice-tui` | 脚本 | 语音设置 TUI |
| `bin/omd-edit-voice-bindings` | 脚本 | 语音快捷键编辑 |
| `bin/omd-launch-settings-voice-tui` | 脚本 | TUI 启动器 |
| `scripts/voice-bind-tui` | 脚本 | 快捷键 TUI |

**结论**：voice 模块只移了 popup + settings QML。服务 singleton、4 个底层脚本、4 个 TUI 脚本、1 个辅助脚本全在核心。

---

### 8. keyboard-remap — 🔴 大量残留（25%）

**模块内**：`module.json` + `popup/KeyboardPopup.qml`

**核心残留**（9 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/KeyboardRemap.qml` | QML singleton | 键盘重映射服务 |
| `quickshell/modules/settings/pages/KeyboardRemapPage.qml` | QML | 设置页 |
| `quickshell/modules/settings/pages/KeyboardEditorOverlay.qml` | QML | 编辑器覆盖层 |
| `defaults/config/keyboard-remap/profiles.json` | JSON | 空模板 |
| `scripts/key-test` | Python | 按键测试 |
| `scripts/key-test-launcher` | 脚本 | 测试启动器 |
| `scripts/key_capture_clipboard.py` | Python | 按键捕获 |
| `scripts/key_evdev_names.py` | Python | evdev 键名映射 |
| `apps/omd-settings/services/KeyboardRemap.qml` | QML | 设置进程中的服务副本 |

**结论**：keyboard-remap 模块只移了 popup QML。服务、2 个设置页、4 个辅助脚本、空模板全在核心。

---

### 9. battery-power — 🔴 大量残留（25%）

**模块内**：`module.json` + `popup/BatteryPopup.qml`

**核心残留**（9 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/Battery.qml` | QML singleton | 电池服务 |
| `quickshell/services/PowerProfiles.qml` | QML singleton | 电源配置服务 |
| `quickshell/modules/bar/BarBatteryIcon.qml` | QML | 电池图标组件 |
| `quickshell/modules/bar/PowerContextMenu.qml` | QML | 电源菜单 |
| `quickshell/modules/settings/pages/PowerPage.qml` | QML | 设置页 |
| `bin/omd-powerprofiles-init` | symlink | → omarchy-powerprofiles-init |
| `share/bin/omarchy-powerprofiles-init` | 脚本 | 电源配置初始化 |
| `apps/omd-settings/services/Battery.qml` + `PowerProfiles.qml` | QML | 设置进程中的服务副本 |

**结论**：battery-power 模块只移了 popup QML。2 个服务、2 个 bar 组件、设置页、1 个脚本全在核心。

---

### 10. session — 🔴 大量残留（25%）

**模块内**：`module.json` + `popup/SessionPopup.qml`

**核心残留**（6 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/modules/common/functions/Session.qml` | QML singleton | 会话服务 |
| `quickshell/modules/bar/modules/SessionButton.qml` | QML | bar 按钮 |
| `quickshell/modules/bar/SessionRestoreOverlay.qml` | QML | 恢复覆盖层 |
| `quickshell/modules/bar/SessionAutoRestore.qml` | QML | 自动恢复 |
| `quickshell/modules/bar/SessionConfirmOverlay.qml` | QML | 确认覆盖层 |
| `bin/omd-session` | 脚本 | 会话保存/恢复 |

**结论**：session 模块只移了 popup QML。服务、bar 按钮、3 个覆盖层组件、1 个脚本全在核心。

---

### 11. input-method — 🟡 部分残留（44%）

**模块内**：`module.json` + `popup/InputMethodPopup.qml` + `config/schemas.json`

**核心残留**（5 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `quickshell/services/InputMethod.qml` | QML singleton | 输入法服务 |
| `quickshell/modules/bar/modules/InputMethodButton.qml` | QML | bar 按钮（与 voice 共享） |
| `quickshell/modules/onScreenDisplay/indicators/InputMethodIndicator.qml` | QML | OSD 指示器 |
| `bin/omd-input-method` | 脚本 | 输入法状态/切换 |
| `defaults/config/input-method/schemas.json` | JSON | 空模板（与模块内重复） |

**结论**：input-method 模块移了 popup + config，但服务、bar 按钮、OSD、脚本、默认模板全在核心。

---

### 12. windows-vm — 🟡 部分残留（67%）

**模块内**：`module.json` + `popup/WindowsVmPopup.qml` + `settings/WindowsVmPage.qml`

**核心残留**（2 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `bin/omd-settings-windows-vm` | 脚本 | VM 管理 TUI |
| `bin/omd-settings-vm-tui` | 脚本 | VM TUI |

**结论**：windows-vm 模块移了 popup + settings，但 2 个 bin 脚本还在核心。

---

### 13. file-backup — 🟡 部分残留（55%）

**模块内**：`module.json` + `popup/BackupPopupSection.qml` + `settings/BackupPage.qml`

**核心残留**（4 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `bin/omd-backup` | 脚本 | SMB 备份 |
| `bin/omd-settings-backup-tui` | 脚本 | 备份 TUI |
| `bin/omd-launch-settings-backup-tui` | 脚本 | TUI 启动器 |
| `share/polkit-1/rules.d/50-omd-backup.rules` | polkit | polkit 规则 |

**结论**：file-backup 模块移了 popup + settings，但 3 个 bin 脚本 + 1 个 polkit 规则在核心。

---

### 14. ocr — 🟡 部分残留（55%）

**模块内**：`module.json` + `popup/OCRPopupSection.qml` + `settings/OCRPage.qml`

**核心残留**（4 个文件）：

| 文件 | 类型 | 说明 |
|---|---|---|
| `bin/omd-ocr` | 脚本 | PaddleOCR |
| `bin/omd-settings-ocr` | 脚本 | OCR 设置 |
| `bin/omd-settings-ocr-tui` | 脚本 | OCR TUI |
| `bin/omd-launch-settings-ocr-tui` | 脚本 | TUI 启动器 |

**结论**：ocr 模块移了 popup + settings，但 4 个 bin 脚本在核心。

---

## 按文件类型统计残留

| 文件类型 | 核心残留数量 | 说明 |
|---|---|---|
| QML 服务 (singleton) | 10 | 问题 3 的根源 |
| QML bar 组件 | 8 | 按钮/图标/菜单 |
| QML 设置页 | 5 | 与模块内重复 |
| QML 设置组件 | 7 | display/ 目录 |
| QML OSD 组件 | 6 | indicators |
| QML 其他 UI | 12 | 覆盖层/区域选择器/工具 |
| bin 脚本 (真实文件) | 15 | |
| bin 脚本 (symlink) | 8 | → omarchy-* |
| share/bin/omarchy-* 脚本 | 8 | 底层工具 |
| Python 脚本 | 4 | |
| Hyprland 配置 | 2 | hyprsunset.conf + clipboard.lua |
| polkit 规则 | 1 | |
| 独立进程目录 | 2 | apps/omd-screenshot + apps/omd-clipboard |
| **合计** | **~88 个文件/目录** | |

---

## 额外发现：apps/omd-settings/services/ 中的服务副本

`apps/omd-settings/services/` 目录中有一批服务文件的副本（与 quickshell/services/ 重复）：

| 文件 | 说明 |
|---|---|
| `apps/omd-settings/services/Battery.qml` | 电池服务副本 |
| `apps/omd-settings/services/PowerProfiles.qml` | 电源配置副本 |
| `apps/omd-settings/services/Brightness.qml` | 亮度副本 |
| `apps/omd-settings/services/Hyprsunset.qml` | 夜间模式副本 |
| `apps/omd-settings/services/KeyboardRemap.qml` | 键盘重映射副本 |
| `apps/omd-settings/services/MprisController.qml` | MPRIS 副本 |
| `apps/omd-settings/services/TrayService.qml` | 托盘副本 |
| `apps/omd-settings/services/VoiceInput.qml` | 语音副本 |

这些是 `omd-settings` 独立进程需要的服务副本（因为它是独立 Quickshell 进程，不能 import 主进程的 services）。它们的存在是合理的（独立进程需要自己的服务实例），但增加了维护负担——修改服务时需要同步多个副本。

---

## 总结

模块迁移整体完成度约 **20%**。另一个智能体主要做了：
1. 创建了 14 个模块目录 + module.json（壳）
2. 移动了部分 popup QML 和 settings QML
3. 移动了部分 bin 脚本

但**几乎所有实质性代码**（服务、bar 组件、设置页、OSD、区域选择器、独立进程、底层脚本、配置）都还在主仓库。模块目录里的大部分是空壳。

要真正完成迁移，需要将上述 ~88 个文件/目录从核心移到对应模块，同时确保：
1. 核心代码通过 ModuleLoader 动态加载模块内容
2. 模块 QML 文件能通过 popup-components 和 qmldir 正确 import
3. 禁用模块后核心功能不受影响
4. 每次移动后编译 + 运行测试