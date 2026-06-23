# Tiling UI Design System

目标：把 shell 的界面统一成 i3 / sway / dwm 一类平铺窗口管理器的视觉语言。界面应该像窗口管理器本身的一部分，而不是 Material 控制中心、移动端卡片面板或桌面小组件集合。

这份规范优先用于后续重做以下区域：

- `modules/ii/bar/`
- `modules/ii/overview/`
- `modules/ii/sidebarRight/`
- `modules/common/widgets/Notification*.qml`
- `modules/ii/notificationPopup/`
- `modules/ii/sessionScreen/`
- `modules/ii/polkit/`
- `modules/ii/regionSelector/`
- `modules/ii/bar/ClipboardDialog.qml`

---

## 1. 设计方向

### 关键词

- tiled
- rectangular
- compact
- keyboard-first
- information-dense
- border-driven
- low animation
- no decoration without state

### 基本判断

一个组件如果看起来像「窗口管理器里的一个容器」，它就是对的；如果看起来像「手机系统控制中心里的卡片」，它就是错的。

### 应该像什么

- i3/sway 的 titlebar、边框和 status bar
- bmenu/fuzzel/dmenu 一类的紧凑列表
- TWM 常见的 sharp rectangle panel
- tmux / terminal UI 的分区、焦点边框、状态条

### 不应该像什么

- 大圆角卡片
- 毛玻璃拟物面板
- 漂浮 FAB
- 大面积渐变
- 大阴影
- 弹性动画
- 过度 Material You 的 chip / pill / card

---

## 2. 全局视觉 Token

当前代码已经有 `Appearance.tiling`，后续新组件优先使用它，而不是直接使用 Material 色板。

```qml
Appearance.tiling.bg
Appearance.tiling.bgTitlebar
Appearance.tiling.bgHover
Appearance.tiling.bgActive
Appearance.tiling.bgInput
Appearance.tiling.border
Appearance.tiling.borderFocus
Appearance.tiling.borderCritical
Appearance.tiling.text
Appearance.tiling.textBright
Appearance.tiling.textDim
Appearance.tiling.accent
Appearance.tiling.accentBright
Appearance.tiling.error
Appearance.tiling.success
Appearance.tiling.borderWidth
Appearance.tiling.titlebarHeight
```

### 色彩规则

| 用途 | 推荐 |
|------|------|
| 主背景 | `Appearance.tiling.bg` |
| 普通容器 | `Appearance.tiling.bg` |
| hover | `Appearance.tiling.bgHover` |
| active / selected | `Appearance.tiling.bgActive` |
| 输入框 | `Appearance.tiling.bgInput` |
| 普通边框 | `Appearance.tiling.border` |
| 焦点边框 | `Appearance.tiling.borderFocus` |
| 严重/危险 | `Appearance.tiling.borderCritical` / `Appearance.tiling.error` |
| 正常文字 | `Appearance.tiling.text` |
| 强调文字 | `Appearance.tiling.textBright` |
| 次级文字 | `Appearance.tiling.textDim` |

### 色彩限制

- 不使用主题随机色做大面积背景。
- `accent` 只用于焦点、选中、进度、重要状态，不作为装饰色。
- 警告/错误只用在真实错误状态，不用来做普通强调。
- 背景层级最多三层：base、hover、active。不要堆叠五六层灰色。

---

## 3. 几何规则

### 圆角

- 默认：`radius: 0`
- 输入框、按钮、列表项：`radius: 0`
- 面板、弹窗、通知：`radius: 0`
- 只有保留旧组件期间允许局部过渡，但新代码不得继续增加圆角。

### 边框

- 容器边框：`Appearance.tiling.borderWidth`
- 焦点容器边框：`Appearance.tiling.borderFocus`
- 危险状态边框：`Appearance.tiling.borderCritical`
- 用边框表达结构和焦点，不用阴影表达层级。

### 阴影

- 默认不使用阴影。
- 弹窗可以只靠边框、背景遮罩和 layer 顺序表达浮层。
- `StyledRectangularShadow` 仅作为过渡遗留；新组件不要引入新 shadow。

### 间距

推荐使用 4px 网格：

| 用途 | 值 |
|------|----|
| 紧凑 gap | 4 |
| 常规 gap | 6 |
| 分组 gap | 8 |
| 面板内边距 | 8 |
| 大面板内边距 | 10-12 |
| 列表项垂直 padding | 6-8 |
| 图标和文本间距 | 6-8 |

不要使用 20px 以上的大间距，除非是全屏 overview 里的工作区缩略图间距。

