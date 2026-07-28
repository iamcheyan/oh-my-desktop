# TUI 统一化重构任务书

## 背景

Sumika Shell 项目有一个共享 TUI 核心库 `bin/sumika_tui_framework.py`，所有 curses TUI 程序都应该从中 import 并使用其统一的事件循环、渲染原语和布局工具。

目前 8 个 TUI 程序中，6 个已经迁移到统一的 `S.run_tui_loop` 架构，剩余 2 个（wifi-tui 和 bluetooth-tui）仍在使用自定义事件循环。本任务将这两个 TUI 迁移到统一架构。

## 当前状态

### 已统一的 TUI（不要动这些）

以下 6 个 TUI 已经使用 `S.run_tui_loop`，作为参考实现：

| TUI | 位置 | 架构 |
|---|---|---|
| wallpaper-tui | `quickshell/modules/settings/bin/sumika-settings-wallpaper-tui` | `S.run_tui_loop` + 单栏堆叠 |
| ocr-tui | `~/.local/share/sumika-shell/extensions/screenshot/bin/sumika-ocr-tui` | `S.run_tui_loop` + `refresh_callback` + 单栏堆叠 |
| voice-tui | `~/.local/share/sumika-shell/extensions/voice/bin/sumika-settings-voice-tui` | `S.run_tui_loop` + `S.Layout` 双栏 |
| vm-tui | `~/.local/share/sumika-shell/extensions/windows-vm/bin/sumika-settings-vm-tui` | `S.run_tui_loop` + `S.Layout` 双栏 |
| keyboard-tui | `~/.local/share/sumika-shell/extensions/keyboard-remap/bin/sumika-settings-keyboard-tui` | `S.run_tui_loop` + `S.Layout` 双栏 |
| backup-tui | `~/.local/share/sumika-shell/extensions/file-backup/bin/sumika-settings-backup-tui` | `S.run_tui_loop` + `S.Layout` 双栏 |

### 需要迁移的 TUI

| TUI | 位置 | 行数 | 问题 |
|---|---|---|---|
| wifi-tui | `quickshell/modules/wifi/bin/sumika-wifi-tui` | ~1023 | 自定义事件循环、无鼠标支持、已用 `S.require_terminal_size`（尺寸检查已统一） |
| bluetooth-tui | `quickshell/modules/wifi/bin/sumika-bluetooth-tui` | ~1344 | 自定义事件循环、无鼠标支持、已用 `S.require_terminal_size`（尺寸检查已统一） |

## 核心库 API 参考

`bin/sumika_tui_framework.py` 提供的关键 API（import as `S`）：

### 事件循环

```python
S.run_tui_loop(stdscr, model, view, handle_key, *,
               poll_timeout=200,        # 轮询间隔(ms)，可以是 callable(model)->int
               refresh_interval=None,   # 定时刷新间隔(秒)，可以是 callable
               refresh_callback=None,   # 定时回调函数 callback(model)
               show_cursor=False)
```

- 自动初始化 curses（颜色、鼠标、ESC 延迟、光标）
- 每帧检查 `model.dirty`，为 True 时调 `view(stdscr, model)` 然后清零
- 轮询 `stdscr.getch()`，有按键时调 `handle_key(stdscr, model, key)`，返回 Falsey 退出
- 每帧调 `S.drain_callbacks()` 处理 `S.run_cmd_bg` 的异步回调
- 可选 `refresh_callback` 定时调，用于检查后台线程完成状态
- 退出时自动 `disable_mouse()`

### Model 基类

```python
class S.StatusModel:
    dirty = True
    busy = False
    refreshing = False
    err = ""
    message = ""
    status = {}       # parse_kv 的结果

    def val(self, key, default="")  # 从 status 字典取值
    def refresh()                   # 子类覆盖
```

### 异步命令

```python
S.run_cmd_bg(cmd, *args, callback=None)  # 后台执行命令，完成后回调放入队列
# 回调签名: callback(lines: list[str], err: str)
# drain_callbacks() 在 run_tui_loop 每帧自动调用
```

### 渲染原语

