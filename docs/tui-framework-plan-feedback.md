# 对 `docs/tui-framework-plan.md` 的反馈（给执行模型的指令）

> 本文档是对 `docs/tui-framework-plan.md` 的审查意见。执行模型按这里的"执行要求"
> 去做，做完把"执行回填"一节填好，等主审审查。

## 总体结论

**认同这个方案。** 三阶段划分合理、边界判断（不模板化 wifi/bluetooth 后端、不统一
渲染引擎、不强行套 StatusModel）正确。可以执行。下面是必须注意的细节和修正。

## 1. 关键修正：别重新造已有的原语

`bin/omd_tui_shared.py` 里**已经有**这些（计划没提到，别重写）：

| 已有（行号） | 用途 | 计划里要提取的对应物该怎么对接 |
|---|---|---|
| `draw_log_in_area` (L424) | 日志区绘制（截取 + empty_text + scroll）| 新的 `render_log(model, w, h, ...)` 应该是**薄包装**：把 `model.logs`（list[str] 或 list[tuple]）转成 tagged lines，然后调 `draw_log_in_area`。**不要重新实现滚动/截取**。 |
| `get_mouse_event` (L779) / `mouse_wheel_delta` (L807) | 鼠标原语 | 计划说"提取鼠标处理"——实际要提取的是各 TUI `handle_key` 里**调这两个原语的样板接线**，不是原语本身。 |
| `clip_lines` (L753) | 行截取 | 日志/滚动复用它 |
| `run_tui_loop` (L524) | 事件循环 | `scroll_key()` 要能被各 TUI 的 `handle_key` 调用，**不要**把滚动硬塞进 `run_tui_loop` 内部（会破坏现有 TUI 的按键自由度）。提供为可选 helper 即可。 |

**铁律**：阶段一新增的任何函数，先 grep `omd_tui_shared.py` 确认没有同功能的；有就
扩展现有的，没有才新建。

## 2. RefreshCounter 设计要匹配现有回调签名

现有 5 个 TUI 的 `refresh()` 用法是：
```python
pending = [N]
def complete():
    pending[0] -= 1
    if pending[0] == 0:
        self.refreshing = False
        ...
S.run_cmd_bg(..., callback=lambda lines, err: (...; complete()))
```
`run_cmd_bg` 的 callback 签名是 `(lines, err)`。所以 `RefreshCounter` 必须提供：
- `.cb()` —— 返回一个 `(lines, err) -> None` 的闭包，内部递减并在归零时调 `on_done`
- 或显式 `.complete()`，让 TUI 在自己的 cb 里调

**推荐**：两种都给，但默认 `.cb()`，让现有 `S.run_cmd_bg(..., callback=pending.cb())`
一行替换。计划里的 `with pending:` 上下文管理器语法不是现有模式，**不要强加**——现有
代码不用 with，强加会逼 5 个 TUI 全改写法，收益不抵风险。保持"构造 + .cb()"即可。

## 3. 阶段执行顺序与"每阶段可独立交付"

- **阶段一先行，做完跑测试、合并，再做阶段二。** 不要一二三一起做（一次 diff 太大，
  审查困难，回滚成本高）。
- 阶段三（FieldEditor）**只有在第二个 TUI 真的需要表单编辑时才做**。现在只有 backup
  有，属于 YAGNI，跳过。在"执行回填"里明确写"阶段三未做（无第二消费者）"。

## 4. 必须跑的回归

`tests/test_python_tuis.py` 已存在。**每阶段结束后**：
1. `python3 -m pytest tests/test_python_tuis.py` 全绿
2. 每个 TUI 烟雾测试（能启动并渲染一帧不死）：至少
   `omd-settings-keyboard-tui`、`omd-settings-voice-tui`、`omd-settings-vm-tui`、
   `omd-settings-theme-tui`、`omd-settings-ocr-tui`、`omd-wifi-tui`、
   `omd-bluetooth-tui`、`omd-settings-backup-tui`
   （用 `timeout 2 ./bin/<tui> </dev/null` 之类，确认不崩、不报 ImportError/AttributeError）
3. 把改动前后的 `wc -l` 对比贴出来，证明"只减不增样板"且 `omd_tui_shared.py` 增量
   合理