---

## 4. 字体和文本

### 字体尺寸

| 场景 | 推荐 |
|------|------|
| bar 文本 | `Appearance.font.pixelSize.small` 或 `normal` |
| 列表项主标题 | `normal` |
| 列表项次级信息 | `small` / `smaller` |
| 面板标题 | `large` / `larger` |
| 空状态 | `normal`，不要 hero size |

### 文本规则

- 标题短，信息靠结构表达，不靠说明文字堆叠。
- 列表项必须支持 elide。
- 时间、百分比、工作区编号优先使用等宽数字字体。
- 不用大段欢迎语、解释性文案和营销式标题。

---

## 5. 动效

当前 `Appearance.animation` 基本已经归零，符合 TWM 方向。

规则：

- 状态切换应立即响应。
- hover/active 可以无动画。
- 展开/收起可以使用极短高度变化，但不要弹性、回弹、缩放。
- 不使用 ripple。
- 不使用 Material shape morph。

如果组件继承 `RippleButton`，应设置：

```qml
rippleEnabled: false
buttonRadius: 0
```

---

## 6. 核心组件规范

### 面板 Panel

面板是一个有边框的矩形窗口。

必须：

- 背景：`Appearance.tiling.bg`
- 边框：`Appearance.tiling.borderWidth`
- 圆角：0
- 内边距：8 或 10
- 可选 titlebar，高度 `Appearance.tiling.titlebarHeight`

避免：

- 面板里再放大卡片
- 大圆角浮层
- 装饰性图形
- 模糊背景

### Titlebar

用于弹窗、控制面板、系统对话框。

结构：

- 左侧：标题或当前对象名
- 中间：可选状态
- 右侧：关闭、刷新、清空等 icon button

样式：

- 高度：`Appearance.tiling.titlebarHeight`
- 背景：`Appearance.tiling.bgTitlebar` 或 `Appearance.tiling.bgActive`
- 文字：`Appearance.tiling.textBright`
- 边框底线：`Appearance.tiling.border`

### Button

按钮是矩形命令，不是 pill。

状态：

- default：透明或 `bg`
- hover：`bgHover`
- active：`bgActive`
- focused：1px `borderFocus`
- disabled：`textDim`

文本按钮只用于明确命令。工具动作优先使用 icon button。

### Icon Button

用于 bar、titlebar、工具栏。

尺寸：

- bar：24-28px
- dialog：28-32px

规则：

- 图标居中。
- 不使用圆形背景。
- hover 时显示矩形背景。
- 必须有 tooltip，除非图标含义非常明确。

### List Item

用于 Wi-Fi、蓝牙、通知、剪贴板、音频设备。

布局：

```text
[icon]  primary text                         trailing status
        secondary text / detail              optional action
```

规则：

- 高度稳定，不因 hover 改变。
- hover 使用 `bgHover`。
- active 使用 `bgActive` + 左侧 2px accent bar 或边框。
- 不用分离卡片；列表项之间用 1px separator 或 0 spacing。
- 右侧操作按钮只在 hover 或 selected 时出现，避免噪声。

### Input

用于 Wi-Fi 密码、搜索、过滤。

规则：

- 背景：`bgInput`
- 边框：普通 `border`，focus `borderFocus`
- 圆角：0
- 高度：30-34
- placeholder 使用 `textDim`

### Progress

用于音量、亮度、电量、资源、模型额度。

规则：

- 轨道矩形，圆角 0。
- 填充使用 `accent` / `success` / `error`。
- 高度 4-8。
- 文本不要压在进度条上，除非空间非常明确。

---

## 7. 模块级规范

### Bar

Bar 是状态条，不是 dock。

规则：

- 高度保持 32px 左右。
- 模块之间用 1px separator 或小 gap。
- 当前 workspace 用 `bgTitlebar` / `borderFocus` 强调。
- 非当前 workspace 用普通文字，不做 pill。
- 图标按钮使用矩形 hover，不使用圆形按钮。
- 弹出内容从 bar 打开时，应是矩形 panel，和 bar 对齐或居中，但不能像移动端控制中心。

### Overview

Overview 是工作区网格，不是启动器。

规则：

- 工作区卡片保持直角或极小圆角，优先直角。
- 每个 workspace 必须显示 `monitor · id`。
- 当前焦点 workspace 用 2px `borderFocus`。
- 拖拽目标 workspace 用 `accent` 边框或背景。
- 新建 workspace 只出现一个尾部加号，不能无限制造空白 workspace。
- 窗口缩略图应使用真实窗口比例和边框，不使用装饰卡片。