```python
S.draw_hero(stdscr, hero_tuple)           # 顶部标题栏
S.hero_line(title, subtitle, tone, busy, msg, status_text)  # 构造 hero 数据
S.draw_focus_border(stdscr, focused, y, x, h, w, title)     # 带焦点的边框
S.draw_border(stdscr, y, x, h, w, title)                    # 普通边框
S.draw_thick_border(stdscr, y, x, h, w, title)              # 粗边框
S.draw_lines_in_area(stdscr, y, x, h, w, tagged_lines)      # 在区域内画 tagged 行
S.draw_help_bar(stdscr, generic_items, tool_items)          # 底部帮助栏
S.draw_log_in_area(stdscr, y, x, h, w, log_lines, empty_text)  # 日志区域
S.finish_frame(stdscr)                   # 刷新帧（替代 stdscr.refresh()）
S.require_terminal_size(stdscr, w, h)    # 尺寸检查，太小时画提示并返回 False
```

### 布局

```python
ly = S.Layout(stdscr)
ly.left_w = 34           # 左栏宽度（默认 34）
ly.right_min = 28        # 右栏最小宽度
ly.split_threshold = 80  # 双栏触发宽度
ly.force_single = False  # 强制单栏
ly.compute()             # 计算布局
# 结果: ly.left_x/y/h/w, ly.right_x/y/h/w, ly.show_right
ly.draw_panel("left", "Title", tagged_lines, focus=True)
ly.draw_panel("right", "Title", tagged_lines, focus=False)
ly.draw_help(stdscr, generic, tool)
ly.inner_rect("left")  # -> (y, x, h, w) 文本区域
```

### 行构造器

```python
S.section_title(text)              # 分区标题行 -> ("section", text)
S.action_line(key, label, enabled) # 快捷键操作行
S.cycle_line(label, value, key, focused)  # 可循环值行
S.toggle_line(checked, label, focused, trailing)  # 勾选行 -> (tag, text)
S.kv_line(key, value)              # 键值行
```

### 辅助

```python
S.safe_addstr(stdscr, y, x, text, attr=0)  # 安全写入（处理边界）
S.truncate(text, width)                     # 按显示宽度截断
S.parse_kv(lines)                           # key=value 行解析为字典
S.parse_int(s)                              # 安全整数解析
S.handle_tab(key, model, field="focus", count=2)  # Tab 键切换焦点
S.TAG_STYLE                                 # tag->attr 映射字典
S.ATTR_TEXT / ATTR_MUTED / ATTR_OK / ATTR_WARN / ATTR_DANGER / ATTR_FOCUS / ATTR_BORDER
```

### 鼠标

```python
S.get_mouse_event(stdscr)  # -> (x, y, bstate) 或 None
S.mouse_wheel_delta(bstate)  # -> 滚轮方向
S.hit_test(lines, y, x, mouse_y, mouse_x)  # 点击测试
S.scroll_key(key, scroll_offset, visible_count, total_count)  # 滚动处理
```

---

## 任务一：迁移 wifi-tui 到 run_tui_loop

### 文件位置

`quickshell/modules/wifi/bin/sumika-wifi-tui`

### 当前架构（需要替换的部分）

wifi-tui 当前是一个 `WiFiTUI` 类，包含：

1. `__init__` — 初始化状态（saved/available 列表、focus、selected、busy 等）
2. `run()` — 手动事件循环（`_init_curses` → `while not _quit` → `_draw` + `_handle_input` → `_cleanup`）
3. `_init_curses()` — 手动 `curses.curs_set(0)` / `noecho()` / `cbreak()` / `keypad(True)` / `S.init_colors()` / `stdscr.timeout(200)`
4. `_cleanup()` — 空函数
5. `_run_bg(label, fn, *args)` — 自己的 threading.Thread 包装
6. `_poll_async()` — 检查 `_async_msg` 和 `_scan_deadline`
7. `_draw()` — 渲染（hero + 3 个 panel + help bar + password prompt overlay）
8. `_handle_input()` — 按键处理
9. `_hero_info()` — 构造 hero 数据
10. `_draw_saved_table()` / `_draw_available_table()` / `_draw_status_table()` — 表格渲染
11. `_draw_password_prompt()` — 密码输入框 overlay

### 目标架构

将 `WiFiTUI` 类拆解为：

