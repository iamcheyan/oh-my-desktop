# Sumika Shell 模块拆分 — 汇总报告

## 拆分的模块（14 个）

所有模块位于 `~/development/sumika-modules/<module-id>/`。

| 模块 ID | 说明 | 包含内容 |
|---|---|---|
| `file-backup` | SMB 文件共享备份 | bin, popup, settings |
| `ocr` | 截图 OCR 文字识别 | bin, popup, settings |
| `windows-vm` | Windows 虚拟机管理 | bin, settings |
| `keyboard-remap` | 键盘设备映射/重映射 | bin, services, popup, settings |
| `voice` | 语音输入 | bin, services, popup, settings, scripts |
| `input-method` | 输入法切换 | bin, services, popup, config |
| `clipboard` | 剪贴板管理 | bin, bar |
| `display` | 显示器设置 | bin, bar, popup, settings, scripts |
| `battery-power` | 电源/电池管理 | services, bar, popup, settings |
| `brightness-gamma` | 亮度/夜间模式 | services, osd, scripts |
| `mpris` | MPRIS 媒体控制 | services |
| `systray` | 系统托盘 | services, bar |
| `session` | 会话快照 | services(空), popup |
| `screenshot` | 截图 | bin, utils |

## 每个模块的文件清单

### file-backup
```
bin/omd-backup
bin/omd-settings-backup-tui
bin/omd-launch-settings-backup-tui
popup/BackupPopupSection.qml
settings/BackupPage.qml
module.json, qmldir
```

### ocr
```
bin/omd-ocr
bin/omd-settings-ocr
bin/omd-settings-ocr-tui
bin/omd-launch-settings-ocr-tui
popup/OCRPopupSection.qml
settings/OCRPage.qml
module.json, qmldir
```

### windows-vm
```
bin/omd-settings-windows-vm
bin/omd-settings-vm-tui
settings/WindowsVmPage.qml
popup/WindowsVmPopup.qml
module.json, qmldir
```

### keyboard-remap
```
bin/omd-settings-keyboard, omd-settings-keyboard-tui, omd-launch-settings-keyboard-tui
bin/omarchy-keyboard-{apply,list,render,setup}
services/KeyboardRemap.qml (non-singleton)
popup/KeyboardPopup.qml
settings/KeyboardRemapPage.qml
settings/KeyboardEditorOverlay.qml
module.json, qmldir
```

### voice
```
bin/omd-settings-voice, omd-settings-voice-tui, omd-edit-voice-bindings
bin/omarchy-voice-{download,record,setup,transcribe}
services/VoiceInput.qml (non-singleton)
popup/VoicePopup.qml
settings/VoicePage.qml
scripts/voice-bind-tui, key-test, key-test-launcher, key_capture_clipboard.py, key_evdev_names.py
module.json, qmldir
```

### input-method
```
bin/omd-input-method
services/InputMethod.qml (non-singleton)
popup/InputMethodPopup.qml
config/schemas.json
module.json, qmldir
```

### clipboard
```
bin/omd-clipboard, omd-clipboard-store, omd-kitty-smart-paste
bar/ClipboardButton.qml
module.json, qmldir
```

### display
```
bin/omd-display-config, omd-ddc-detect
bar/DisplayButton.qml
popup/DisplayPopup.qml
settings/DisplayConfigState.qml, DisplayPage.qml, MonitorCanvas.qml, etc.
scripts/omarchy-hyprland-monitor-*, omarchy-hw-external-monitors
module.json, qmldir
```

### battery-power
```
services/Battery.qml (non-singleton)
services/PowerProfiles.qml (non-singleton)
popup/BatteryPopup.qml
settings/PowerPage.qml
module.json, qmldir
```

### brightness-gamma
```
services/Brightness.qml (non-singleton)
services/Hyprsunset.qml (non-singleton)
osd/BrightnessIndicator.qml, GammaIndicator.qml
scripts/omarchy-brightness-*
hyprsunset.conf
module.json, qmldir
```