### Sidebar / Control Panel

右侧栏应变成「系统控制面板」，不是大卡片堆叠。

结构建议：

```text
titlebar
quick toggles grid
section: network
section: bluetooth
section: audio
section: notifications
status bar / actions
```

规则：

- 每个 section 是带标题的矩形区域。
- section 内是紧凑列表。
- toggle 是矩形按钮，选中态用左边框或背景，不用圆角 pill。
- 大面积空白减少，信息密度提高。

### Wi-Fi Dialog

当前 Wi-Fi 弹窗可以作为第一批改造对象。

目标结构：

```text
Connect to Wi-Fi                         [refresh] [close]
----------------------------------------------------------
SSID                         Security     Strength  State
Home_5G                      WPA2         86%       active
Coffee                       open         42%
----------------------------------------------------------
[Details]                                      [Done]
```

规则：

- 从「列表卡片」改成「表格/列表」。
- active 网络用 `borderFocus` 或 `accent` 左条。
- 密码输入内联展开，但保持矩形边界。
- 信号强度可以显示图标 + 百分比，不要只靠图标。

### Notifications

通知应像 log/event list，而不是聊天卡片。

结构：

```text
[app icon] summary                         time [actions]
           body preview
```

规则：

- 未展开：单行或两行。
- 展开：正文、图片、actions 在同一个矩形内。
- critical：左边 2px `error` 或边框 `borderCritical`。
- grouped notifications 使用分组 header，不用大圆角嵌套卡片。
- 底部操作条保持 status bar 风格。

### Clipboard

剪贴板是历史列表。

规则：

- 文本项：等宽预览 + 来源/时间。
- 图片项：小缩略图 + 尺寸/类型。
- 操作：copy / paste / delete 右侧 icon button。
- 不使用大缩略卡片。

### Session / Power Menu

规则：

- 网格按钮可以保留，但每个按钮是矩形。
- 高风险操作使用 `error` 边框或文字。
- 默认焦点明确。

### Polkit

规则：

- 必须严肃、低装饰。
- 标题栏显示认证目标。
- 密码输入清晰聚焦。
- 错误信息使用 `error`。

### OSD

规则：

- 小型矩形条。
- 用进度条和数值表达。
- 不使用大圆角胶囊。

---

## 8. 新增组件时的检查清单

新增 UI 前先过这张表：

- 是否使用 `Appearance.tiling.*`？
- 是否 `radius: 0`？
- 是否有明确边框？
- hover/active/focus 三态是否可区分？
- 键盘焦点是否可见？
- 列表项高度是否稳定？
- 文本是否会 elide 或 wrap？
- 是否避免了卡片套卡片？
- 是否避免了 ripple、shadow、blur、渐变？
- 是否能用 4px 网格解释间距？
- 是否优先复用了公共组件？

如果有一项答不上来，先不要落地。

---

## 9. 迁移计划

### Phase 1: Token 和基础组件

- 统一 `DialogButton`
- 统一 `DialogListItem`
- 新增或整理 `TilingPanel` / `TilingTitleBar` / `TilingIconButton`
- 让新组件全部使用 `Appearance.tiling`

### Phase 2: 高使用频率界面

- Wi-Fi dialog
- Bluetooth dialog
- Clipboard dialog
- Notification list / popup

### Phase 3: 大面板

- SidebarRightContent
- SessionScreen
- Polkit
- RegionSelector toolbar

### Phase 4: 清理旧 Material 残留

- 减少 `MaterialShape`
- 减少 `FloatingActionButton`
- 减少 `NavigationRail`
- 删除只服务旧视觉的 wrapper

---

## 10. 当前仓库观察

当前代码已经有利于 TWM 风格的部分：

- `Appearance.rounding.*` 基本为 0。
- `Appearance.animation.*` 基本为 0。
- `Appearance.tiling` 已经定义了完整基础色。
- `WindowDialog` / `DialogButton` / `DialogListItem` 已经开始转向直角矩形。
- `NotificationItem` 已经部分使用 `Appearance.tiling`。

主要问题：

- 仍有很多 Material 命名和 Material 视觉残留。
- 控制中心、Wi-Fi、蓝牙、通知缺少统一 titlebar/list/table 规范。
- 部分按钮仍然继承旧 ripple/button 模型。
- 信息密度和边框层级不统一。

后续改造不应该零散调颜色，而应该先统一公共组件，再逐个模块替换。
