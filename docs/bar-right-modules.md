# Bar 右侧模块自定义：声明式模块列表

## 用法

在 `~/.config/quickshell/config.json` 的 `bar` 对象里配置两个属性：

```json
"bar": {
  "rightModuleSpacing": 8,
  "rightModules": [
    "sidebar",
    "util:audio",
    "util:idle",
    "util:nightlight",
    "util:mic",
    "util:colorpicker",
    "util:screenshot",
    "util:clipboard",
    "util:wifi",
    "util:bluetooth",
    "battery",
    "media",
    "systray",
    "spacer",
    "weather"
  ]
}
```

### rightModules

- **数组顺序**：第一个 = 最右，最后一个 = 最左（因为 bar 右侧用
  `layoutDirection: Qt.RightToLeft` 渲染）
- **模块在数组里 = 显示**，不在 = 隐藏。无需额外开关
- 修改后保存文件，quickshell 自动热重载

### rightModuleSpacing

- 模块之间的像素间距（整数）
- 默认 `8`
- 设 `0` = 模块紧贴
- 设 `16` = 宽松

## 可用模块

| name | 说明 |
|---|---|
| `weather` | 天气 |
| `systray` | 系统托盘 |
| `media` | 媒体控制 |
| `battery` | 电池 |
| `sidebar` | 右侧边栏按钮（音量/麦克风静音/键盘布局/通知/电源指示） |
| `spacer` | 兼容旧配置的零宽占位；不会额外撑开模块 |
| `util:bluetooth` | 蓝牙对话框 |
| `util:wifi` | WiFi 对话框 |
| `util:clipboard` | 剪贴板对话框 |
| `util:screenshot` | 截图工具 |
| `util:colorpicker` | 取色器 |
| `util:mic` | 麦克风静音切换 |
| `util:nightlight` | 夜灯切换 |
| `util:idle` | 阻止自动休眠 |
| `util:audio` | 音量对话框 |

## 示例

### 精简布局（只保留托盘、电池、电源）

```json
"rightModules": [
  "sidebar",
  "battery",
  "systray",
  "spacer"
]
```

### 紧凑无间距

```json
"rightModuleSpacing": 0,
"rightModules": [ ... ]
```

### 天气放最右边

```json
"rightModules": [
  "weather",
  "sidebar",
  "battery",
  "systray",
  "spacer"
]
```

## 实现细节

- `Config.qml`：`bar.rightModules`（`list<string>`）和
  `bar.rightModuleSpacing`（`int`，默认 8）
- `RightModuleRegistry.qml`：模块名 → Component 映射
- `BarContent.qml`：右侧 `RowLayout` 用 `Repeater` 遍历
  `rightModules`，`spacing` 绑定到 `rightModuleSpacing`
- 各模块组件在 `quickshell/modules/bar/modules/` 目录
- `SidebarIndicators.qml`：从原 BarContent 抽出的右侧边栏指示器
- `SpacerItem.qml`：零宽占位，保留旧配置里的 `"spacer"` 不会影响间距

## 原版图标参考（已废弃 — 旧 CosmicIcon/freedesktop 格式）

> ⚠️ 以下图标名称是迁移到 Nerd Font 之前的旧版本，仅供参考。当前所有 Bar 模块已迁移到 NerdIcon + NerdIconMap 系统，见下方 "NerdFont 图标系统" 章节。

所有文件位于 `quickshell/modules/bar/`。

### 左侧模块

| 模块 | 图标 | 文件 |
|------|------|------|
| `appLauncher` | 无（文本 "Applications"） | `modules/AppLauncherButton.qml` |
| `workspaces` | 无（文本 "Workspaces"） | `Workspaces.qml` |
| `activeWindow` | 动态窗口图标 / OS logo | `ActiveWindow.qml` |

### 右侧工具模块（CosmicIcon，freedesktop 格式）

| 模块 | 图标 | 文件 |
|------|------|------|
| `util:audio` | `status/audio-volume-high-symbolic`（静音: `status/audio-volume-muted-symbolic`） | `modules/AudioButton.qml` |
| `util:wifi` | `status/network-wireless-signal-good-symbolic` 等信号变体 | `modules/WifiButton.qml`（图标来自 `services/Network.qml`） |
| `util:bluetooth` | `status/bluetooth-active-symbolic`（连接）/ `devices/bluetooth-symbolic`（未连接）/ `status/bluetooth-disabled-symbolic`（禁用） | `modules/BluetoothButton.qml` |
| `util:mic` | `status/microphone-sensitivity-high-symbolic`（静音: `status/microphone-sensitivity-muted-symbolic`） | `modules/MicButton.qml` |
| `util:voice` | `status/microphone-sensitivity-high-symbolic`（颜色变化：idle=barText, active=yellow, error=red） | `modules/VoiceButton.qml` |
| `util:clipboard` | `actions/edit-paste-symbolic` | `modules/ClipboardButton.qml` |
| `util:nightlight` | `status/display-brightness-symbolic` | `modules/NightLightButton.qml` |
| `util:colorpicker` | `actions/pencil-symbolic` | `modules/ColorPickerButton.qml` |
| `util:idle` | `actions/image-redeye-symbolic`（抑制中: `actions/document-properties-symbolic`） | `modules/IdleButton.qml` |
| `util:screenshot` | `apps/accessories-screenshot-symbolic` | `modules/ScreenshotButton.qml` |

### 右侧信息模块