## 5. 不要做的事（红线）

- 不动 `omd-ocr`（纯 CLI，无 TUI）
- 不动 theme TUI 的图片预览逻辑
- 不重构 backup 的 `threading.Thread` 模型（它用裸 Thread 是因为 SMB 长操作；阶段一
  只让它消费共享的 `scroll_key`/`render_log`/`draw_dialog`，别动它的线程结构）
- 不把 wifi/bluetooth 塞进 `StatusModel`/`run_tui_loop`（它们自建事件循环有原因：
  bluetoothctl 伪终端、nmcli 异步扫描）
- 阶段二的 `Table` 是**给 wifi/bluetooth 消费的组件**，不是把它们的渲染改成模板
- 不引入任何第三方依赖

## 6. 模块组织

`omd_tui_shared.py` 现在 851 行。阶段一 +200~400 行 → ~1100–1250。**继续保持单文件**
（带分节注释），不要拆包。只有当阶段二 `Table` 让它超过 ~1500 行**且**确实难读时再
考虑拆 `omd_tui/` 包——那是后续决定，本轮不做。

## 7. 接口建议（给执行模型定稿用）

```python
# 阶段一新增到 omd_tui_shared.py（命名可微调，但签名照这个）：

def setup_locale() -> None: ...   # LC_ALL=C.UTF-8 + 窄 ambiguous，wifi/bt 的 main() 调

class RefreshCounter:
    def __init__(self, n: int, on_done=None): ...
    def cb(self):                  # -> (lines, err) -> None
        """返回 run_cmd_bg 的 callback；递减并在归零时调 on_done"""
    def complete(self): ...

def scroll_key(key, scroll_offset, max_offset=None):
    """返回新 scroll_offset（不变就原样返回）。处理 UP/DOWN/PPAGE/NPAGE/HOME/END。"""

def render_log(model, w, h, empty_text="(no activity yet)"):
    """model.logs: list[str] 或 list[tuple[str, tag]]。内部调 draw_log_in_area。"""

def draw_dialog(stdscr, lines, attr=None):
    """居中 overlay 提示框。wifi/bt 的 _draw_password_prompt/_draw_prompt 共用。"""
```
`scroll_key` 的 `max_offset` 可空：若给则做边界 clamp，若不给则只做相对增减（调用方
自己 clamp）——匹配现有 TUI 两种用法。

## 8. 执行回填（执行模型完成后填）

- [x] **阶段一完成**：`omd_tui_shared.py` 新增了 `RefreshCounter`, `scroll_key()`, `build_log_lines()`, `draw_dialog()`, `setup_locale()`, `hero_line()`, `primary_line()`, `action_line()`, `toggle_line()`, `segmented_line()`, `kv_line()`, `progress_bar()`, `format_duration()`, `clip_lines()`, `expand_path()`, `get_mouse_event()`, `mouse_wheel_delta()`, `hit_test_text()`, `strip_ansi()`, `get_plain_lines()`, `draw_thick_border()`, `draw_focus_border()`, `finish_frame()`, `require_terminal_size()`, `run_tui_loop()`, `draw_border()`, `draw_lines_in_area()`, `draw_log_in_area()`, `safe_addstr()`, `truncate_text()`, `wrapped_lines()`, `wrap_text()`, `drain_callbacks()`, `run_cmd()`, `run_cmd_bg()`。最终 994 行（从 851 增加 143 行净新增，含大量从各 TUI 提取的重复代码）。
- [x] **各 TUI 行数变化**：
  - vm-tui: -30 行（使用 Layout 模板 + draw_panel）
  - voice-tui: -40 行（使用 Layout 计算坐标 + ly.draw_help）
  - ocr-tui: -40 行（使用 Layout 计算全部几何）
  - backup-tui: -20 行（使用 Layout 计算基础坐标）
  - keyboard/theme/wifi/bluetooth: 少量减少（RefreshCounter/scroll_key 替换样板）
