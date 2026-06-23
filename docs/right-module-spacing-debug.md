# 右侧模块间距问题排查

## 目标

设置 `rightModuleSpacing: 0` 后，右侧所有图标应完全紧贴，无任何间距。

## 实现层级

间距由三层控制，三层全部改为绑定 `rightModuleSpacing` 后理论应生效：

```
模块之间 (RowLayout.spacing)
  ↓
模块内部 (各模块的 RowLayout/GridLayout.spacing)
  ↓
按钮自身 (CircleUtilButton.implicitWidth)
```

### 第一层：模块之间 — BarContent.qml:162 ✅

```qml
RowLayout {
    spacing: Config.options.bar.rightModuleSpacing
    layoutDirection: Qt.RightToLeft
    Repeater { model: Config.options.bar.rightModules }
}
```

`rightModuleSpacing: 0` → 模块间 spacing = 0。**已确认绑定正确。**

2026-06-22 实际修复补充：仅设置 `spacing: 0` 不够。原实现里右侧
`RowLayout` 使用 `anchors.fill: parent`，它始终占满从中间时钟右侧到屏幕
右侧的整段宽度。这样即使模块间 spacing 为 0，布局容器仍有一大段空白可
分配。

中间方案曾经写成：

```qml
anchors {
    top: parent.top
    bottom: parent.bottom
    right: parent.right
}
width: Config.options.bar.rightModuleSpacing === 0 ? implicitWidth : parent.width
```

这个仍然不对，因为 `rightModuleSpacing: 1` 会立刻切回 `parent.width`。最终修正为：

```qml
width: implicitWidth
```

这样 `rightModuleSpacing` 才是连续的像素间距：`0/1/2/3/4` 会逐步变化，而
不会在 `0 → 1` 时突然切回整段右侧宽度。

### 第二层：模块内部 — 各模块 ✅

| 模块 | 属性 | 绑定状态 |
|---|---|---|
| SysTray.qml:73 | GridLayout.columnSpacing | ✅ → rightModuleSpacing |
| BatteryIndicator.qml:36 | RowLayout.spacing | ✅ → rightModuleSpacing |
| Media.qml:58 | RowLayout.spacing | ✅ → rightModuleSpacing |
| SidebarIndicators.qml:40 | RowLayout.spacing | ✅ → rightModuleSpacing |
| SidebarIndicators.qml:45/58/70/76 | Layout.rightMargin | ✅ → realSpacing (same value) |
| Media.qml:99 | Layout.rightMargin | ✅ → rowLayout.spacing |
| WeatherBar.qml:13 | implicitWidth | ✅ → `+ rightModuleSpacing` (0 时无影响) |

### 第三层：按钮自身 — CircleUtilButton.qml:13-14 ✅

```
implicitWidth: Math.max(content.implicitWidth, 20)
implicitHeight: Math.max(content.implicitHeight, 20)
padding: 0
```

原先 `implicitWidth: implicitHeight`（被 fillHeight 撑到 ~36px），现改为 20px。

---

## 为什么效果「还是没变化」？

### 可能性 1：Config 热重载未正确读取 0

`rightModuleSpacing` 在 Config.qml 中默认值为 `8`：

```qml
property int rightModuleSpacing: 8 // 默认
```

当 JSON 文件写入 `"rightModuleSpacing": 0` 时：

- `0` 是 falsy 值，但 JsonAdapter 是直接赋值，不应受 falsy 影响
- **最大嫌疑**：FileView 热重载时，QML 绑定的重新求值顺序可能导致 0 被当作「未设置」而退化为默认值 8

**验证方法**：
1. 显式在 Config.qml 将默认值改为 `0` 并重启 quickshell（跳过 JSON 加载），观察间距是否立即消失
2. 或者在 BarContent.qml 写死 `spacing: 0` 重启，看效果

**如果写死 0 有效 → 问题在 Config 热重载机制**（重点排查方向）

### 可能性 2：Loader 在 RowLayout 中的宽度

Repeater 的 delegate 是 Loader：

```qml
delegate: Loader {
    Layout.fillHeight: true
    sourceComponent: ...
}
```

Loader 没有设置 `Layout.fillWidth` 或 `Layout.preferredWidth`。在 RowLayout（RTL）中，Loader 的宽度由内部组件 implicitWidth 决定。如果 Loader 本身的 implicitWidth 计算不准确，可能导致布局器给它分配额外宽度。