| 模块 | 图标 | 文件 |
|------|------|------|
| `battery` | `devices/battery-symbolic`（充电: `status/plugged-into-power-symbolic`） | `BatteryIndicator.qml` |
| `media` | `actions/media-playback-pause-symbolic`（播放中）/ `actions/media-playback-start-symbolic`（暂停）/ `apps/multimedia-audio-player-symbolic`（无播放器） | `Media.qml` |
| `sidebar` | 内含指示器：`status/audio-volume-muted-symbolic` / `devices/battery-symbolic` / `status/plugged-into-power-symbolic` | `SidebarIndicators.qml` |
| `notification` | `status/notification-symbolic`（静默: `status/notification-disabled-symbolic`） | `NotificationUnreadCount.qml` |
| `systray` | 溢出菜单：`actions/pan-down-symbolic`；托盘项使用动态图标 | `SysTray.qml` |
| `clock` | 无（纯文本时钟） | `ClockWidget.qml` |

### WiFi 信号强度图标变体（`Network.nerdIcon`）

WiFi 图标现在统一使用 `NerdIconMap.wifi`，不再区分信号强度变体（Nerd Font 没有信号强度变体码点）。

### NerdFont 图标系统

OMD 的 Bar 图标使用 **Nerd Font glyphs**，通过 `NerdIcon` 组件渲染，图标映射定义在 `NerdIconMap.qml` 单例中。

**字体**：`JetBrainsMono Nerd Font Mono`（与 Omarchy 上游 Waybar 一致）

**配置位置**：
- `quickshell/modules/common/Config.qml:87` → `iconNerd: "JetBrainsMono Nerd Font Mono"`
- `quickshell/modules/common/widgets/NerdIcon.qml` → 渲染组件
- `quickshell/modules/common/widgets/NerdIconMap.qml` → 图标名称 → Unicode 映射

### 模块图标映射

| 模块 | 图标 | NerdIconMap 属性 | 文件 |
|------|------|-----------------|------|
| `util:audio` | 🔊 / 🔇 | `volumeHigh` / `volumeOff` | `AudioButton.qml` |
| `util:bluetooth` | 🔵 | `bluetoothConnected` / `bluetooth` / `bluetoothDisabled` | `BluetoothButton.qml` |
| `util:clipboard` | 📋 | `contentPaste` | `ClipboardButton.qml` |
| `util:colorpicker` | ✏️ | `edit` | `ColorPickerButton.qml` |
| `util:idle` | 🚫 / 👁 | `block` / `visibility` | `IdleButton.qml` |
| `util:mic` | 🎤 / 🔇 | `mic` / `micOff` | `MicButton.qml` |
| `util:nightlight` | ☀️ | `brightness6` | `NightLightButton.qml` |
| `util:screenshot` | 📸 | `screenshot` | `ScreenshotButton.qml` |
| `util:voice` | 🎙 | `mic` | `VoiceButton.qml` |
| `util:wifi` | 📶 | `Network.nerdIcon`（动态） | `WifiButton.qml` |
| `sidebar` | 🔇+🔋 | `volumeOff` / `power` / `batteryFull` | `SidebarIndicators.qml` |
| `battery` | 🔋 | `power` / `batteryFull` | `BatteryIndicator.qml` |
| `media` | ♾ / ⏯ | `musicNote` / `pause` / `play` | `Media.qml` |
| `notification` | 🔔 | `notifications` / `notificationsOff` | `NotificationUnreadCount.qml` |
| `systray` | ▼ | `expandMore` | `SysTray.qml` |
| `resources` | 💾/🔄/⚙ | `memory` / `swapHoriz` / `cpu` | `Resource.qml` |

### 悬浮弹窗图标

| 弹窗 | 图标用途 | NerdIconMap 属性 |
|------|---------|-----------------|
| `BatteryHoverPopup` | 电池/充电/时间/功率/配置 | `batteryFull` / `bolt` / `schedule` / `settings` |
| `BatteryPopup` | 电池详情 | `batteryFull` / `bolt` / `schedule` / `favorite` |
| `WifiHoverPopup` | 网络状态/SSID/信号 | `Network.nerdIcon` / `wifi` |
| `BluetoothHoverPopup` | 蓝牙状态/设备 | `bluetooth` / `bluetoothConnected` / `bluetoothDisabled` |
| `ClockHoverPopup` | 时区 | `circle` |
| `MediaHoverPopup` | 播放/专辑/均衡器/循环/随机 | `pause` / `play` / `album` / `graphicEq` / `repeat` / `shuffle` |

### 公共组件图标

| 组件 | 用途 | 文件 |
|------|------|------|
| `StyledPopupValueRow` | 弹窗值行图标 | `StyledPopupValueRow.qml` |
| `StyledPopupHeaderRow` | 弹窗标题行图标 | `StyledPopupHeaderRow.qml` |
| `BarContextMenuItem` | 右键菜单项图标 | `BarContextMenuItem.qml` |

### 与 Omarchy 上游的关系

OMD 的 Bar 图标字体与 Omarchy 官方 Waybar 一致：

| 项目 | 字体 | 来源 |
|------|------|------|
| Omarchy Waybar | `JetBrainsMono Nerd Font` | `config/waybar/style.css:10` |
| OMD Quickshell Bar | `JetBrainsMono Nerd Font Mono` | `Config.qml:87` |

两者使用同一字体族（Mono 变体），图标 Unicode 码点完全兼容。
