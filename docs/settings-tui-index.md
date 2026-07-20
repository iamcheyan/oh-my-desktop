# Python 设置工具一览

OMD 的设置工具集中在 `bin/` 下，按入口分三类：

- **工具盒（bar 弹出菜单）**：WiFi、蓝牙
- **设置中心（`omd-settings-tui` 路由）**：键盘、语音、虚拟机、主题、备份、OCR
- **独立命令行工具**：OCR 识别

## 工具盒类

| 文件 | 最近提交数 | 说明 |
|---|---|---|
| `bin/omd-wifi-tui` | 10 | WiFi 网络管理器 TUI。扫描网络、连接/断开、信号强度、频段显示。从 bar 的 WiFi 按钮弹出。 |
| `bin/omd-bluetooth-tui` | 22 | 蓝牙配对与连接 TUI。发现设备、配对、连接、断开。显示设备类型标签、RSSI、适配器信息。从 bar 的蓝牙按钮弹出。 |

## 设置中心类

由 `bin/omd-settings-tui`（bash 路由）按子命令分派到各个 Python TUI：

| 文件 | 最近提交数 | 说明 | 路由键 |
|---|---|---|---|
| `bin/omd-settings-keyboard-tui` | 23 | 键盘按键映射 TUI。视觉按键拾取器、Fn 模式切换、预置管理、多面板布局。 | `keyboard` |
| `bin/omd-settings-voice-tui` | 10 | 语音输入设置 TUI。录音试讲、语音检测、峰值电平、最近录音列表、状态显示。 | `voice` |
| `bin/omd-settings-vm-tui` | 8 | Windows 虚拟机设置 TUI。按状态显示的详细视图（安装/启动/就绪/停止/修复）、环境依赖检查。 | `windows-vm` |
| `bin/omd-settings-theme-tui` | 13 | 主题与外观设置 TUI。壁纸 ASCII 预览、主题色板显示、模式/特效选择、鼠标支持。 | `theme` |
| `bin/omd-settings-backup-tui` | 34 | 文件共享/备份设置 TUI。SMB 备份配置、连接测试、手动备份执行。双列布局。 | `backup` |
| `bin/omd-settings-ocr-tui` | 1 | OCR 设置 TUI。检测 PaddleOCR/ONNX Runtime/模型缓存状态、安装向导、测试功能。 | `ocr` |

### 配套 shell 辅助脚本

这些路由分发的 shell 辅助脚本（非 Python，但属于设置工具链）：

| 文件 | 说明 |
|---|---|
| `bin/omd-settings-keyboard` | 键盘映射的持久化读写、预置列表查询 |
| `bin/omd-settings-voice` | 语音模型下载、状态查询 |
| `bin/omd-settings-windows-vm` | Windows VM 状态/操作查询 |
| `bin/omd-settings-theme` | 主题列表查询、应用主题 |
| `bin/omd-settings-ocr` | OCR 状态检测、安装、测试触发 |
| `bin/omd-launch-settings-ocr-tui` | 从终端打开 OCR 设置 TUI（窗口规则专用） |

## 独立工具

| 文件 | 最近提交数 | 说明 |
|---|---|---|
| `bin/omd-ocr` | 1 | 对给定图片执行文字识别（PaddleOCR PP-OCRv6），输出逐行识别文本到 stdout。 |

## 技术栈

全部 Python TUI 共用以下基础设施（位于 `share/` 或脚本内置）：

- **TUI 框架**：Python `curses`，统一窗口管理、鼠标支持、事件循环
- **视觉系统**：`docs/settings-tui-visual-system.md` — 颜色、边框、间距约定
- **布局系统**：`docs/settings-layout-system.md` — 面板分割、焦点导航
- **启动方式**：`bin/omd-settings-tui` bash 路由 → Python 子进程

## 相关设计文档

- `docs/settings-center.md` — 设置中心总架构
- `docs/settings-tui-go.md` — 早期 Go 版本的 TUI 设计（已迁移到 Python）
- `docs/settings-tui-visual-system.md` — TUI 视觉规范
- `docs/settings-layout-system.md` — 布局与焦点系统
- `docs/voice-settings-redesign.md` — 语音设置页设计
- `docs/windows-vm-settings-layout.md` — 虚拟机设置布局
- `docs/appearance-settings-layout.md` — 外观设置布局
- `docs/keyboard-remap-settings-layout.md` — 键盘映射布局
- `docs/network-settings-layout.md` — 网络设置布局
- `docs/settings-panel-ux-optimization.md` — 面板 UX 优化