### mpris
```
services/MprisController.qml (non-singleton)
services/TrackArt.qml (non-singleton)
module.json, qmldir
```

### systray
```
services/TrayService.qml (non-singleton)
bar/SysTray.qml, SysTrayItem.qml, SysTrayMenu.qml, SysTrayMenuEntry.qml
module.json, qmldir
```

### session
```
popup/SessionPopup.qml
module.json, qmldir
```

### screenshot
```
bin/omd-screenshot
ScreenshotContextMenu.qml
utils/ScreenshotAction.qml
module.json, qmldir
```

## 核心保留文件

以下文件保留在仓库核心中，未被模块化：

### Bar 核心
- `BarContent.qml` — 核心按钮（Audio, Wifi, Clock, SidebarIndicators）+ 模块 Repeater
- `BarStatusPopup.qml` — 核心 sections（wifi, bluetooth, audio, notifications, xkb）+ 模块 Repeater
- `AudioButton.qml`, `WifiButton.qml`, `ClockWidget.qml`, `SidebarIndicators.qml`

### 设置框架
- `SettingsDialog.qml` — 含模块 Repeater
- `pages/OverviewPage.qml` — 仅保留 Themes（其余已移除）
- `pages/AppearancePage.qml`, `SoundPage.qml`, `SystemPage.qml`, `NetworkPage.qml`, `BluetoothPage.qml`

### 核心服务（仍然作为单例）
- `Audio.qml`, `HyprlandData.qml`, `Network.qml`, `Notifications.qml`
- `Wallpaper.qml`, `GlobalStates.qml`, `Config.qml`, `Appearance.qml`, `Directories.qml`
- `Session.qml`（保留在 `modules/common/functions/`，供 battery 等模块引用）

### 其他核心
- `ModuleLoader.qml`（模块加载器）
- `overview/`, `lock/`, `notificationPopup/`, `schedulePopup/`, `polkit/`
- `onScreenDisplay/` 框架（InputMethodIndicator, VolumeIndicator 保留）

## 已知问题 / 未完成项

1. **Module keyd 配置未迁移**：`keyboard-remap/profiles.json`（原在仓库根目录）在 git stash 冲突后已清理。模块的原始服务副本仍保留为单例以确保兼容性。
2. **SessionButton 和 ScreenshotContextMenu 残留**：`bar/modules/SessionButton.qml` 和 `bar/modules/ScreenshotContextMenu.qml` 已在最终清理中删除（已复制到对应模块）。
3. **Services 仍保留在 monolith 中作为单例**：对于 battery-power、voice、input-method 等模块，服务副本以非单例形式存在于模块目录中，但 monolith 中的原始单例服务文件仍保留以供向后兼容。这是由于 QML 引擎对带连字符的导入路径的限制。
4. **InputMethodButton.qml 保留在核心**：该按钮同时处理输入法和语音控制，未拆分（两个功能共享 UI 组件）。
5. **session 模块 services/ 为空**：Session.qml 保留在 `modules/common/functions/` 中，因为 battery 等其他模块仍引用它作为单例。

## 禁用模块的方法

在用户配置 `~/.config/sumika-shell/quickshell/config.json` 中：
```json
{
  "modules": {
    "disabled": ["ocr", "voice"]
  }
}
```
禁用后，模块不会被扫描，其 bar 按钮、弹窗 section 和设置页都不会出现。

## 模块注册表

启动时由 `quickshell/scripts/quickshell` 扫描 `~/development/sumika-modules/*/module.json`，生成 `/tmp/sumika-module-registry.json`。ModuleLoader 读取该文件，动态加载模块的 bar 按钮、弹窗 sections 和设置页。

## 验证结果

```
omd-bar:       Configuration Loaded
omd-overview:  Configuration Loaded
omd-applauncher: Configuration Loaded
omd-clipboard: Configuration Loaded
```

所有 4 个 Quickshell 应用编译通过，显示了 "Configuration Loaded"。