1. **Model 对象**（普通 Python 类，不需要继承 `S.StatusModel`，但必须有 `dirty` 属性）
2. **`_view(stdscr, model)` 函数** — 从原 `_draw()` 提取
3. **`_handle_key(stdscr, model, key)` 函数** — 从原 `_handle_input()` 提取
4. **`main()` 入口** — 调 `S.run_tui_loop(stdscr, model, _view, _handle_key, ...)`

### 具体步骤

#### 步骤 1：创建 Model 类

把 `WiFiTUI.__init__` 的所有状态字段提取到一个新类 `WifiModel`：

```python
class WifiModel:
    dirty = True  # run_tui_loop 需要这个属性

    def __init__(self):
        self.saved = []
        self.available = []
        self.status = None
        self.focus = F_SAVED     # 0=saved, 1=available, 2=status
        self.selected = 0
        self.busy = False
        self.status_msg = "Press s to scan, Enter to connect"
        self.log_lines = []
        self.password_prompt = None  # ssid 或 None
        self.password_buf = ""
        self._async_msg = None
        self._scan_deadline = 0.0
        self._show_available = True
```

#### 步骤 2：迁移 `_run_bg` 到 Model

`_run_bg` 使用 `threading.Thread` + `self._async_msg`。可以保留这个模式，但改用 Model 的字段。或者迁移到 `S.run_cmd_bg` + 回调——但 nmcli 命令不是简单的 stdout 解析，`_run_bg` 包装的是 Python 函数不是命令行。**保留 `_run_bg` 原样**，只是把它变成 Model 的方法：

```python
class WifiModel:
    ...
    def run_bg(self, label, fn, *args):
        if self.busy:
            return
        self.busy = True
        self.status_msg = label
        self.dirty = True

        def worker():
            try:
                _ok, msg = fn(*args)
                self._async_msg = msg
            except Exception as exc:
                self._async_msg = f"Error: {exc}"
            finally:
                self.busy = False

        threading.Thread(target=worker, daemon=True).start()
```

#### 步骤 3：迁移 `_poll_async` 到 refresh_callback

`_poll_async` 每帧检查 `_async_msg` 和 `_scan_deadline`。这正好是 `refresh_callback` 的用途：

```python
def _poll(model):
    """refresh_callback: 检查异步消息和扫描截止时间"""
    if model._async_msg is not None:
        model.status_msg = model._async_msg
        model._async_msg = None
        _refresh_data(model)
        model.dirty = True
    deadline = getattr(model, "_scan_deadline", 0.0) or 0.0
    if deadline and time.monotonic() >= deadline:
        model._scan_deadline = 0.0
        _refresh_data(model)
        n = len(model.available)
        if not model.busy:
            model.status_msg = f"{n} network{'s' if n != 1 else ''} found"
        model.dirty = True
```

#### 步骤 4：迁移 `_draw` 到 `_view` 函数

把 `WiFiTUI._draw(self)` 改为 `_view(stdscr, m)`：
- `self.stdscr` → `stdscr`
- `self.xxx` → `m.xxx`
- `self._hero_info()` → `_hero_info(m)`
- `self._draw_saved_table(...)` → `_draw_saved_table(stdscr, m, ...)`
- 等等

注意 `_draw` 开头已有 `S.require_terminal_size(self.stdscr, 40, 12)`，改为 `S.require_terminal_size(stdscr, 40, 12)`。

`_draw` 里的 `self.stdscr.erase()` 保留为 `stdscr.erase()`。

#### 步骤 5：迁移 `_handle_input` 到 `_handle_key` 函数

把 `WiFiTUI._handle_input(self)` 改为 `_handle_key(stdscr, m, key)`：

- 原来 `key = self.stdscr.getch()` → 不需要了，`key` 是参数传入的
- 原来 `if key == -1: return` → 不需要了，`run_tui_loop` 已处理
- 原来 `self._quit = True` → `return False`
- `self.xxx` → `m.xxx`
- 方法调用 `self._run_bg(...)` → `m.run_bg(...)`
- 方法调用 `self._refresh_data()` → `_refresh_data(m)`
- 每个修改状态的地方加 `m.dirty = True`

**重要**：原 `_handle_input` 不返回值，用 `self._quit` 控制退出。新函数必须 `return True` 继续、`return False` 退出。确保所有路径都有返回值。

#### 步骤 6：迁移辅助方法为顶层函数

