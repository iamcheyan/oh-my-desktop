# Python TUI 框架

## 当前架构

Sumika Shell 的 Python TUI 位于 `bin/`，并通过
`bin/sumika_tui_framework.py` 共享布局、绘制和事件循环能力：

| 脚本 | 类型 | 架构模式 | Layout 模板 |
|---|---|---|---|

| `sumika-wifi-tui` | 工具盒（bar 弹出） | 独立 OOP，自建事件循环 | 否（用共享 Table 函数） |
| `sumika-bluetooth-tui` | 工具盒（bar 弹出） | 独立 OOP，自建事件循环 | 否（用共享 Table 函数） |
| `sumika-settings-keyboard-tui` | 设置中心 | `StatusModel` + `run_tui_loop` | 是（自定义高度/堆叠） |
| `sumika-settings-voice-tui` | 设置中心 | `StatusModel` + `run_tui_loop` | 是 |
| `sumika-settings-vm-tui` | 设置中心 | `StatusModel` + `run_tui_loop` | 是 |
| `sumika-settings-theme-tui` | 设置中心 | `StatusModel` + `run_tui_loop` | 是（`force_single` + 自定义绘制） |
| `sumika-settings-backup-tui` | 设置中心 | 自建 Model，自建事件循环 | 是 |
共享模块覆盖以下能力。

## 架构模式

### 模式 A：`StatusModel` + `run_tui_loop`（6 个 TUI 的骨架）

```python
class Model(S.StatusModel):
    def refresh(self):      # 调 S.run_cmd_bg(...) via RefreshCounter
    def run_action(self):   # 调 S.run_cmd_bg(...)

def view(stdscr, model):
    ly = S.Layout(stdscr)   # 可选使用 Layout 模板
    ly.compute()
    ly.draw_hero(stdscr, hero_info(model))
    # ... 各 TUI 自有绘制 ...
    ly.draw_help(stdscr, *help_items(model))
    S.finish_frame(stdscr)

def handle_key(stdscr, model, key):  # 按键分发

def main(stdscr):
    S.run_tui_loop(stdscr, Model(), view, handle_key, ...)
```

### 模式 B：独立 OOP（wifi、bluetooth）

```python
class XxxTUI:
    def __init__(self, stdscr): ...
    def run(self):                # 自建事件循环
    def _draw(self):              # 全屏绘制
    def _handle_input(self):      # 按键处理
```

### 模式 C：自建 Model（backup）

```python
class Model:   # 不使用 StatusModel
    # 表单编辑（editing_field/edit_buffer/edit_field_key）
    # threading.Thread 直接管理
```

## Layout 模板框架

### 设计目的

设置 TUI 不应分别维护重复的几何计算。`Layout` 统一提供
`pad_x`、`pad_y`、`content_w`、`left_w`、`right_x` 等布局数据。

### `S.Layout` 类

```python
ly = S.Layout(stdscr)        # 读取终端尺寸
ly.pad = 2                   # 可覆盖默认值
ly.left_w = 34
ly.compute()                 # 计算所有坐标

# 绘制
ly.draw_hero(stdscr, hero_data)
ly.draw_panel("left", "Title", lines, focus=(m.focus == 0))
ly.draw_panel("right", "Title", lines, focus=(m.focus == 1))
ly.draw_help(stdscr, *help_items(m))

# 或：只取坐标自行绘制（backup/voice/ocr 用法）
ly.content_top, ly.left_x, ly.left_w, ly.right_x, ...
```

### Layout 的参数

| 参数 | 默认值 | 说明 |
|---|---|---|
| `pad` | 2 | 边缘留白 |
| `hero_h` | 2 | 英雄栏高度 |
| `help_h` | 1 | 帮助栏高度 |
| `gap` | 1 | 左右面板间距 |
| `left_w` | 34 | 左栏宽度 |
| `right_min` | 28 | 右栏最小宽度 |
| `split_threshold` | 80 | 低于此宽度时隐藏右栏 |
| `force_single` | False | 强制单栏模式 |

### computed 后提供的属性

