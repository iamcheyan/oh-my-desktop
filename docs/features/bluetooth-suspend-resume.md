# Bluetooth 挂起恢复问题（BCM4377 / Apple Silicon）

## 症状

合上笔记本盖子（系统挂起）再打开后，蓝牙外设（MX 鼠标、键盘等）无法重连。
`bluetoothctl info <mac>` 显示 `Connected: no`，设备 `Paired: yes` / `Trusted: yes`
但无论怎么操作都不连接。只有重启电脑或手动重载内核模块才能恢复。

## 根因

### 硬件

Apple Silicon 笔记本（MacBook）的蓝牙控制器是 Broadcom **BCM4377**，
内核驱动为 `hci_bcm4377`。在 Asahi Linux 上，该控制器的固件在系统挂起
（suspend to RAM）后进入不一致状态：

1. 恢复后 `bluetoothd` 尝试重连可信设备 → 控制器返回
   **`Authentication Failed (0x05)`**（链路密钥状态损坏）。
2. 手动 `bluetoothctl connect <mac>` 触发控制器固件崩溃 → 控制器直接断电
  （`PowerState: on-disabling → off`）。
3. 内核日志出现 **`command 0x0c01 tx timeout`** + **`-110`**（ETIMEDOUT），
   说明控制器固件已无响应。

### 为什么简单的修复无效

| 尝试 | 结果 | 原因 |
|------|------|------|
| `bluetoothctl power off/on` | 无效 | 固件已卡死，power cycle 无法重置 |
| `bluetoothctl connect <mac>` | 控制器断电 | 触发固件崩溃 |
| `systemctl restart bluetooth` | 控制器不恢复 | 只重启用户态守护进程，不重载固件 |
| `rfkill block/unblock bluetooth` | 仍报错 `Bad flag given` | rfkill 不重置固件状态 |

**唯一有效的手段**：重载内核模块 `hci_bcm4377`，强制重新加载控制器固件：

```bash
sudo modprobe -r hci_bcm4377
sudo modprobe hci_bcm4377
```

模块重载后控制器重新初始化，BlueZ 自动重连所有 trusted+paired 设备。

## 修复方案

三层修复，从系统级到用户级：

### 1. systemd 恢复钩子（系统级，root）

`/etc/systemd/system-sleep/10-bluetooth-bcm4377.sh`：

```bash
#!/bin/bash
case "$1/$2" in
    post/*)
        modprobe -r hci_bcm4377 2>/dev/null || true
        sleep 0.5
        modprobe hci_bcm4377 2>/dev/null || true
        ;;
esac
```

systemd 在系统恢复（resume）后以 root 身份执行 `/etc/systemd/system-sleep/`
下的脚本。此钩子在 hypridle 的 `after_sleep_cmd` 之前运行，确保控制器在
用户会话恢复前就已就绪。

仓库副本：`share/system-sleep/10-bluetooth-bcm4377.sh`，由 `Init.sh` 的
`install_session_files()` 自动安装。

### 2. BlueZ 配置（系统级）

`/etc/bluetooth/main.conf` 取消注释以下三项：

```ini
AutoEnable=true              # 控制器发现时自动上电
ReconnectAttempts=7          # 链路断开后重试 7 次
ReconnectIntervals=1,2,4,8,16,32,64  # 重试间隔（秒）
```

`AutoEnable=true` 确保模块重载后控制器自动上电；
`ReconnectAttempts` + `ReconnectIntervals` 让 BlueZ 在模块重载后主动重连
trusted 设备，不依赖用户级脚本。

### 3. 用户级恢复兜底（omarchy-system-wake）

`share/bin/omarchy-system-wake`（由 hypridle `after_sleep_cmd` 调用）：

```bash
bt_reconnect() {
    # 等待 systemd 钩子重载模块 + BlueZ 初始化
    sleep 3
    # 对每个 trusted+paired+disconnected 设备尝试连接（带 8 秒超时）
    bluetoothctl devices Paired | while read -r _ mac _; do
        # ... 检查 trusted + connected，timeout 8 bluetoothctl connect
    done
}
bt_reconnect &
```

这是 belt-and-suspenders 兜底：systemd 钩子 + BlueZ 配置通常已自动重连，
此脚本补漏那些 BlueZ 没自动重连的设备。`timeout 8` 防止对睡眠/关闭的
设备阻塞恢复流程（之前没加超时导致 134 秒卡死）。

## 执行顺序（恢复时）

```
1. 系统恢复（resume）
2. systemd 执行 /etc/systemd/system-sleep/10-bluetooth-bcm4377.sh
   → modprobe -r hci_bcm4377 && modprobe hci_bcm4377（root，重载固件）
3. hypridle 执行 after_sleep_cmd = sleep 1 && sumika-wake
   → omarchy-system-wake（用户级，兜底重连）
4. BlueZ AutoEnable + ReconnectAttempts 自动重连 trusted 设备
5. omarchy-system-wake bt_reconnect 补漏未重连的设备
```

## 验证

### 手动验证恢复钩子

```bash
# 模拟恢复（不实际挂起）
sudo /etc/systemd/system-sleep/10-bluetooth-bcm4377.sh post suspend
sleep 3
bluetoothctl info <mac> | grep Connected
```

### 检查配置

```bash
grep -E '^(AutoEnable|ReconnectAttempts|ReconnectIntervals)' /etc/bluetooth/main.conf
# 应输出：
# ReconnectAttempts=7
# ReconnectIntervals=1,2,4,8,16,32,64
# AutoEnable=true
```

### 实际测试

合上盖子等 5 秒再打开，移动鼠标，应在 5-10 秒内自动重连。

## 受影响硬件

- **控制器**：Broadcom BCM4377（Apple Silicon，MacBook 2020+）
- **驱动**：`hci_bcm4377`（内核模块）
- **平台**：Asahi Linux（aarch64）
- 非 BCM4377 平台不受影响（钩子 `modprobe -r` 对不存在的模块是无操作）

## 手动恢复（如果自动修复失败）

```bash
# 重载 BCM4377 模块
sudo modprobe -r hci_bcm4377 && sudo modprobe hci_bcm4377
# 等待 BlueZ 自动重连，或手动连接
sleep 2
bluetoothctl connect <mac>
```

## 文件清单

| 文件 | 位置 | 作用 |
|------|------|------|
| `10-bluetooth-bcm4377.sh` | `/etc/systemd/system-sleep/` | 恢复时重载内核模块（root） |
| `10-bluetooth-bcm4377.sh` | `share/system-sleep/` | 仓库副本，Init.sh 安装 |
| `main.conf` | `/etc/bluetooth/` | BlueZ 自动重连配置 |
| `omarchy-system-wake` | `share/bin/` | 用户级恢复兜底 |
| Init.sh `install_session_files()` | 根目录 | 安装系统钩子 |