以下方法需要从 `WiFiTUI` 的实例方法改为接受 `stdscr` 和 `model` 的顶层函数：

- `_hero_info(self)` → `_hero_info(m)`
- `_draw_saved_table(self, y, x, h, w, saved)` → `_draw_saved_table(stdscr, m, y, x, h, w, saved)`
- `_draw_available_table(self, y, x, h, w, available)` → `_draw_available_table(stdscr, m, y, x, h, w, available)`
- `_draw_status_table(self, y, x, h, w)` → `_draw_status_table(stdscr, m, y, x, h, w)`
- `_draw_password_prompt(self, h, w)` → `_draw_password_prompt(stdscr, m, h, w)`
- `_refresh_data(self)` → `_refresh_data(m)`

每个函数里 `self.xxx` → `m.xxx`，`self.stdscr` → `stdscr`。

#### 步骤 7：修改 main() 入口

原来的：
```python
def main():
    S.setup_locale()
    try:
        curses.wrapper(lambda stdscr: WiFiTUI(stdscr).run())
    except KeyboardInterrupt:
        pass
```

改为：
```python
def main():
    S.setup_locale()
    try:
        curses.wrapper(lambda stdscr: _bootstrap(stdscr))
    except KeyboardInterrupt:
        pass

def _bootstrap(stdscr):
    m = WifiModel()
    prepare_wifi()
    _refresh_data(m)
    rescan_wifi()
    m._scan_deadline = time.monotonic() + 2.0
    m.status_msg = "Scanning… press s to rescan"
    S.run_tui_loop(stdscr, m, _view, _handle_key,
                   poll_timeout=200,
                   refresh_interval=0.1,
                   refresh_callback=_poll)
```

注意 `prepare_wifi()` 和 `rescan_wifi()` 原来在 `run()` 里调，现在移到 `_bootstrap` 里，在 `run_tui_loop` 之前调。

#### 步骤 8：删除不再需要的代码

删除 `WiFiTUI` 类、`run()` 方法、`_init_curses()` 方法、`_cleanup()` 方法。

#### 步骤 9：验证

```bash
# 语法检查
python3 -c "import py_compile; py_compile.compile('quickshell/modules/wifi/bin/sumika-wifi-tui', doraise=True)"

# 功能测试（在终端里运行）
python3 quickshell/modules/wifi/bin/sumika-wifi-tui
# 测试：j/k 导航、Tab 切换 section、Enter 连接、s 扫描、q 退出
```

---

## 任务二：迁移 bluetooth-tui 到 run_tui_loop

### 文件位置

`quickshell/modules/wifi/bin/sumika-bluetooth-tui`

### 当前架构

和 wifi-tui 几乎一样的模式：`BluetoothTUI` 类 + `run()` + `_init_curses()` + `_draw()` + `_handle_input()` + `_poll()` + `_cleanup()`。

比 wifi-tui 多一个 `_poll()` 方法（在 `_draw` 和 `_handle_input` 之间调），以及 PIN 码输入框。

### 具体步骤

和 wifi-tui 完全相同的迁移模式：

1. `BluetoothTUI.__init__` → `BluetoothModel` 类（加 `dirty = True`）
2. `_run_bg` → Model 的 `run_bg` 方法（和 wifi 一样保留 threading 模式）
3. `_poll` → `_poll(model)` 顶层函数，用作 `refresh_callback`
4. `_draw` → `_view(stdscr, m)` 函数
5. `_handle_input` → `_handle_key(stdscr, m, key)` 函数（`self._quit = True` → `return False`）
6. 所有辅助方法 → 顶层函数（`_hero_info`、`_draw_paired_table`、`_draw_discovered_table`、`_draw_adapter_table`、`_draw_pin_prompt` 等）
7. `main()` → 用 `S.run_tui_loop` + `refresh_callback=_poll`
8. 删除 `BluetoothTUI` 类、`run()`、`_init_curses()`、`_cleanup()`

### 注意事项

- bluetooth-tui 的 `_poll` 比 wifi 多一些逻辑（扫描结果检查等），全部移入 `_poll(model)` 函数
- PIN 码输入框和 wifi 的密码输入框类似，迁移方式相同
- bluetooth-tui 用 `bluetoothctl` 后端，不是 nmcli，不要动后端逻辑

---

## 任务三：VoiceModelStatusPopup 生命周期统一