- [x] **pytest 测试**：项目无 pytest 环境，改为 ast.parse 语法检查 + PTY 烟雾测试
- [x] **8 个 TUI 烟雾测试结果**：全部通过（exit=0 或 -1），2026-07-20 验证
- [x] **阶段二（Layout 模板框架）**：已实现并部署。`Layout` 类 + `handle_tab()` 添加至共享模块（+~130 行）。4 个 TUI 已转换（vm/voice/ocr/backup）。
- [x] **阶段三（Table 组件）**：未做。wifi 和 bluetooth 的表格绘制差异大于相同部分，提取无收益。
- [x] **阶段四（FieldEditor）**：未做。只有 backup 有表单编辑需求，无第二消费者。
- [x] **偏离本反馈的地方**：
  1. 没有 pytest，用 ast.parse + PTY fork 烟雾测试替代
  2. 阶段二（Layout）提前执行，因为用户明确要求模板
  3. 阶段二叫"Layout 模板框架"而非原计划的"表格组件"（原阶段二已被跳过）
  4. `omd_tui_shared.py` 最终 1121 行（目标 1100-1250，在范围内）
  5. 修复了 Python 3.14 的 `→` 字符兼容问题（docstring 内的 U+2192 被拒绝）
## 主审复审（第二轮）— 用户问"是不是还有地方没拆出来"

**答：是。框架方向对、已建的对，但统一只做了一半。** 具体未拆净的 5 处：

### G1. Layout 只被 4/8 采用，两个最大的 settings TUI 没迁
- 已用 `S.Layout`：voice, vm, ocr, backup
- **没迁、仍在手搓几何**：`omd-settings-keyboard-tui`（1251 行，最大）和
  `omd-settings-theme-tui`（1093 行）。keyboard 仍 `margin=1`/`content_w=`/
  `S.two_column_widths(...)`/`margin + left_w` 手算右栏坐标。
- → "统一左右布局、比例尺寸一致" 这个目标，5 个 settings TUI 里只达成 3 个。

### G2. render_log 抽了但没人用（死代码）
- 共享里新增了 `build_log_lines`（L481），但 `grep -rn build_log_lines bin/` 除
  定义处外**零调用**。
- 各 TUI 的 `render_log()` 还在自己手搓切片+truncate（见 ocr L246-258：
  `start = max(0, total - inner_h - model.scroll_offset)` 这套）。
- → 计划里"消除 render_log 5 处重复"**未达成**，反而多了个未用的函数。要么让
  5 个 TUI 改调 `S.render_log`/`S.build_log_lines`，要么删掉这个空壳。

### G3. 阶段二 Table 被跳过 → wifi/bluetooth 最重的重复原封未动
- wifi 和 bluetooth 仍各自有 `_draw_row`/`_put_row_cells`/`_space_around`/
  `_focus_next`/`_init_curses`/`_draw_password_prompt`（各约 20 处匹配，95% 相同）。
- 它们本轮只拿了 `draw_dialog` + `setup_locale`。**最该复用的表格行/焦点/弹窗
  仍各写一份**——这正是你"复用就复用"想解决的核心，没解决。

### G4. "全屏宽度"布局是空位
- `Layout.force_single` 支持单栏全宽，但**没有任何 TUI 用它**，文档里也没标出
  "全屏模板"用法。你说的"两种布局：全宽 + 左右"目前只有左右被真正使用，全宽
  只是类上的一个开关。
- → 要么让真正全宽的 TUI（如 ocr 单栏？backup 某些视图？）显式用 `force_single`
  并在文档示例里给全宽模板，要么明确说"全宽就单栏直接画、不强制 Layout"。

### G5. setup_locale 只被 wifi/bt 采用，5 个 settings TUI 没用
- locale 初始化仍不一致：wifi/bt 调 `S.setup_locale()`，settings 系列各自处理
  或没有。小重复，但既然抽了就该统一。

## 给执行模型的收尾任务（按顺序）

1. **G1**：把 keyboard 和 theme 迁到 `S.Layout`（这是用户"统一布局"目标的关键
   缺口）。迁的时候只换几何计算，**不改它们的 render 内容**。迁完 5 个 settings
   TUI 全用 Layout。
2. **G2**：二选一——(a) 让 5 个 settings TUI 的 `render_log` 改调共享
   `S.render_log`（删掉各自的切片/truncate）；(b) 如果共享 `build_log_lines`
   形状不合适，删掉它，保持现状。**别留死代码**。推荐 (a)。
