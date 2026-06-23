# Bar 自动隐藏功能

> 状态：**已移除**
> 移除时间：2026-06-21
> 原始位置：`modules/ii/bar/Bar.qml`

---

## 功能说明

鼠标不在 bar 上时，bar 自动滑出屏幕隐藏；鼠标移上去时，bar 滑下来显示。
支持按住 Super 键时也显示 bar（延迟可配置）。

---

## 恢复步骤

### 1. 修改 `Bar.qml`

在 `PanelWindow` 内部（`id: barRoot` 之后）添加：

```qml
Timer {
    id: showBarTimer
    interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
    repeat: false
    onTriggered: {
        barRoot.superShow = true
    }
}
Connections {
    target: GlobalStates
    function onSuperDownChanged() {
        if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
        if (GlobalStates.superDown) showBarTimer.restart();
        else {
            showBarTimer.stop();
            barRoot.superShow = false;
        }
    }
}
property bool superShow: false
property bool mustShow: hoverRegion.containsMouse || superShow
```

### 2. 修改 `exclusiveZone`

将：
```qml
exclusiveZone: Appearance.sizes.baseBarHeight + (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
```
改为：
```qml
exclusiveZone: (Config?.options.bar.autoHide.enable && (!mustShow || !Config?.options.bar.autoHide.pushWindows)) ? 0 :
    Appearance.sizes.baseBarHeight + (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
```

### 3. 修改 `hoverMaskRegion` margins

将：
```qml
Item {
    id: hoverMaskRegion
    anchors.fill: barContent
}
```
改为：
```qml
Item {
    id: hoverMaskRegion
    anchors {
        fill: barContent
        topMargin: -Config.options.bar.autoHide.hoverRegionWidth
        bottomMargin: -Config.options.bar.autoHide.hoverRegionWidth
    }
}
```

### 4. 修改 `barContent` 的 `topMargin` 和动画

将：
```qml
anchors {
    right: parent.right
    left: parent.left
    top: parent.top
    bottom: undefined
    bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
    rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
}
Behavior on anchors.bottomMargin {
    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
}
```
改为：
```qml
anchors {
    right: parent.right
    left: parent.left
    top: parent.top
    bottom: undefined
    topMargin: (Config?.options.bar.autoHide.enable && !mustShow) ? -Appearance.sizes.barHeight : 0
    bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
    rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
}
Behavior on anchors.topMargin {
    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
}
Behavior on anchors.bottomMargin {
    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
}
```

### 5. 修改 bottom state 的 `bottomMargin`

将：
```qml
PropertyChanges {
    target: barContent
    anchors.topMargin: 0
    anchors.bottomMargin: 0
}
```
改为：
```qml
PropertyChanges {
    target: barContent
    anchors.topMargin: 0
    anchors.bottomMargin: (Config?.options.bar.autoHide.enable && !mustShow) ? -Appearance.sizes.barHeight : 0
}
```

### 6. Config 选项

需要在 `Config.qml` 的 `bar` 下添加：

```qml
property JsonObject autoHide: JsonObject {
    property bool enable: false
    property bool pushWindows: true
    property real hoverRegionWidth: 5
    property JsonObject showWhenPressingSuper: JsonObject {
        property bool enable: true
        property int delay: 100
    }
}
```

---

## 原理

- `mustShow` = 鼠标在 bar 上 或 按住 Super 键
- `autoHide.enable` 时，`topMargin` 设为 `-barHeight`（滑出屏幕）
- `Behavior on topMargin` 提供平滑动画
- `hoverMaskRegion` 扩大 hover 检测区域（`hoverRegionWidth`）
- `exclusiveZone` 在隐藏时不占用空间（设为 0）