### 文件位置

`~/.local/share/sumika-shell/extensions/voice/bar/VoiceModelStatusPopup.qml`

### 问题

这个组件是一个 `PopupWindow`，重复了 `ContextMenuWindow.qml` 的生命周期管理代码：
- `dismissGuard` Timer + `GlobalFocusGrab.addDismissable/removeDismissable`
- `onVisibleChanged` 里的 dismissGuard 控制
- `Connections { target: GlobalFocusGrab; onDismissed: root.close() }`
- `MouseArea` 点击外部关闭

### 限制

**不能直接继承 `ContextMenuWindow`**，因为 `ContextMenuWindow.open()` 会注册到 `ContextMenuTracker`，导致其他右键菜单打开时强制关闭这个弹窗。VoiceModelStatusPopup 不是右键菜单，不应该被 ContextMenuTracker 管理。

### 方案：提取 ManagedPopupWindow 基类

1. 创建 `quickshell/modules/common/widgets/ManagedPopupWindow.qml`：

```qml
// ManagedPopupWindow — PopupWindow with shared lifecycle management.
// Provides: dismiss guard, GlobalFocusGrab integration, click-outside-to-close,
// fade-in animation, StyledRectangularShadow, popupBackground Rectangle.
//
// Subclass or use directly by setting the `content` default property.
// Override `close()` if you need custom cleanup.
//
// Unlike ContextMenuWindow, does NOT register with ContextMenuTracker.

PopupWindow {
    id: root

    default property alias content: columnLayout.data

    signal closed()

    color: "transparent"

    property real outerPadding: Appearance.sizes.elevationMargin
    property real menuPadding: 6

    implicitWidth: popupBackground.implicitWidth + root.outerPadding * 2
    implicitHeight: popupBackground.implicitHeight + root.outerPadding * 2

    function open() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.closed();
    }

    // ── Dismiss guard ──
    // 延迟注册 dismissable，避免打开时的点击被误判为"点击外部"
    Timer {
        id: dismissGuard
        interval: 50
        repeat: false
        onTriggered: {
            if (root.visible)
                GlobalFocusGrab.addDismissable(root);
        }
    }

    onVisibleChanged: {
        if (visible) {
            dismissGuard.restart();
        } else {
            dismissGuard.stop();
            GlobalFocusGrab.removeDismissable(root);
        }
    }

    Component.onDestruction: {
        dismissGuard.stop();
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() { root.close() }
    }

    // ── Click outside to close ──
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            const pos = mapToItem(popupBackground, event.x, event.y)
            if (pos.x < 0 || pos.x > popupBackground.width || pos.y < 0 || pos.y > popupBackground.height)
                root.close();
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.outerPadding
            }
            color: TuiStyle.bg
            radius: TuiStyle.shellRadius
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.menuBorder
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: columnLayout.implicitWidth + root.menuPadding * 2
            implicitHeight: columnLayout.implicitHeight + root.menuPadding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(popupBackground)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(popupBackground)
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(popupBackground)
            }

            ColumnLayout {
                id: columnLayout
                anchors {
                    fill: parent
                    margins: root.menuPadding
                }
                spacing: 0
            }
        }
    }
}
```

2. 让 `ContextMenuWindow.qml` 继承 `ManagedPopupWindow`：

把 `ContextMenuWindow.qml` 中所有重复的生命周期代码删除，改为：

```qml
import qs.modules.common.widgets

ManagedPopupWindow {
    id: root

    signal menuClosed()

    function open() {
        if (ContextMenuTracker.activeMenu && ContextMenuTracker.activeMenu !== root)
            ContextMenuTracker.activeMenu.close();
        ContextMenuTracker.activeMenu = root;
        root.visible = true;
    }

    function close() {
        if (ContextMenuTracker.activeMenu === root)
            ContextMenuTracker.activeMenu = null;
        root.visible = false;
        root.menuClosed();
    }

    // ... 其余内容不变（ContextMenuTracker 相关逻辑、content 等）
}
```

注意：`ContextMenuWindow` 的 `open()` 和 `close()` 需要覆盖 `ManagedPopupWindow` 的版本，因为要额外处理 `ContextMenuTracker`。`menuClosed` 信号是 `ContextMenuWindow` 特有的，`ManagedPopupWindow` 只有 `closed` 信号。