`content_top`、`content_h`、`content_w`、`show_right`、
`left_x`/`y`/`h`/`w`、`right_x`/`y`/`h`/`w`

### 谁用了 Layout

| TUI | 用法 |
|---|---|
| **vm-tui** | `draw_panel()` 全量使用，左右面板一致 |
| **voice-tui** | 取 `ly.left_w`、`ly.right_x` 等坐标自行绘制（堆叠盒子） |
| **ocr-tui** | 取全部坐标，自定义日志区 |
| **backup-tui** | 取坐标，自定义不等高左右面板 |
| **keyboard-tui** | 取坐标，自定义堆叠盒子（6 框 + 3 路焦点仍保持自制） |
| **theme-tui** | `ly.split_threshold=108` + `force_single` 计算几何，自定义绘制 |
| **wifi-tui** | 否（OOP 结构，用 `S.draw_row`/`S.put_row_cells` 等共享 Table 函数） |
| **bluetooth-tui** | 否（OOP 结构，用 `S.draw_row`/`S.put_row_cells` 等共享 Table 函数） |

## `handle_tab` 焦点切换

```python
if S.handle_tab(key, m):      # field="focus", count=2
    return True
```

自动循环 `model.focus` 0→1→0（或任意 count）。Tab 键通用处理，各 TUI 不再各自手写。

## 已实现能力

### 通用运行能力

在 `sumika_tui_framework.py` 新增了以下提取物，逐 TUI 替换手写样板：

| 提取物 | 用途 | 消费者 |
|---|---|---|
| `RefreshCounter` | 简化 `pending = [N]` 计数器模式 | vm, voice, theme, ocr, keyboard |
| `scroll_key()` | UP/DOWN/PPAGE/NPAGE/HOME/END 统一处理 | vm, voice, ocr, backup |
| `draw_dialog()` | 居中 overlay 提示框 | wifi, bluetooth |
| `setup_locale()` | LC_ALL + 窄 ambiguous 统一设置 | 所有 8 个 TUI |

### Layout 模板框架

| 能力 | 说明 |
|---|---|
| `Layout` 类 | 标准两栏布局，含 `compute()` / `draw_panel()` / `inner_rect()` |
| `handle_tab()` | Tab 焦点切换 |
已转换 6 个 TUI：
- vm-tui（最先转换，验证 API）
- voice-tui
- ocr-tui
- backup-tui
- keyboard-tui（取坐标 + 自定义堆叠盒子和焦点）
- theme-tui（`split_threshold=108`, `force_single`, 自定义预览/设置/动作盒）
### 表格渲染原语

将 wifi/bluetooth 共用的 6 个表格绘制方法提取到 `sumika_tui_framework.py`：

| 提取物 | 说明 |
|---|---|
| `space_around()` | CSS/ratatui SpaceAround 列偏移计算 |
| `clip_cell()` | 单元格文本截断/填充 |
| `draw_row()` | 行绘制：背景填充 + 按偏移放单元格 |
| `put_row_cells()` | 自动计算 SpaceAround 偏移的 `draw_row` 简写 |
| `header_attr()` | 表头样式（`ATTR_SECTION`） |
| `sel_attr()` | 选中行样式（`ATTR_FOCUS` 或 normal） |

wifi-tui 删除 6 个方法（`_space_around`, `_put_row_cells`, `_clip`, `_header_attr`, `_sel_attr`, `_draw_row`），bluetooth-tui 同理。各自约 -50 行。

### 表单编辑边界

只有 backup 需要表单编辑，无第二消费者。保持 backup 独有。

## 不变的边界

1. 不动 `sumika-ocr`（纯 CLI，没有 TUI）
2. 不动 theme TUI 的图片预览功能
3. 不动 backup 的线程模型
4. 不把 wifi/bluetooth 强行套进 `StatusModel`
5. 不加第三方依赖——纯 `curses` + Python stdlib
6. 共享原语保持集中，只有出现清晰的职责边界时才继续拆文件

## 新建 TUI 实践指南

### 0. 起步

