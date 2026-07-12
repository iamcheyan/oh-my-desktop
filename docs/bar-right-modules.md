# Bar 顶部模块布局

顶部模块布局是固定代码路径，不再从 `quickshell/config.json` 读取
`leftModules` / `centerModules` / `rightModules`。当前顺序直接定义在
`quickshell/modules/bar/BarContent.qml`，这样可以避免启动时通过字符串查表和
`Loader` 动态创建组件。

## 当前顺序

左侧:

- `AppLauncherButton`
- `Workspaces`
- `ActiveWindow`

中间:

- 留空，用来避开刘海屏/居中遮挡问题

右侧:

- `SysTray`
- `AudioButton`
- `KeyboardRemapButton`
- `WifiButton`
- `ClipboardButton`
- `SessionButton`
- `DisplayButton`
- `ClockWidget`
- `SidebarIndicators`

如果以后确实要调整顶部图标位置，直接修改 `BarContent.qml`。不要重新添加
用户可配置的模块数组，除非同时恢复完整的配置 UI、迁移逻辑和错误处理。

## 尺寸配置

- `rightModuleSpacing`: 右侧模块之间的像素间距，默认 `8`
- `rightIconSlotWidth`: OMD 自绘图标模块的固定点击槽宽度，默认 `28`
- `rightIconSize`: 槽内 Nerd Font glyph 的绘制尺寸，默认 `20`

OMD 自绘顶部图标必须使用 `BarNerdIcon`：

```qml
BarNerdIcon {
    text: NerdIconMap.volumeHigh
    color: Appearance.colors.colBarText
}
```

`BarNerdIcon` 统一读取 `rightIconSize`，并用 `TextMetrics` 做轻量 optical
balance。不要在单个模块里写 `iconSize: Config.options.bar.rightIconSize + N`；
要调整体大小时改 `rightIconSize`，要调视觉校正时改 `BarNerdIcon`。

`BarBatteryIcon` 集中处理电池 glyph 选择和视觉缩放。右侧电源/电池指示只应
通过 `SidebarIndicators.qml` 使用它，不要再添加独立 `BatteryIndicator`
模块。

## 当前模块职责

| 组件 | 职责 |
|---|---|
| `AppLauncherButton.qml` | 启动应用程序启动器 |
| `Workspaces.qml` | 工作区切换 |
| `ActiveWindow.qml` | 当前窗口图标和标题 |
| `SysTray.qml` | 系统托盘和托盘溢出菜单 |
| `AudioButton.qml` | 音量弹窗、滚轮调音量、语音输入状态/右键菜单 |
| `KeyboardRemapButton.qml` | 键盘映射状态和设置入口 |
| `WifiButton.qml` | 网络设置入口和右键网络菜单 |
| `ClipboardButton.qml` | 剪贴板 UI / 双击粘贴最新内容 |
| `SessionButton.qml` | 工作区快照保存/恢复 |
| `DisplayButton.qml` | 截图入口、截图菜单、滚轮亮度 |
| `ClockWidget.qml` | 时间文本和通知未读点，点击打开通知面板 |
| `SidebarIndicators.qml` | 键盘布局、电源/电池入口 |

## 运行时共享状态

`BarRuntime.qml` 放置 bar 内部共享但不值得升格成全局 service 的状态。
目前它集中维护截图选择器是否活动，供 `BarDismissLayer.qml` 和
`BarStatusPopup.qml` 共用，避免两个组件各自每 100ms spawn `test -f`。

## 已移除的旧路径

这些组件是旧的可配置 topbar 遗留模块，当前固定布局不再加载：

- `LeftModuleRegistry.qml`
- `RightModuleRegistry.qml`
- `BatteryIndicator.qml`
- `Media.qml`
- `MediaHoverPopup.qml`
- `BluetoothHoverPopup.qml`
- `SpacerItem.qml`
- `modules/BluetoothButton.qml`
- `modules/ColorPickerButton.qml`
- `modules/IdleButton.qml`
- `modules/MicButton.qml`
- `modules/ScreenshotButton.qml`

如果以后要恢复某个按钮，应该按当前固定布局直接加入 `BarContent.qml`，同时
确认对应服务和设置入口仍然有效。
