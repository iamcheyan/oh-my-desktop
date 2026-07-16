# Bluetooth & WiFi 管理工具对比

## omarchy 的方案（现成的轮子）

### 蓝牙：bluetui + bluez
- **bluetui**：终端 TUI 工具，扫描/配对/连接/断开，开箱即用
- 启动命令：`rfkill unblock bluetooth` → `bluetui`
- 快捷键：`SUPER + CTRL + B`
- Waybar 点击：`omarchy-launch-bluetooth`

### WiFi：iwd + impala + systemd-networkd
- **iwd**：WiFi 后台守护进程（替代 wpa_supplicant，更轻量）
- **impala**：终端 TUI 工具，扫描/连接 WiFi，与 iwd 交互
- **systemd-networkd** + **systemd-resolved**：网络配置和 DNS
- 启动命令：`rfkill unblock wifi` → `impala`
- 快捷键：`SUPER + CTRL + W`
- Waybar 点击：`omarchy-launch-wifi`

### 架构特点
1. 全部用**终端 TUI 工具**（bluetui / impala），没有自定义 QML UI
2. 通过 `rfkill` 控制射频开关
3. 后台用标准 stack（bluez / iwd），不自己写 Python 脚本
4. TUI 通过 `omarchy-launch-or-focus-tui` 管理窗口焦点
5. Hyprland 窗口规则将 bluetui/impala 设为浮动窗口

---

## OMD 当前的方案（自己造轮子）

### 蓝牙
- 自定义 `BluetoothPage.qml`（QML 设置页面）
- 自定义 `omd-bluetooth-connect` shell/Python 脚本
- 通过 `Process` 解析 stdout 获取配对码和状态
- 问题：配对码显示不稳定，Quickshell 缓存状态不准确，脚本有竞态条件

### WiFi
- 自定义 `WifiDialog.qml`（QML 弹窗）
- 自定义 `Network.qml` 服务（通过 NetworkManager 或直接 iwd）
- 问题：键盘快捷键、聚焦管理、状态同步都需要自己维护

---

## 建议

| 功能 | 当前 OMD 方案 | omarchy 方案 | 推荐 |
|------|--------------|-------------|------|
| 蓝牙管理 | 自定义 QML + Python 脚本 | bluetui TUI | bluetui |
| WiFi 管理 | 自定义 QML Dialog | impala + iwd | impala + iwd |
| 蓝牙音频 | - | bluez + WirePlumber A2DP 自动连接 | 沿用 |
| 网络配置 | - | systemd-networkd + systemd-resolved | 沿用 |
| 防火墙 | - | ufw | 沿用 |

**核心思路**：把蓝牙和 WiFi 的设置交给专门的 TUI 工具，OMD 只需要在 bar 上显示状态图标 + 点击启动对应 TUI，不需要自己实现配对/WiFi 扫描逻辑。

对比 OMD 目前的做法（BluetoothPage.qml 几百行 + 自定义脚本的各种 bug），bluetui 和 impala 是成熟的项目，社区维护，配对码显示、扫描、连接管理都经过充分测试。

---

## OMD 最终方案：omd-bluetooth-tui

### 为什么不用 bluetui

bluetui 不支持 **Legacy Pairing**（PIN 码输入），导致 MINILA-R Convertible 等老式蓝牙键盘无法配对。
bluetoothctl 的 `agent on` 支持所有配对方式（SSP + Legacy），所以我们在 bluetoothctl 之上包了一层 curses TUI。

### 文件

| 文件 | 说明 |
|------|------|
| `bin/omd-bluetooth-tui` | Python curses TUI 脚本 |
| `bin/omd-launch-bluetooth` | 启动器（在终端中打开 TUI） |
| `hypr/bindings.lua` | `SUPER + CTRL + B` 快捷键 |
| `quickshell/modules/bar/BarStatusPopup.qml` | bar 蓝牙按钮启动 TUI |

### 功能

- 全屏设备列表，`j/k` 导航，`Enter` 配对/连接
- `[*]` = 已连接，`[~]` = 已配对，`[ ]` = 可配对
- **Legacy Pairing**：显示 PIN 码提示，用户在键盘上输入
- **Secure Simple Pairing**：自动确认 passkey
- `d` 断开，`f` 忘记设备，`r` 扫描，`q` 退出
- 配对成功后自动 `trust` + `connect`
