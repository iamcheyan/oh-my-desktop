# Python TUI 工具一览

Sumika Shell 的设置工具集中在 `bin/` 下，按入口分三类：

- **工具盒（bar 弹出菜单）**：WiFi、蓝牙
- **设置中心（`sumika-settings-tui` 路由）**：键盘、语音、虚拟机、主题、备份、OCR
- **独立命令行工具**：OCR 识别

## 工具盒类

| 文件 | 说明 |
|---|---|
| `bin/sumika-wifi-tui` | WiFi 网络管理器 TUI。扫描网络、连接/断开、信号强度、频段显示。从 bar 的 WiFi 按钮弹出。 |
| `bin/sumika-bluetooth-tui` | 蓝牙配对与连接 TUI。发现设备、配对、连接、断开。显示设备类型标签、RSSI、适配器信息。从 bar 的蓝牙按钮弹出。 |

## 设置中心类

由 `bin/sumika-settings-tui`（bash 路由）按子命令分派到各个 Python TUI：

| 文件 | 说明 | 路由键 |
|---|---|---|
| `bin/sumika-settings-keyboard-tui` | 键盘按键映射 TUI。视觉按键拾取器、Fn 模式切换、预置管理、多面板布局。 | `keyboard` |
| `bin/sumika-settings-voice-tui` | 语音输入设置 TUI。录音试讲、语音检测、峰值电平、最近录音列表、状态显示。 | `voice` |
| `bin/sumika-settings-vm-tui` | Windows 虚拟机设置 TUI。按状态显示的详细视图（安装/启动/就绪/停止/修复）、环境依赖检查。 | `windows-vm` |
| `bin/sumika-settings-theme-tui` | 主题选择 TUI。色板网格、当前主题高亮、键盘/鼠标导航。详见 [主题系统文档](../features/theme-system.md)。 | `theme` |
| `bin/sumika-settings-backup-tui` | 文件共享/备份设置 TUI。SMB 备份配置、连接测试、手动备份执行。双列布局。 | `backup` |
| `bin/sumika-settings-ocr-tui` | OCR 设置 TUI。检测 PaddleOCR/ONNX Runtime/模型缓存状态、安装向导、测试功能。 | `ocr` |

### 配套 shell 辅助脚本

这些路由分发的 shell 辅助脚本（非 Python，但属于设置工具链）：

| 文件 | 说明 |
|---|---|
| `bin/sumika-settings-keyboard` | 键盘映射的持久化读写、预置列表查询 |
| `bin/sumika-settings-voice` | 语音模型下载、状态查询 |
| `bin/sumika-settings-windows-vm` | Windows VM 状态/操作查询 |
| `bin/sumika-settings-theme` | 主题列表查询、应用主题 |
| `bin/sumika-settings-ocr` | OCR 状态检测、安装、测试触发 |
| `bin/sumika-launch-settings-ocr-tui` | 从终端打开 OCR 设置 TUI（窗口规则专用） |

## 独立工具

| 文件 | 说明 |
|---|---|
| `bin/sumika-ocr` | 对给定图片执行文字识别（PaddleOCR PP-OCRv6），输出逐行识别文本到 stdout。 |

## 技术栈

全部 Python TUI 共用以下基础设施（位于 `bin/sumika_tui_framework.py`）：

- **TUI 框架**：Python `curses`，统一窗口管理、鼠标支持、事件循环
- **视觉系统**：[`tui-style-system.md`](tui-style-system.md) — 颜色、边框、间距约定
- **布局系统**：[`../settings/settings-layout-system.md`](../settings/settings-layout-system.md) — QML 面板布局契约
- **Python 布局系统**：[`tui-framework-plan.md`](tui-framework-plan.md) — Python TUI 的 Layout 模板类与架构
- **启动方式**：`bin/sumika-settings-tui` bash 路由 → Python 子进程

### 共享模块 `bin/sumika_tui_framework.py`

| 组件 | 用途 | 所有 TUI 共用 |
|---|---|---|
| `init_colors()` / 16 个颜色常量 | 统一配色 | ✅ |
| `draw_border()` / `draw_thick_border()` | 边框绘制 | ✅ |
| `draw_hero()` / `draw_help_bar()` | 英雄栏、帮助栏 | ✅ |
| `hero_line()` / `primary_line()` / `action_line()` / ... | 视觉组件工厂 | ✅ |
| `StatusModel` | 模型基类 | 6 个 TUI |
| `RefreshCounter` | 后台刷新计数器 | 6 个 TUI |
| `run_tui_loop()` | 事件循环 | 6 个 TUI |
| `run_cmd_bg()` / `drain_callbacks()` | 后台命令执行 | ✅ |
| `scroll_key()` | 快捷键滚动处理 | ✅ |
| `draw_dialog()` | 居中弹窗 | ✅ |
| `setup_locale()` | 语言环境初始化 | ✅ |
| **`Layout` 类** | 标准两栏几何模板 | 6 个 TUI（vm/voice/ocr/backup/keyboard/theme） |
| `draw_row()` / `put_row_cells()` / `space_around()` / `clip_cell()` | 表格行绘制原语 | wifi, bluetooth |
| `handle_tab()` | Tab 焦点切换 | 按需 |

### 使用 Layout 模板的 TUI

```python
def view(stdscr, model):
    ly = S.Layout(stdscr)        # 创建模板
    ly.left_w = 36                # 覆盖默认值
    ly.compute()                  # 计算所有几何坐标
    ly.draw_hero(stdscr, hero_data)  # 标准英雄栏
    ly.draw_panel("left", "Status", lines, focus=(m.focus==0))
    ly.draw_panel("right", "Details", lines, focus=(m.focus==1))
    ly.draw_help(stdscr, *help_items(m))  # 标准帮助栏
    S.finish_frame(stdscr)
```

### 使用共享 Table 函数的 TUI

wifi-tui 和 bluetooth-tui 未用 `Layout`，但通过 `S.draw_row()`/`S.put_row_cells()`/
`S.space_around()`/`S.clip_cell()`/`S.header_attr()`/`S.sel_attr()` 共享行绘制逻辑。

### 未使用 Layout 的 TUI

无当前未使用的——6 个 settings TUI 全部覆盖。wifi/bluetooth 作为 OOP 类不使用 Layout 但使用共享 Table 函数。

全部 TUI 共用共享模块中的颜色、边框、英雄栏、帮助栏、文本工具、事件循环等底层组件。

### 新建 TUI 速查

新建设置 TUI 或工具盒 TUI 时，参考 [`tui-framework-plan.md`](tui-framework-plan.md) 末尾的
「[新建 TUI 实践指南]」一节，包含：

- 骨架模板代码（`StatusModel` + `run_tui_loop` / 自写 OOP）
- 5 种布局模式样例（等高二栏 / 堆叠 / 单栏全宽 / 不等高 / 带预览）
- 共享组件速查表（所有 TUI 通用、Settings 额外、Toolbox 额外）
- 9 条口诀

[新建 TUI 实践指南]: tui-framework-plan.md#新建-tui-实践指南