```python
import sys, os, curses, locale, threading
sys.path.insert(0, os.path.dirname(__file__))
import sumika_tui_framework as S
```

所有 TUI 共用 `bin/sumika_tui_framework.py`，不加第三方依赖。

### 1. 选骨架

| 用途 | 骨架 | 已有的例子 |
|------|------|-----------|
| **设置中心**（有模型、状态刷新、日志） | `S.StatusModel` + `S.run_tui_loop()` | vm, voice, ocr, keyboard, theme |
| **工具盒**（bar 弹出，全自控） | 自写 OOP 类 + 自建事件循环 | wifi, bluetooth |
| **含表单编辑** | 自写 Model（keep threading） | backup |

Settings TUI 模板代码：

```python
class Model(S.StatusModel):
    def refresh(self):
        # S.run_cmd_bg(..., callback=...) via RefreshCounter
    def run_action(self):
        pass

_hero: list[tuple[str, str]] | None = None
def hero_info(m: Model):
    global _hero
    if _hero is None:
        _hero = [S.primary_line("My Tool"), S.action_line("key1->action1", "key2->action2")]
    return _hero

def view(stdscr, m: Model):
    ly = S.Layout(stdscr)
    ly.compute()
    ly.draw_hero(stdscr, hero_info(m))
    ly.draw_panel("left", "Items", render_items(m), focus=(m.focus == 0))
    ly.draw_panel("right", "Details", render_details(m), focus=(m.focus == 1))
    ly.draw_help(stdscr, *help_items(m))
    S.finish_frame(stdscr)

def handle_key(stdscr, m: Model, key: str) -> bool:
    if S.handle_tab(key, m): return True
    if key == "q": return False
    # ... 其他按键
    return True

def main(stdscr):
    S.run_tui_loop(stdscr, Model(), view, handle_key)

if __name__ == "__main__":
    S.setup_locale()
    curses.wrapper(main)
```

### 2. 构图

`S.Layout` 覆盖了多数情况，`compute()` 前调参数：

| 参数 | 默认 | 说明 |
|------|------|------|
| `pad` | 2 | 边缘留白 |
| `hero_h` | 2 | 英雄栏高度 |
| `help_h` | 1 | 帮助栏高度 |
| `gap` | 1 | 左右栏间距 |
| `left_w` | 34 | 左栏宽度 |
| `right_min` | 28 | 右栏最小宽度 |
| `split_threshold` | 80 | 低于此宽隐藏右栏 |
| `force_single` | False | 强制单栏 |

`compute()` 后取用：

```python
ly.content_top     # 内容区起始行
ly.content_h       # 内容区高度
ly.content_w       # 内容区宽度
ly.show_right      # 右栏是否有空间
ly.left_x, ly.left_y, ly.left_h, ly.left_w
ly.right_x, ly.right_y, ly.right_h, ly.right_w
```

**标准面板**：`ly.draw_panel("left", title, lines, focus=True)` — 画边框 + 标题 + 内容。

**不标准的情况**（取坐标自己画）：
- 堆叠多个盒子（keyboard：左 3 右 3）
- 不等高左右栏（backup）
- 内置预览 / 自定义区域（theme：预览框 + 设置框 + 动作框 + 主题网格）
- 大日志区（ocr / voice）

#### 布局的几个典型模式

**等高二栏**（vm 用法）：
```python
ly.draw_panel("left", "Left", lines, focus=True)
ly.draw_panel("right", "Right", lines, focus=True)
```

**左栏堆叠 + 右栏内容**（voice 用法）：
```python
S.draw_border(stdscr, ly.content_top, ly.left_x, box_h, ly.left_w, "Box A")
S.draw_lines_in_area(...)
S.draw_thick_border(stdscr, ly.content_top + box_h, ly.left_x, ..., ly.left_w, "Box B")
ly.draw_panel("right", "Details", lines, focus=True)
```

**单栏全宽**（theme 窄屏 / ocr 日志区）：
```python
ly.force_single = True;  ly.compute()
S.draw_thick_border(stdscr, ly.content_top, ly.left_x, log_h, ly.content_w, "Logs")
```