3. 让 `VoiceModelStatusPopup.qml` 继承 `ManagedPopupWindow`：

删除所有重复的生命周期代码（dismissGuard、GlobalFocusGrab、onVisibleChanged、Connections、MouseArea、popupBackground、StyledRectangularShadow），改为：

```qml
import qs.modules.common.widgets

ManagedPopupWindow {
    id: root

    signal closed()  // 已在基类定义，但 VoiceModel 需要自己的

    property string shareDir: FileUtils.trimFileProtocol(Qt.resolvedUrl("..")) + "/bin"

    // 覆盖 open/close 以管理 barPopupType
    function open() {
        root.visible = true;
        GlobalStates.barPopupType = "voiceModel";
    }
    function close() {
        if (GlobalStates.barPopupType === "voiceModel")
            GlobalStates.barPopupType = "";
        root.visible = false;
        root.closed();
    }

    Component.onCompleted: {
        open();
        refreshAll();
    }

    // ── Model status state ──
    property string modelStatus: "checking"
    // ... 其余状态属性不变 ...

    // ── Process checks ──
    // ... checkModelProc, venvCheckProc, daemonCheckProc 不变 ...

    // ── barPopupType 监听 ──
    Connections {
        target: GlobalStates
        function onBarPopupTypeChanged() {
            if (GlobalStates.barPopupType !== "voiceModel" && root.visible) {
                root.close();
            }
        }
    }

    // ── Content ──
    // 原来 ColumnLayout 里的 StatusRow 组件直接作为子项放入
    // ManagedPopupWindow 的 default property alias content: columnLayout.data
    // 所以直接写在这里即可：

    Item {
        Layout.fillWidth: true
        implicitHeight: 32
        StyledText {
            anchors.centerIn: parent
            text: "Offline Model Status"
            // ...
        }
    }
    // ... 其余 StatusRow 和内容不变 ...
}
```

### 步骤

1. 创建 `quickshell/modules/common/widgets/ManagedPopupWindow.qml`
2. 在 `quickshell/modules/common/widgets/qmldir` 注册 `ManagedPopupWindow 1.0 ManagedPopupWindow.qml`
3. 重构 `ContextMenuWindow.qml` 继承 `ManagedPopupWindow`
4. 重构 `VoiceModelStatusPopup.qml` 继承 `ManagedPopupWindow`
5. 重启 bar 验证：右键菜单正常打开/关闭、voice model popup 正常打开/关闭

---

## 验收标准

1. `quickshell/modules/wifi/bin/sumika-wifi-tui` 使用 `S.run_tui_loop`，不再有 `WiFiTUI` 类、`_init_curses`、`_cleanup`、`while not _quit` 循环
2. `quickshell/modules/wifi/bin/sumika-bluetooth-tui` 同上
3. 两个 TUI 保留所有原有功能（WiFi 连接/断开/忘记/扫描、蓝牙配对/取消配对/PIN 码）
4. 两个 TUI 获得鼠标支持（`run_tui_loop` 自动启用）
5. `ManagedPopupWindow.qml` 创建，`ContextMenuWindow.qml` 和 `VoiceModelStatusPopup.qml` 都继承它
6. 右键菜单和 voice model popup 都正常工作
7. 所有文件通过语法检查：`python3 -c "import py_compile; py_compile.compile('file', doraise=True)"` 和 bar 无 QML 错误

## 注意事项

- **不要动后端逻辑**：nmcli 命令、bluetoothctl 命令、WiFi/蓝牙的连接/断开/扫描逻辑保持不变
- **不要动表格渲染逻辑**：`_draw_saved_table`、`_draw_available_table` 等只改 `self` → `m`/`stdscr`，不改渲染方式
- **不要动密码/PIN 输入框逻辑**：只改方法签名和引用方式
- **保留 `threading.Thread` 模式**：`_run_bg` 不迁移到 `S.run_cmd_bg`（它包装的是 Python 函数不是命令行）
- **每改一个文件就做语法检查**：`python3 -c "import py_compile; py_compile.compile('path', doraise=True)"`
- **改完后重启 bar 验证**：`~/development/OMD/bin/sumika-restart --quickshell-only`，检查 `/tmp/sumika-bar.log` 无错误