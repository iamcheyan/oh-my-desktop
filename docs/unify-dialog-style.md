# 统一弹窗/菜单样式方案

## 目标

将所有从顶部 bar 弹出的对话框/菜单统一为同一套视觉样式，以剪贴板对话框（ClipboardDialog）为基准。这样换肤时只需改一处调色板，所有弹窗自动跟随。

## 当前架构

### 调色板中心

所有颜色和尺寸值集中在 `Appearance.tiling`（`ii/modules/common/Appearance.qml:394-413`）：

```qml
property QtObject tiling: QtObject {
    property color bg: "#1d1d1d"
    property color bgTitlebar: "#285577"
    property color bgHover: "#2a2a2a"
    property color bgActive: "#333333"
    property color bgInput: "#222222"
    property color border: "#333333"
    property color borderFocus: "#4c7899"
    property color borderCritical: "#900000"
    property color text: "#c5c8c6"
    property color textBright: "#ffffff"
    property color textDim: "#7d7d7d"
    property color accent: "#4c7899"
    property color accentBright: "#81a1c1"
    property color error: "#bf616a"
    property color success: "#a3be8c"
    property int borderWidth: 1
    property int titlebarHeight: 26
    property int dialogRadius: 6  // 已统一，所有容器引用此值
}
```

**换肤只需修改这个 QtObject 的值，所有引用 `Appearance.tiling.*` 的组件自动跟随。**

### 弹窗分三大类（当前互不一致）

#### 第一类：WindowDialog 系（已统一用 tiling 调色板）

基类：`ii/modules/common/widgets/WindowDialog.qml`
- 容器 Rectangle：`color: Appearance.tiling.bg`, `border.color: Appearance.tiling.border`, `radius: Appearance.tiling.dialogRadius`
- 子组件：`WindowDialogTitle`, `WindowDialogSeparator`, `WindowDialogButtonRow`

使用此类的弹窗：
- `ii/modules/ii/bar/ClipboardDialog.qml` — 剪贴板（基准样式）
- `ii/modules/ii/sidebarRight/wifiNetworks/WifiDialog.qml` — Wi-Fi 列表
- `ii/modules/ii/sidebarRight/bluetoothDevices/BluetoothDialog.qml` — 蓝牙列表
- `ii/modules/ii/bar/ClockWidgetPopup.qml` — 时钟弹窗
- `ii/modules/ii/bar/ResourcesPopup.qml` — 资源监控弹窗
- `ii/modules/ii/sidebarRight/nightLight/NightLightDialog.qml` — 夜间模式
- `ii/modules/ii/sidebarRight/volumeMixer/VolumeDialog.qml` — 音量混合器
- `ii/modules/ii/bar/weather/WeatherPopup.qml` — 天气弹窗

#### 第二类：StyledPopup 系（hover 弹窗，用 tiling 但 radius 硬编码为 0）

基类：`ii/modules/ii/bar/StyledPopup.qml`
- 容器 Rectangle：`color: Appearance.tiling.bg`, `border.color: Appearance.tiling.borderFocus`, `radius: 0`（硬编码！）
- 子组件：`StyledPopupHeaderRow`, `StyledPopupValueRow`

使用此类的弹窗：
- `ii/modules/ii/bar/BatteryPopup.qml` — 电池弹窗

#### 第三类：PopupWindow 系（独立容器，不用 tiling 调色板，用 Appearance.colors）

基类：Quickshell 的 `PopupWindow`（非项目内组件）
- 容器 Rectangle：`color: Appearance.colors.colLayer0`, `border.color: Appearance.colors.colLayer0Border`, `radius: Appearance.rounding.windowRounding`

使用此类的弹窗：
- `ii/modules/ii/bar/ScreenshotContextMenu.qml` — 截图菜单
- `ii/modules/ii/bar/SysTrayMenu.qml` — 系统托盘菜单

### 列表项基类

`ii/modules/common/widgets/DialogListItem.qml` — RippleButton 子类，已用 tiling 调色板：
- `colBackground: transparent`, `colBackgroundHover: Appearance.tiling.bgHover`
- `horizontalPadding: 10`, `verticalPadding: 8`, `buttonRadius: 0`, `borderWidth: 0`

使用此类的列表项：
- `ii/modules/ii/bar/ClipboardItem.qml` — 剪贴板条目（有 `keySelected` 选中高亮）
- `ii/modules/ii/sidebarRight/wifiNetworks/WifiNetworkItem.qml` — Wi-Fi 条目
- `ii/modules/ii/sidebarRight/bluetoothDevices/BluetoothDeviceItem.qml` — 蓝牙条目

### 底部按钮

两种风格并存：
- `DialogButton`（`ii/modules/common/widgets/DialogButton.qml`）— 文字按钮，Wi-Fi/蓝牙用
- 剪贴板用 `RippleButton` + `MaterialSymbol` 圆形图标按钮（关闭/翻页/清除）

## 需要做的改动

### 1. 统一容器：所有弹窗用 `Appearance.tiling` 调色板

**第二类 StyledPopup** — 把 `radius: 0` 改为 `Appearance.tiling.dialogRadius`，把 `border.color: Appearance.tiling.borderFocus` 改为 `Appearance.tiling.border`（和 WindowDialog 一致）。

文件：`ii/modules/ii/bar/StyledPopup.qml:69-74`

**第三类 PopupWindow** — 把 `Appearance.colors.colLayer0` / `Appearance.colors.colLayer0Border` / `Appearance.rounding.windowRounding` 改为 `Appearance.tiling.bg` / `Appearance.tiling.border` / `Appearance.tiling.dialogRadius`。

文件：
- `ii/modules/ii/bar/ScreenshotContextMenu.qml:66-69`
- `ii/modules/ii/bar/SysTrayMenu.qml:75-78`

### 2. 统一底部工具栏组件

新建 `ii/modules/common/widgets/WindowDialogToolbar.qml`，支持两种按钮风格（图标和文字），统一布局：

```qml
RowLayout {
    property list<QtObject> leadingActions    // 左侧按钮
    property list<QtObject> trailingActions    // 右侧按钮
    property bool paginationVisible: false     // 是否显示分页
    property int currentPage: 0
    property int totalPages: 1
    // ...
}
```

然后让 ClipboardDialog、WifiDialog、BluetoothDialog 都用这个组件。

### 3. 给 DialogListItem 加选中态

`ii/modules/common/widgets/DialogListItem.qml` 加 `property bool selected: false`，选中时显示高亮背景（和 ClipboardItem 的 `keySelected` 效果一致）。然后 ClipboardItem 改为用基类的 `selected` 属性而非自己实现。

### 4. 抽键盘导航（可选）

把 ClipboardDialog 的键盘上下/翻页/回车/滚轮逻辑抽成可复用组件或附加类型，让 Wi-Fi/蓝牙列表也能用。

## 验证方式

- 改完后 `quickshell log -p ~/.config/quickshell/ii` 确认无报错
- 逐个打开每个弹窗确认视觉一致：剪贴板、Wi-Fi、蓝牙、电池、截图菜单、托盘菜单
- 修改 `Appearance.tiling` 中某个值（如 `dialogRadius` 或 `bg`），确认所有弹窗同时变化