**不等高左右栏**（backup 用法）：
```python
left_h = ly.content_h - right_h  # 右栏的高度自己算
S.draw_border(stdscr, ly.content_top, ly.left_x, left_h, ly.left_w, "Left")
S.draw_border(stdscr, ly.content_top, ly.right_x, right_h, ly.right_w, "Right")
```

### 3. 共享组件速查

**所有 TUI 通用：**

| 函数/组件 | 用途 |
|-----------|------|
| `init_colors()` | 配色初始化（curses 颜色对） |
| `draw_border` / `draw_thick_border` / `draw_focus_border` | 三种边框（普通/粗焦/焦点） |
| `draw_hero(stdscr, lines)` | 顶部英雄栏（2 行，带图标） |
| `draw_help(stdscr, generic, specific)` | 底部帮助栏（按键说明） |
| `hero_line` / `primary_line` / `action_line` / `toggle_line` / `kv_line` / `segmented_line` | 标准行组件 |
| `safe_addstr` / `truncate` / `wrap_text` | 文本安全输出与截断 |
| `draw_dialog(stdscr, lines)` | 居中 overlay 弹窗 |
| `setup_locale()` | locale 统一设置（在 `main()` 开头调） |
| `run_cmd(name, *args)` / `run_cmd_bg(...)` / `drain_callbacks()` | 后端命令执行 |
| `get_mouse_event` / `mouse_wheel_delta` | 鼠标事件解析 |
| `finish_frame(stdscr)` | 帧收尾（refresh + 可选鼠标） |
| `require_terminal_size(stdscr, min_w, min_h)` | 终端尺寸检查 |

**Settings TUI 额外：**

| 函数/组件 | 用途 |
|-----------|------|
| `StatusModel` | 基类：`logs` / `refresh()` / `run_action()` / `focus` / `scroll_offset` |
| `run_tui_loop(stdscr, model, view, handle_key, ...)` | 事件循环（定时器、日志限制、refresh 调度） |
| `RefreshCounter(n, on_done)` | `.cb()` 返回 `run_cmd_bg` 的回调闭包，归零调 `on_done` |
| `scroll_key(key, scroll_offset, max_offset)` | 统一滚轮/翻页处理 |
| `draw_log_in_area(win, y, x, h, w, logs, scroll_offset, empty_text)` | 带滚动条的日志区 |
| `Layout` + `handle_tab` | 几何模板 + Tab 焦点切换 |

**Toolbox TUI 额外（wifi/bt 用，settings 也可用）：**

| 函数 | 用途 |
|------|------|
| `draw_row(win, y, x, inner_w, cells, widths, offsets, attr)` | 表格行绘制（填充背景 + 放单元格） |
| `put_row_cells(win, y, x, inner_w, cells, widths, attr)` | 自动算 SpaceAround 偏移的 `draw_row` |
| `space_around(inner_w, col_widths)` | 列偏移计算（CSS SpaceAround 分布） |
| `clip_cell(s, width)` | 单元格截断 + 填充 |
| `header_attr(focused)` | 表头样式（固定 `ATTR_SECTION`） |
| `sel_attr(selected, focused_section)` | 选中行样式（`ATTR_FOCUS` 或 normal） |

### 4. 口诀

1. 新建 settings TUI → `StatusModel` + `Layout` + `draw_panel`/`draw_log_in_area`。不用手写几何。
2. 新建 toolbox TUI → 自写 OOP 类 + 想用 Layout 取坐标就取 + 共享 `draw_row`/`put_row_cells` 画行。
3. 有弹窗 → `S.draw_dialog`。
4. 有日志 → `S.draw_log_in_area`。
5. 有单选/切换/键值行 → `S.toggle_line` / `S.segmented_line` / `S.kv_line`。
6. `main()` 入口必须有一行 `S.setup_locale()` + `curses.wrapper(main)`。
7. **不用的可以不 import**。共享模块函数是工具，不是继承约束。
8. 画完调 `S.finish_frame(stdscr)`。
9. 不加第三方依赖。
