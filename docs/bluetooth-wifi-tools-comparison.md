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

## OMD 最终方案：omd-bluetooth-tui + omd-wifi-tui

### 为什么不用 bluetui / impala 原样

| 工具 | 原因 |
|------|------|
| **bluetui** | 不支持 **Legacy Pairing**（PIN 显示/输入），MINILA-R 等老键盘无法配对。我们在 `bluetoothctl` agent 上包 TUI。 |
| **impala** | 只支持 **iwd** 后端。OMD/多数桌面发行版默认是 **NetworkManager**；impala 与 NM 冲突。我们用 `nmcli`（类似 impala-nm / nmtui）。 |

### 文件

| 文件 | 说明 |
|------|------|
| `bin/omd-bluetooth-tui` | Python curses 蓝牙 TUI（BlueZ / bluetoothctl） |
| `bin/omd-wifi-tui` | Python curses WiFi TUI（NetworkManager / nmcli） |
| `bin/omd-launch-bluetooth` | 启动器（终端 + 浮动窗口 app-id） |
| `bin/omd-launch-wifi` | 启动器 |
| `hypr/bindings.lua` | `SUPER+CTRL+B` / `SUPER+CTRL+W` |

### 依赖（分享给别人前请写清楚）

| 组件 | 硬依赖 | 可选 |
|------|--------|------|
| 两者 | Python ≥ 3.10、curses、UTF-8 终端 | Nerd Font（图标） |
| 蓝牙 | **BlueZ**（`bluetoothctl`）、`bluetooth` 服务 | `rfkill` |
| WiFi | **NetworkManager**（`nmcli`）、NM 管理无线网卡 | `rfkill` |

**不支持 / 不会自动适配：**

- 纯 **iwd + impala**、纯 **wpa_supplicant**（无 NM）→ WiFi TUI 启动即报错退出
- **WPA-Enterprise / 802.1X**（学校/公司 WiFi）→ 请用 `nmtui` / Settings
- **Hidden SSID**、热点/AP 模式、VPN、有线
- 多蓝牙适配器切换（只用 default controller）
- 无 TTY / 非交互环境

### 蓝牙功能

- 全屏设备列表，`j/k` 导航，`Enter` 配对/连接
- **Legacy Pairing**：显示 PIN，用户在外设键盘上输入
- **SSP**：自动确认 passkey
- `d` 断开，`f` 忘记，`s` 扫描，`t` 信任，`q` 退出
- 配对成功后自动 `trust` + `connect`

### WiFi 功能

- Saved / Available / Status 三区（布局对齐 bluetui 风格）
- `Enter` 连接/断开，`s` rescan，`t` 射频开关，`f` 忘记配置
- 安全网络弹出密码框（WPA-PSK）；已保存配置走 `connection up uuid`
- SSID 去重（同名保留最强信号）
