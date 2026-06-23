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
- 各模块组件在 `ii/modules/ii/bar/modules/` 目录
- `SidebarIndicators.qml`：从原 BarContent 抽出的右侧边栏指示器
- `SpacerItem.qml`：零宽占位，保留旧配置里的 `"spacer"` 不会影响间距
