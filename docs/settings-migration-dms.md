# DankMaterialShell → OMD Settings Center 迁移报告

## 概述

DankMaterialShell (DMS) 有一个成熟的、深度结构化的设置系统，包含 44 个设置页面、400+ 配置键、spec 驱动的数据模型、搜索索引、以及大量可复用的 widget。

我们的目标：**功能移植，样式保留 OMD 自己的 TuiStyle/COSMIC 风格**。

---

## 迁移优先级分类

### 🟢 P0 — 直接可用，低耦合，高价值

| 功能 | DMS 文件 | 说明 | 依赖 |
|------|---------|------|------|
| **Audio 设备管理** | `Modules/Settings/AudioTab.qml` + `Services/AudioService.qml` | 输出/输入设备列表、默认 sink/source 选择、设备音量、重命名/隐藏设备 | `Pipewire`（Quickshell 内置） |
| **Power Profile** | `Modals/PowerProfileModal.qml` + `Services/PowerProfileWatcher.qml` | performance/balanced/power-saver 切换 | `power-profiles-daemon` |
| **Battery 设置** | `Modules/Settings/BatteryTab.qml` + `Services/BatteryService.qml` | 电池阈值、充电限制、低电量通知 | `UPower`（Quickshell 内置） |
| **Idle/锁屏超时** | `Modules/Settings/PowerSleepTab.qml` + `Services/IdleService.qml` | AC/电池分别设超时、挂起行为、锁屏前淡出 | `hypridle` |
| **通知设置** | `Modules/Settings/NotificationsTab.qml` | 弹窗超时（低/普通/紧急）、紧凑模式、历史限制、通知规则 | `Notifications`（我们已有） |
| **OSD 设置** | `Modules/Settings/OSDTab.qml` | OSD 位置、每种 OSD 的开关 | 无特殊依赖 |
| **Locale/语言** | `Modules/Settings/LocaleTab.qml` | 语言选择 | `I18n`/`Translation`（我们已有） |
| **默认应用** | `Modules/Settings/DefaultAppsTab.qml` | 默认浏览器/终端/文件管理器 | `PortalService` |

### 🟡 P1 — 中等耦合，需要适配但价值高

| 功能 | DMS 文件 | 说明 | 适配难点 |
|------|---------|------|---------|
| **Display 配置** | `DisplayConfigTab.qml` + `DisplayConfig/` 整个目录 | 已开始移植到 `quickshell/modules/settings/display/`：显示器预览、拖拽排列、分辨率/刷新率/缩放/旋转/位置应用 | DMS 的 `WlrOutputService`/profile/Niri 后端未直接引入；OMD 当前用 `hyprctl` 适配 Hyprland |
| **Night Light/Gamma** | `GammaControlTab.qml` + `DisplayService.qml` 的 gamma 部分 | 色温调节、日出日落自动调度 | 依赖 `wlsunset` 或 hyprctl IPC，我们已有 `Hyprsunset` |
| **WiFi 管理** | `NetworkWifiTab.qml` + `WifiPasswordModal.qml` | 扫描、连接、密码输入、已保存网络、QR 分享 | 依赖 `NetworkService`，需用 NetworkManager 适配 |
| **Bluetooth 设备** | `BluetoothPairingModal.qml` + `BluetoothService.qml` | 配对流程、PIN 输入、codec 选择 | 我们已有 `BluetoothStatus`，需扩展 |
| **Autostart 管理** | `AutoStartTab.qml` | XDG autostart 目录浏览+编辑 | `DesktopService` + folderlistmodel |
| **Window Rules** | `WindowRulesTab.qml` | 每应用规则（透明度/大小/位置/workspace/float） | 需适配 Hyprland Lua window rule 语法 |
| **壁纸管理** | `WallpaperTab.qml` + `SessionData` 的 wallpaper 部分 | 预览、每显示器壁纸、light/dark 模式、填充模式、循环 | 我们已有 `omd-wallpaper`，需整合 |
| **音效设置** | `SoundsTab.qml` + `AudioService` 的 sound 部分 | 系统音效开关、每事件音效 | 需适配音效文件路径 |

### 🔴 P2 — 高耦合或 DMS 特有，不建议直接移植

| 功能 | 原因 |
|------|------|
| **主题/matugen** | DMS 用 matugen 生成主题色，我们用 Omarchy theme 系统 |
| **多 bar 编辑器 (DankBarTab)** | DMS 特有的多 bar 配置，我们 bar 配置在 config.json |
| **Dock 配置** | 我们没有 dock |
| **Desktop Widgets** | DMS 特有的桌面 widget 实例系统 |
| **插件系统** | DMS 特有 |
| **CUPS 打印机** | 94KB 代码，依赖 CUPS service |
| **用户管理** | 依赖 pkexec，风险高 |
| **Greeter/SDDM 设置** | DMS 特有的 greeter 同步 |
| **Keybind 编辑器** | 85KB 的 KeybindItem.qml，且 DMS keybind 系统与我们完全不同 |
| **Mux (tmux/zellij) 配置** | 我们已在 omd-session 里处理了 |
| **VPN 管理** | 依赖 DMS daemon |

---

## 可复用 Widget 清单

