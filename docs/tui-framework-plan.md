# Python TUI 框架统一方案

## 背景

OMD 现有 9 个 Python 脚本（`bin/` 下），涵盖以下设置工具：

| 脚本 | 类型 | 代码行数 | 架构模式 |
|---|---|---|---|
| `omd-wifi-tui` | 工具盒（bar 弹出） | 1088 | 独立 OOP，自建事件循环 |
| `omd-bluetooth-tui` | 工具盒（bar 弹出） | 1422 | 独立 OOP，自建事件循环 + bluetoothctl agent |
| `omd-settings-keyboard-tui` | 设置中心 | 1251 | `StatusModel` + `run_tui_loop` |
| `omd-settings-voice-tui` | 设置中心 | 707 | `StatusModel` + `run_tui_loop` |
| `omd-settings-vm-tui` | 设置中心 | 547 | `StatusModel` + `run_tui_loop` |
| `omd-settings-theme-tui` | 设置中心 | 1093 | `StatusModel` + `run_tui_loop` |
| `omd-settings-backup-tui` | 设置中心 | 1008 | 自建 Model，自建事件循环 |
| `omd-settings-ocr-tui` | 设置中心 | 463 | `StatusModel` + `run_tui_loop` |
| `omd-ocr` | 独立命令行工具 | 42 | 无 TUI，纯 CLI |

已共享的模块 `bin/omd_tui_shared.py`（851 行）覆盖了：
- 颜色对初始化（`init_colors`, 16 个颜色常量）
- 绘制原语（边框、文本、表格、日志、英雄栏、帮助栏）
- 文本工具（截断、折行、宽度计算、安全输出）
- 视觉组件（`hero_line`, `primary_line`, `action_line`, `kv_line`, `toggle_line`, `segmented_line` 等）
- 模型基类 `StatusModel`（状态管理、日志、后台刷新）
- 事件循环 `run_tui_loop`
- 后端命令执行（`run_cmd`, `run_cmd_bg`, `drain_callbacks`）
- 鼠标事件处理
- 布局工具（`two_column_widths`）

下文分析现有重复和可提取的框架层。

## 现状：三种架构模式

### 模式 A：`StatusModel` + `run_tui_loop`（5 个脚本）

**文件：** keyboard, voice, vm, theme, ocr

**共同结构：**
```
class Model(S.StatusModel):
    def __init__(self):     # 设默认值，调 refresh()
    def refresh(self):      # 调 S.run_cmd_bg(...) 用 pending 计数器同步
    def run_action(self, action):  # 调 S.run_cmd_bg(...)，设置 busy/message/logs

def view(stdscr, model):    # 调用 render_left/render_right/render_log/hero_info
def handle_key(stdscr, model, key):  # 按键分发

def main(stdscr):
    S.run_tui_loop(stdscr, Model(), view, handle_key, ...)
```

**重复模式（5 个脚本中完全相同）：**
1. `refresh()` 中的 `pending` 计数器模式——至少 5 处几乎同样的 `pending = [N]` / `complete()` 闭包
2. `run_action()` 中的 `cb(lines, err)` 模式——结构一样，只是具体字段不同
3. 每个 TUI 自己写 `render_log()`——但逻辑几乎一样（截取 + `("muted", truncate(line))`）
4. 每个 TUI 自己写 `hero_info()`——都是调用 `S.hero_line(title, ...)` 但参数组装各不相同
5. `handle_key` 中的滚轮/翻页代码——方向不同但公式一样（`KEY_UP`/`DOWN`/`PPAGE`/`NPAGE`/`HOME`/`END` + `scroll_offset`）
6. `handle_key` 中的鼠标处理——至少在 4 个 TUI 中手写 `S.get_mouse_event()` + `mouse_wheel_delta()`

### 模式 B：独立 OOP（2 个脚本）

**文件：** wifi, bluetooth

**共同结构：**
```
class XxxTUI:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.focus = F_SECTION_A   # 焦点区域枚举
        self.selected = 0
        self.busy = False
        self.status_msg = "..."

    def run(self):                # 自建事件循环
    def _init_curses(self):       # curses 初始化
    def _handle_input(self):      # 按键处理
    def _draw(self):              # 全屏绘制
    def _hero_info(self):         # 英雄栏
    def _run_bg(self, ...):       # 后台线程
    def _draw_xxx_table(self):    # 各区域表格绘制
    def _draw_password_prompt(self):  # 弹出框
```