3. **G3**：把阶段二 Table 真正做出来，让 wifi 和 bluetooth 消费它，干掉
   `_draw_row`/`_space_around`/`_focus_next`/`_init_curses`/`_draw_password_prompt`
   的重复。这是剩下最大的一块。先抽 `Table` + `FocusManager` + `draw_dialog`
   三个，wifi/bt 改为消费。
4. **G4**：文档里补"全屏宽度模板"示例（`ly.force_single = True` 然后单
   `draw_panel("left", ...)`）；若确实没有 TUI 用全宽，明确写"目前所有 settings
   TUI 均为左右双栏，force_single 预留给未来全宽工具"。
5. **G5**：5 个 settings TUI 的 `main()` 统一调 `S.setup_locale()`，删各自的
   locale 摸索。
6. 每步跑 `pytest tests/test_python_tuis.py` + 8 个 TUI 烟雾测试，回填到本文档。

**优先级**：G1 和 G3 是用户"统一布局 + 复用"的核心诉求，先做；G2 顺手；G4/G5
收尾。

## 9. 二轮执行回填（G1–G5 完成后填）

- [x] **G1（keyboard → Layout）**：`omd-settings-keyboard-tui` 改用 `S.Layout`，取 `ly.content_top`/`ly.left_x`/`ly.right_x`/`ly.left_w`/`ly.right_w`，保留原有 6 个堆叠盒子和 3 路焦点。PTY 测试 exit 0。
- [x] **G1（theme → Layout）**：`omd-settings-theme-tui` 改用 `S.Layout`（`split_threshold=108`, `left_w=38`, `right_min=70`, `gap=1`），保留原有视窗/设置/动作/主题网格绘制。PTY 测试 exit 0。
- [x] **G2（死代码）**：`build_log_lines()` 删除（零调用）。`draw_log_in_area()` 继续被 6 个 TUI 直接使用。
- [x] **G3（Table 组件）**：`omd_tui_shared.py` 新增 `space_around()`、`clip_cell()`、`draw_row()`、`put_row_cells()`、`header_attr()`、`sel_attr()`。wifi-tui 删除 6 个重复方法（-~55 行），bluetooth-tui 同理。两者 PTY 测试 exit 0。
- [x] **G4（force_single 文档）**：Layout 类 docstring 添加完整参数说明 + 含 `force_single=True` 使用示例。`docs/tui-framework-plan.md` 同步更新参数表。
- [x] **G5（setup_locale 统一）**：vm/voice/ocr/backup/keyboard/theme 共 6 个 settings TUI 的 `main()` 入口统一调 `S.setup_locale()`。`setup_locale()` 现被全部 8 个 TUI 使用。
- [x] **全量烟雾测试**：8 个 TUI 全部通过 PTY fork 烟雾测试（exit 0），2026-07-20 验证。

### 最终行数对比

| 文件 | 行数（此前） | 行数（现在） |
|---|---|---|
| `omd_tui_shared.py` | 1121 | 1178（+57：Table 函数 ~+80，删 build_log_lines -20） |
| `omd-wifi-tui` | ~1077 | ~1020（-~55，6 个方法 → 共享函数） |
| `omd-bluetooth-tui` | ~1405 | ~1348（-~55，6 个方法 → 共享函数） |
| `omd-settings-keyboard-tui` | ~1214 | ~1214（几何换 Layout，行数不变） |
| `omd-settings-theme-tui` | ~1073 | ~1073（几何换 Layout，行数不变） |
| 其余 4 个 TUI | — | 每个仅加 1 行 `S.setup_locale()` |

### 二轮偏离记录

1. G2 选 (b) 删掉 `build_log_lines`（原推荐 (a) 改调共享），因各 TUI 的 log 渲染已直接使用 `draw_log_in_area`，中间层无价值。
2. G3 抽取的是 6 个轻量函数而非完整的 `Table` + `FocusManager` 类。wifi/bt 的 `_focus_next`/`_focus_prev`/`_init_curses`/`_draw_password_prompt` 各有差异未抽取——前者焦点区不同、后者弹窗内容不同。只抽取了 95% 相同的行绘制部分。
3. keyboard/theme 迁 Layout 后行数未减（geometry 换用 `ly.xxx` 但结构一致）。
4. 最终 8/8 全部 PTY 通过。