这些 widget 可以直接拿来，只需把 DMS 的 `Theme`/`DankIcon`/`StyledText` 替换为我们的 `TuiStyle`/`NerdIcon`/`StyledText`：

| Widget | DMS 路径 | 用途 | 移植难度 |
|--------|---------|------|---------|
| `SettingsCard` | `Modules/Settings/Widgets/SettingsCard.qml` | 卡片容器（标题+图标+可折叠） | 低 — 我们已有 SettingsCard |
| `SettingsToggleRow` | 同上目录 | 开关行 | 低 |
| `SettingsToggleCard` | 同上 | 带展开内容的开关卡片 | 低 |
| `SettingsSliderRow` | 同上 | 滑块行（带重置按钮+tooltip） | 低 |
| `SettingsSliderCard` | 同上 | 卡片内滑块 | 低 |
| `SettingsDropdownRow` | 同上 | 下拉行 | 低 |
| `SettingsFontDropdownRow` | 同上 | 字体下拉（枚举 Qt.fontFamilies） | 低 |
| `SettingsColorPicker` | 同上 | 颜色模式选择器 | 中 — 依赖 PopoutService |
| `SettingsButtonGroupRow` | 同上 | 按钮组行 | 低 |
| `SettingsDivider` | 同上 | 分隔线 | 低 |
| `DeviceAliasRow` | 同上 | 音频设备重命名行 | 中 — 依赖 AudioService |
| `DankSlider` | `Widgets/DankSlider.qml` | Material 滑块 | 低 |
| `DankToggle` | `Widgets/DankToggle.qml` | Material 开关 | 低 |
| `DankDropdown` | `Widgets/DankDropdown.qml` | 带搜索的下拉 | 中 |
| `ConfirmModal` | `Modals/Common/ConfirmModal.qml` | 确认对话框 | 低 |
| `FileBrowserModal` | `Modals/FileBrowser/` | 文件浏览器 | 中 — 13 个文件 |

---

## 建议的迁移路线

### 第一批（P0，低风险高回报）
1. **Audio 设备管理** — 替换我们当前简单的音量滑块，加入设备列表/选择/重命名
2. **Power Profile** — 我们已有 `PowerProfiles` service，只需加入 UI
3. **Battery 设置** — 电池阈值/充电限制
4. **Idle/锁屏超时** — AC/电池分别设超时
5. **通知设置** — 超时/历史/规则
6. **OSD 设置** — 位置/开关

### 第二批（P1，中等工作量）
7. **Display 配置** — 分辨率/刷新率/缩放
8. **Night Light** — 色温/调度
9. **WiFi 管理** — 扫描/连接/密码
10. **Bluetooth 配对** — PIN/codec
11. **Autostart** — XDG 目录编辑
12. **壁纸增强** — 每显示器/填充模式/循环

### 第三批（按需）
13. **Window Rules** — 如果需要 GUI 窗口规则编辑
14. **音效** — 如果需要系统音效
15. **默认应用** — 如果需要 GUI 选择

---

## 技术适配要点

### 样式映射
| DMS | OMD |
|-----|-----|
| `Theme.colorX` | `TuiStyle.colorX` |
| `DankIcon` | `NerdIcon` / `MaterialSymbol` |
| `StyledText` (DMS) | `StyledText` (OMD) |
| `DankFlickable` | `StyledFlickable` |
| `DankButton` | `RippleButton` |
| `DankToggle` | 需新建或移植 |
| `DankSlider` | 需新建或移植 |
| `DankDropdown` | 需新建或移植 |

### 数据模型适配
DMS 用 `SettingsData` + `SettingsSpec` + JSON 文件。我们用 `config.json` + `omarchy-*` 脚本。
- 简单设置（toggle/slider）：可以直接存到 `config.json` 的扩展字段
- 复杂设置（display profile）：需要调用 `hyprctl`/写配置文件
- 不需要移植 DMS 的 spec/migration 系统，太重了

### Service 适配
| DMS Service | OMD 对应 | 动作 |
|------------|---------|------|
| `AudioService` | `Audio` | 扩展 Audio 加入设备列表/选择 |
| `PowerProfileWatcher` | `PowerProfiles` | 已有，加 UI |
| `BatteryService` | `Battery` | 扩展加入阈值设置 |
| `IdleService` | `Idle` | 扩展加入超时配置 |
| `NotificationService` | `Notifications` | 扩展加入规则/超时 |
| `DisplayService` | 无 | 需新建，用 `hyprctl monitors`/`wlr-output` |
| `NetworkService` | `Network` | 扩展加入 WiFi 扫描/连接 |
| `BluetoothService` | `BluetoothStatus` | 扩展加入配对/codec |

---

## 总结

DMS 的设置系统比我们的成熟很多，但高度耦合 DMS 特有的架构（matugen、多 bar、插件、dms daemon）。**P0 的 8 个功能**是最值得优先移植的——它们耦合低、价值高、且我们已有对应的 service 基础。P1 的功能需要更多适配工作，但能显著提升设置中心的完整性。

建议从 **Audio 设备管理** 开始，因为它最实用、依赖最少（只需 Quickshell 的 Pipewire），且能验证整个移植流程（DMS widget → OMD 样式适配 → service 扩展 → 集成到 SettingsCenter）。
