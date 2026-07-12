# Screenshot Tool Current State and Known Problems

Date: 2026-07-12 (updated)

## 需求

按下截图快捷键的瞬间，整个桌面（包括顶栏右键菜单、popup、通知等所有
OMD overlay）应该被"冻结"——截取的图像里必须包含这些 overlay，之后
桌面不再响应任何操作（除非取消截图），截图选择器出现在冻结图像之上。

## 当前表现

只要一截图，顶栏的右键菜单和 popup 就会消失，没有被冻结到截图里。

## 本轮修改尝试

尝试用 IPC 替代文件轮询来同步截图状态：

1. `bin/omd-screenshot` 启动截图进程前，先调用
   `qs ipc -p .../omd-bar call screenshot begin`，让 bar 进程立即设置
   `GlobalStates.screenshotActive = true`。
2. bar 端 `GlobalFocusGrab.onCleared` 检查 `screenshotActive`，若为 true
   则不 dismiss。
3. `BarStatusPopup`、`BarContextMenu` 的 `onDismissed` 也有同样 guard。
4. `BarDismissLayer` 在 `screenshotActive` 时不出现。
5. 截图进程退出时调用 `screenshot end` 恢复。

### 测试结果（2026-07-12 16:04）

测试环境：单显示器 HDMI-A-1，通过 IPC 手动打开 notifications popup，
然后调用 `screenshot begin`，再启动 `omd-screenshot`。

关键观测：

1. `screenshot begin` IPC 确实生效——调用后 popup 仍然可见（步骤4:
   `hyprctl layers | grep -c barstatus` = 1）。
2. **但截图进程一启动，popup 就消失了**（步骤6:
   `hyprctl layers | grep -c barstatus` = 0）。
3. `screenshotActive` guard 没能阻止 popup 消失。

### 测试方法的局限性

上面的测试通过 IPC `barPopup open` 打开 popup，**没有测试右键菜单**
（`BarContextMenu`）。右键菜单是 `PopupWindow` 类型，不是
`PanelWindow`，dismiss 机制不同。测试也没有覆盖用户实际操作流程
（手动点击顶栏按钮打开 popup/菜单，然后按截图快捷键）。

## 目前怀疑的失败点

### 1. `screenshot begin` 的时序 vs 截图进程 surface 创建

`bin/omd-screenshot` 的流程是：
```
touch /tmp/omd-screenshot-active
qs ipc call screenshot begin    ← bar 设置 screenshotActive=true
nohup qs -p omd-screenshot &    ← 截图进程启动，创建 layer-shell surface
```

`screenshot begin` 在截图进程启动之前就发了。bar 的
`GlobalStates.screenshotActive` 应该已经是 true。

但截图进程的 `RegionSelection` 是 `PanelWindow` with
`WlrLayer.Overlay` + `WlrKeyboardFocus.Exclusive`。这个 exclusive
键盘焦点可能触发了一些 bar 端没 guard 住的关闭路径。

### 2. `BarStatusPopup` 的 visible binding

```qml
visible: root.open && root.focusedScreen
```
```qml
readonly property bool open: activeType.length > 0 && !GlobalStates.screenLocked
```

如果 `screenLocked` 或 `focusedScreen` 在截图时变化，popup 可能
直接通过 binding 变 invisible，不走 `onDismissed`，所以
`screenshotActive` guard 没用。

### 3. `BarContextMenu` 是 `PopupWindow` 不是 `PanelWindow`

`PopupWindow` 的关闭机制可能不完全受 `GlobalFocusGrab` 控制。
需要确认 `PopupWindow` 在焦点丢失时是否会自动关闭。

### 4. `dismissGuard` timer 的竞争

`BarStatusPopup` 打开时 `dismissGuard` 300ms 后才
`addDismissable`。如果截图进程在这个窗口内启动，focus grab 可能
还没 active，但其他机制可能已经关掉了 popup。

### 5. `RegionSelector.qml` 的 `FileUtils is not defined` 错误

截图进程里 `RegionSelector.qml:21` 报
`ReferenceError: FileUtils is not defined`。这导致 `dismiss()` 里的
`screenshot end` IPC 调用失败，`screenshotActive` 可能永远不被
重置。但这是退出时的问题，不影响进入截图时 popup 消失的问题。

### 6. grim 快照文件不存在

截图 log 反复出现：
```
Cannot open: file:///tmp/quickshell/media/screenshot/image-HDMI-A-1-XXX.png
```

这说明 `snapshotProc` 的 grim 命令可能失败了，或者 Image 试图加载
时文件还没写完。但即使 grim 成功，如果 popup 在 grim 执行前就
消失了，快照里也不会有 popup。

### 7. 没有验证 `screenshot begin` IPC 是否真的到达 bar

`console.log` 在 `screenshot begin` handler 里没有出现在任何已知
log 文件中（`/tmp/omd-bar.log`、qslog 文件均无输出）。无法确认
IPC 调用是否真的被 bar 进程处理。Quickshell 的 `console.log`
输出目标不确定。

## 当前修改的文件

- `apps/omd-bar/shell.qml` — 新增 `screenshot` IPC handler（begin/end）
- `bin/omd-screenshot` — 启动前 `screenshot begin`，kill 时 `screenshot end`
- `quickshell/services/GlobalFocusGrab.qml` — `onCleared` 检查
  `screenshotActive`，移除了 `delayedDismiss` timer
- `quickshell/modules/bar/BarRuntime.qml` — 移除文件轮询，直接用
  `GlobalStates.screenshotActive`
- `quickshell/modules/bar/BarDismissLayer.qml` — 截图时隐藏 dismiss
  layer（`visible: ... && !screenshotActive`）
- `quickshell/modules/bar/BarContextMenu.qml` — `onDismissed` 加
  `screenshotActive` guard
- `quickshell/modules/regionSelector/RegionSelector.qml` — `dismiss()`
  时调用 `screenshot end`（但有 `FileUtils is not defined` 错误）
- `quickshell/modules/regionSelector/RegionSelection.qml` — 录制模式
  也先 `menus close`

## 需要调查的方向

1. **确认 `screenshot begin` IPC 是否真的到达 bar 进程**——用一种
   有可观察副作用的方式验证（比如在 handler 里改一个 IPC 可读的
   属性，或用一个文件 marker）。

2. **追踪截图进程启动后 popup 消失的确切路径**——在 bar 的
   `BarStatusPopup.onVisibleChanged`、`GlobalFocusGrab.onCleared`、
   `BarDismissLayer.dismiss` 等位置加 log，用一种一定能看到的
   输出方式（比如写文件而不是 `console.log`）。

3. **确认 `PopupWindow`（BarContextMenu）在焦点丢失时的行为**——
   它是否会自动关闭，不走 `GlobalFocusGrab`。

4. **考虑完全不同的架构**——比如把截图 selector 放到 bar 进程
   里，而不是独立进程。这样不需要跨进程 IPC 同步状态，bar 可以
   直接在 grim 之前冻结自己的 overlay。

5. **考虑用 Hyprland 的 `hyprctl dispatch` 来冻结 overlay**——比如
   截图时把 bar 进程的 layer 设为不可交互，但保持可见。

6. **考虑用 `grim` 的 `--include` 或直接截取整个桌面的方式**——
   在 grim 之前不做任何会改变桌面状态的操作。