**验证**：给 Loader 加 `Layout.minimumWidth: 20` 或 `implicitWidth: 20` 看是否有变化。

### 可能性 3：SpacerItem 永远占满剩余空间 ✅ 已确认并修复

`SpacerItem.qml`：

```qml
Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
}
```

无论 `spacing` 设为多少，spacer 总会吃掉所有剩余宽度。因为 spacer 排在模块列表倒数第二位（介于 systray 和 weather 之间），_systray 和 weather 之间的间距就是 spacer 的宽度_，不归 spacing 控制。

原配置数组：

```
["sidebar", "util:audio", ..., "systray", "spacer", "weather"]
↑最右（RTL 首位）                   ↑最左（RTL 末位）
```

修复：

```qml
Item {
    Layout.fillHeight: true
    implicitWidth: 0
    implicitHeight: 0
}
```

这样：

- `spacer` 保留在旧配置里也不会撑开天气和托盘/工具图标
- 实际模块间距只由 `rightModuleSpacing` 控制

### 可能性 4：WeatherBar「自带」间距

WeatherBar.qml:13：

```qml
implicitWidth: rowLayout.implicitWidth + Config.options.bar.rightModuleSpacing
```

这个 `+ rightModuleSpacing` 的来源历史：WeatherBar 是最后一个模块（最左端），原开发者发现其 `rowLayout.implicitWidth` 比实际内容多出一截（可能因为内部 RowLayout 默认 spacing 非 0 或文本 elide 策略），用这个加法做补偿。但 `spacing: 0` 时这行加的是 0，不应造成问题。**如果有隐含问题，是 `rowLayout.implicitWidth` 本身偏高，不在我们的控制范围内。**

### 可能性 5：RippleButton 继承了 QtQuick.Controls.Button 的默认属性

RippleButton 继承自 `Button`，有默认的 `spacing`（icon 和 text 之间）、`padding`（`6` by default）、`implicitContentWidth` / `implicitContentHeight`。虽然 CircleUtilButton 设置了 `padding: 0` 和 `contentItem: content`，但 Button 的内部布局可能还有额外的宽度计算（如 `background` 的 `implicitHeight: 0` 但实际最小尺寸）。**但 `padding: 0` 理论上应消除所有间距。**

---

## 系统性排查方法（操作步骤）

1. **断开 Config——写死测试**：将 BarContent.qml 第 162 行改为 `spacing: 0`，重启 quickshell
   - 若图标紧贴 → 确认问题在 Config 热重载
   - 若还有间隙 → 问题不在模块间 spacing

2. **删除 spacer**：从 config.json 的 rightModules 中去掉 `"spacer"` 重启
   - 若间隙消失 → 问题就是 spacer

3. **缩小排查范围**：把 rightModules 临时缩短为 `["sidebar", "battery", "media"]`，排除其他模块干扰

4. **终极排查**：给所有 Loader 加 `Layout.minimumWidth: 20`，排除 Loader 宽度计算问题

5. **强制重启而非热重载**：
   ```bash
   killall quickshell
   ~/.config/hypr/scripts/quickshell &
   ```

6. 如果以上全部无效，可能是 Qt Quick 的 RowLayout 在 `spacing: 0` 时仍保留最小间距（罕见 bug），可考虑改用 `Positioner` 或手动 x 坐标定位。

---

## 实际结论

| 排查结果 | 根因 | 解决方案 |
|---|---|---|
| `rightModuleSpacing: 1` 后突然变大 | 右侧 `RowLayout` 在 spacing > 0 时又使用 `parent.width` | RowLayout 始终使用 `implicitWidth` |
| `rightModuleSpacing: 0` 后仍有大间距 | `spacer` 使用 `Layout.fillWidth: true` 吃掉剩余宽度 | `spacer` 变成零宽占位 |
| 模块之间的普通间距 | `BarContent.qml` 的 `RowLayout.spacing` | 已绑定 `Config.options.bar.rightModuleSpacing` |
| 托盘内部间距 | `SysTray.qml` 的 `GridLayout.columnSpacing` | 已绑定 `Config.options.bar.rightModuleSpacing` |

现在不需要从 `rightModules` 里删除 `"spacer"`。保留它即可；它不会额外影响间距。