**这两种 TUI（wifi + bluetooth）之间的重复：**
1. `_init_curses()`——5 行几乎一样
2. `_force_narrow_ambiguous_locale()`——完全一样（wifi 的 `main()` 和 bluetooth 的 `main()` 都有）
3. `_draw_password_prompt` / `_draw_prompt`——overlay 弹出框几乎一样
4. `_draw_row()`、`_put_row_cells()`、`_space_around()`、`_header_attr()`、`_sel_attr()`——表格绘制代码 95% 相同
5. `_focus_next()` / `_focus_prev()`——焦点切换逻辑相同
6. `_handle_input()` 中的键盘导航（`j/k/↑/↓/Tab/Backtab/q`）——结构一致
7. `_move_sel()`——几乎一样
8. `nmcli_split()`（wifi）和 `_parse_scan_lines()`（bluetooth）——不同的数据解析但模式类似

**wifi 特殊：** 密码输入 overlay、Enterprise 检测、nmcli 集成
**bluetooth 特殊：** `pty_spawn()` + bluetoothctl agent（唯一使用伪终端的），设备图标/类型推理

### 模式 C：自建 Model（1 个脚本）

**文件：** backup

**特点：** 不使用 `StatusModel`，自建 `Model` 类。有可编辑字段（独特的表单编辑能力），使用 `threading.Thread` 直接管理后台线程（不是 `run_cmd_bg`），自建事件循环。

**backup 独有功能：**
- Config 字段编辑（`editing_field` / `edit_buffer` / `edit_field_key`）
- SMB 网络挂载/同步（`test_connection`, `run_backup`）
- 单独的 `omd-backup` 后端脚本
- 比较结果展示

## 重复代码汇总

| 重复项 | 出现次数 | 现在位置 | 建议 |
|---|---|---|---|
| `pending` 计数器模式 | 5 (keyboard, voice, vm, theme, ocr) | 各 TUI 的 `refresh()` | 提取到 `StatusModel` 或 `RefreshHelper` |
| `run_action` 的 `cb(lines, err)` 样板 | 5+ | 各 TUI 的 `run_action()` | 基类提供通用回调方法 |
| 滚轮/翻页 `handle_key` | 5+ (所有带日志的 TUI) | 各 TUI 的 `handle_key()` | 提取到共享模块或 `run_tui_loop` 钩子 |
| 鼠标事件处理 | 4+ | 各 TUI 的 `handle_key()` | 同 |
| `render_log()` | 4+ (keyboard, voice, vm, ocr, theme) | 各 TUI 的 render 函数 | 共享 `render_log()` |
| 表格绘制 (`_draw_row`, `_space_around`, 等) | 2 (wifi, bluetooth) | 各 TUI 内部 | 提取共享的表格组件 |
| `_init_curses()` | 2 (wifi, bluetooth) | 各 TUI 内部 | 可直接用 `run_tui_loop` |
| `_force_narrow_ambiguous_locale()` | 2 (wifi, bluetooth) | 各 TUI 的 `main()` | 移到共享模块 |
| 提示框 overlay (`_draw_password_prompt`, `_draw_prompt`) | 2 (wifi, bluetooth) | 各 TUI 内部 | 提取 `draw_dialog()` |
| 焦点切换 (`_focus_next/_focus_prev`) | 2 (wifi, bluetooth) | 各 TUI 内部 | 提取共享焦点管理器 |
| 英雄栏构建 (`_hero_info` vs `hero_info`) | 8 | 各 TUI 内部 | 已有 `hero_line()` 原语，不需要抽象 |
| `StatusModel` 字段默认值 | 5 | 各 TUI 的 `__init__` | 可统一但差异较大，不强制 |

## 框架提取方案（建议）

### 目标
1. 消除机械性重复（pending 计数器、滚动处理、log 渲染）
2. 保持各 TUI 的内容自由，不强制统一渲染模式
3. wifi/bluetooth 的独立架构保留（它们有特殊的伪终端/后台进程需求），但可吸收共享的表格/弹窗组件
4. backup 的字段编辑能力如果需要推广，才提取表单组件

### 阶段一：提取无争议的机械重复（到 `omd_tui_shared.py`）

```
# 新增:
def setup_locale():
    """设置 LC_ALL=C.UTF-8 + 窄 ambiguous 宽度"""
    ...

class RefreshCounter:
    """简化 pending 计数器模式：
    pending = RefreshCounter(n, on_done=lambda: set(refreshing=False))
    with pending:
        call()
    """
    ...

# 滚动帮助函数
def scroll_key(key, scroll_offset, max_offset=None):
    """统一处理 KEY_UP/DOWN/PPAGE/NPAGE/HOME/END 的偏移量计算"""
    ...

def render_log(model, w, h, empty_text="(no activity yet)"):
    """标准日志渲染函数。model.logs 可以是 list[str] 或 list[tuple[str, tag]]"""
    ...

# dialog/overlay
def draw_dialog(stdscr, h, w, lines, attr=S.ATTR_ACCENT_BOLD):
    """居中绘制提示框。wifi 和 bluetooth 各有一个近乎一样的实现。"""
    ...
```

### 阶段二：提取表格组件（wifi/bluetooth 共享）

```
class Table:
    """可排序、可聚焦的表格组件

    用法：
        table = Table(headers=["SSID", "Security", ...])
        table.set_rows(data)
        table.draw(win, y, x, w, h, focus, selected)
    """
    ...
```

### 阶段三（可选）：表单编辑组件

```
class FieldEditor:
    """文本字段编辑，backup TUI 的 config 编辑通用化"""
    ...
```

### 建议的模块组织

保持单文件 `bin/omd_tui_shared.py`（简单项目不需要包结构），按节组织：

```
Current:              After:
  omd_tui_shared.py    omd_tui_shared.py
  (851 lines)          ├── color/attrs         (现状)
                       ├── text utilities      (现状)
                       ├── drawing             (现状 + draw_dialog)
                       ├── components          (现状 + RefreshCounter, render_log, scroll_key, Table)
                       ├── model (StatusModel) (现状 + 通用回调)
                       ├── event loop          (现状 + 鼠标/滚动集成)
                       ├── backend             (现状)
                       ├── mouse               (现状)
                       └── misc                (现状 + setup_locale)
```

### 不变的边界

1. **wifi/bluetooth 保持独立 OOP**——它们有 `bluetoothctl` 伪终端、`nmcli` 等特殊后端，不适合模板化。但可消费共享组件（`Table`, `draw_dialog`, `render_log`）。

2. **backup 的字段编辑**——当前只有它有，如果需要其他 TUI 也有表单编辑才提取。

3. **theme TUI 的图片预览**——独有功能，不提取。

4. **每个 TUI 的 view 布局**——`render_left`/`render_right` 的内容完全属于业务逻辑，不模板化。

## 改动影响

| 修改的文件 | 预计改动量 | 风险 |
|---|---|---|
| `omd_tui_shared.py` | +200~400 行（新增函数）| 低，只增不改 |
| `omd-settings-keyboard-tui` | -80~120 行（去掉 pending/log/scroll 样板）| 中 |
| `omd-settings-voice-tui` | -60~100 行 | 中 |
| `omd-settings-vm-tui` | -50~80 行 | 中 |
| `omd-settings-theme-tui` | -80~120 行 | 中 |
| `omd-settings-ocr-tui` | -40~60 行 | 低（脚本最小）|
| `omd-wifi-tui` | -100~150 行（Table/scroll locale 替换）| 中 |
| `omd-bluetooth-tui` | -100~150 行 | 中 |
| `omd-settings-backup-tui` | -30~50 行（scroll 替换）| 低 |

总计：每个 TUI 减少 15-25% 的样板代码。

## 不做的事情

1. **不引入框架依赖**——保持纯 `curses` + Python stdlib
2. **不统一渲染引擎**——每个 TUI 的内容布局是其核心差异
3. **不把 wifi/bluetooth 强行套进 `StatusModel`**——它们的后端交互模式差异大
4. **不提取 `omd-ocr`**——它只是简单的 CLI 工具
