# WiFi 自动恢复链路 — 设计与审计

> 记录 2026-08-08 排查"合盖/断连后 WiFi 5 小时不自动恢复"问题时整理的完整
> 链路审计。本文档供以后维护 WiFi watchdog / `fix_connection` 时参考。

## 1. 背景事件

2026-08-08 02:39:01，扩展器 Extender-A-BB40 掉线，wpa_supplicant 判定链路
失效主动断开。断开后 NetworkManager 的 autoconnect 反复抢连优先级最高的
Extender-A-BB40 (priority=100)，连不上也不回落到主路由 C40FA623BF09-2G
(priority=50)，导致断网 5 小时直到手动连接。

根因有三层：
1. **autoconnect 优先级配反** — Extender 100 > 主路由 50，NM 反复抢扩展器。
2. **空壳 profile 抢占** — `C40FA623BF09-5G 1` 等 profile 有 key-mgmt 但无
   PSK，`secrets are required` 连不上，却显示为"已保存"并抢占连接。
3. **watchdog 用 `nmcli connection up id`** — 该命令不能切换已关联的 SSID
   (NM 拒绝 "base connection interrupted")，wpa 卡在死 SSID 上时永远切不走。

## 2. 完整自动恢复链路

```
healthPollTimer (5s, repeat)
  → Network.qml: update()
  → watchdogEvaluate()
      │
      ├─ wifiStatus === "connected"
      │    → 清零 watchdogDisconnectCount / watchdogFailCount
      │    → 记录 lastConnectedSsid
      │
      └─ wifiStatus !== "connected" (disconnected / limited / disabled)
           → watchdogDisconnectCount += 1
           → 累计 ≥ 3 次 (~15s) → watchdogRecovering = true
           → watchdogFixProc: sumika-wifi fix
                │
                ├─ fix_connection() [sumika_wifi_ops.py]
                │    Step 0: service_check — NM / 设备 / rfkill / radio
                │    Step 1: rescan → auto_fix_security_profile (WPA3)
                │            → purge_empty_profiles (删空壳)
                │    Step 2: 验证当前连接 (gateway ping + route + DNS + internet)
                │            → 可达 → return True (保留)
                │            → 不可达 → disconnect 释放设备
                │    Step 3: attempt_round("1") — ranked candidates
                │            → connect_network (device wifi connect 原子切换)
                │            → 每个候选 ping gateway 验证
                │    Step 4: 全失败 → radio off/on 硬重置 → attempt_round("2")
                │
                ├─ 成功 → 清零 watchdogRecovering / FailCount / DisconnectCount
                │          + 刷新 knownWifiNames / savedWifiProfiles
                └─ 失败 → watchdogRetryTimer (15s)
                          → 清零 watchdogRecovering / DisconnectCount
                          → 下一轮 healthPoll 重新触发，永不放弃
```

### 2.1 关键设计决策

| 决策 | 原因 |
|---|---|
| watchdog 委托 `fix_connection` 而非自己逐个试 | `connection up` 不能切换网络；`fix_connection` 用 `device wifi connect` 原子切换，且包含 security audit + purge + radio reset |
| 断连 3 次 (~15s) 才触发恢复 | 容忍短暂 roaming blip，避免与 NM autoconnect 竞争 |
| 恢复期间抑制 NM autoconnect | 防止 NM 在候选间隙抢连别的 autoconnect=yes 网络 |
| 恢复失败后 15s 重试，无上限 | 永不放弃 — 路由器可能恢复、信号可能改善 |
| `wifiStatus="limited"` 视为非 connected | limited (连着但无 internet) 也触发恢复 |

### 2.2 `fix_connection` 恢复流程详解

**Step 0 — service_check**: 验证 NetworkManager 运行中、WiFi 设备存在、
rfkill 未阻塞、radio 开启。任一不满足则停止恢复（不能修的不要硬修）。

**Step 1 — 扫描 + 审计 + 清理**:
- `rescan_wifi()` 刷新扫描缓存。
- 对每个可见的已保存 profile 调 `auto_fix_security_profile`：WPA2/WPA3
  transition-mode AP 的 `wpa-psk` profile 自动改为 `sae`（见
  WIFI-WPA3-AUTOFIX.md）。
- `purge_empty_profiles()` 删除无 PSK 的空壳 profile（见 §3）。

**Step 2 — 验证当前连接**:
- 有网关 → ping 3 次 → 0% loss → 检查 default route + DNS + internet probe。
- 全通 → "Active connection verified"，返回 True（保留）。
- DNS/route 不通但 gateway 可达 → "WiFi link is up, but DNS needs attention"，
  返回 False（不断开工作链路，但报告问题）。
- Gateway 不通 → "preserving active link"，返回 True（不因暂时 ICMP 丢包
  断开可能正在恢复的链路）。
- 无网关 → 断开当前连接释放设备，进入候选尝试。

**Step 3 — attempt_round("1")**: `_ranked_candidates` 排序可见的
autoconnect profile（priority*2 + signal + 5GHz bonus，刚失败的 SSID 降权 -30），
逐个用 `connect_network`（`device wifi connect` 原子切换）尝试，每个连上后
ping gateway 验证。第一个成功即返回。

**Step 4 — radio reset fallback**: 全部候选失败 → `set_wifi_radio(false)` →
2s → `set_wifi_radio(true)` → 4s → `nmcli connection reload` → 重试
`attempt_round("2")`。仍失败 → 返回 False，watchdog 15s 后重新触发。

## 3. 空壳 profile 清理 (empty-shell purge)

### 3.1 问题

NM 在用户**发起连接的瞬间**就创建 profile；如果用户取消密码输入框，profile
留下但 PSK 为空（`psk-flags=0`、`psk` 为空）。这些空壳：

- 在 UI 显示为"已保存"，但点击后 `secrets are required` 连不上；
- 同一 SSID 的多个空壳（`Foo`、`Foo 1`、`Foo 2`）互相抢占，连上的被没密码
  的切走；
- autoconnect 时反复失败，拖累整网恢复。

### 3.2 检测

`_profile_has_psk(uuid)` 用 `nmcli --show-secrets -g psk` 读取真实 PSK：
- 普通 `nmcli -g psk` 永远显示 `<hidden>`，无法区分空与非空。
- `--show-secrets` 返回真实值：非空 = 有密码，空 = 空壳。
- **Fail-safe**: secrets 读取失败（rc != 0，权限/polkit/NM 重启）时返回
  `True`（假设有密码）。返回 `False` 会导致 `purge_empty_profiles` 删掉所有
  profile — 灾难性故障。
- Open 网络（无 key-mgmt）返回 True（不需要 PSK）。
- Enterprise（EAP/802.1X）返回 False（需要 nmtui，不是 PSK）。

`get_saved_networks()` 的 `has_credentials` 字段反映真实 PSK 存在与否。
UI 侧（`Network.qml` 的 `knownWifiNames` 和 `savedWifiProfiles`）只展示
`has_credentials=true` 的 profile，空壳不出现在 WiFi 列表和设置页。

### 3.3 清理

`purge_empty_profiles(on_log)` 删除所有 `has_credentials=false` 的 profile
（当前活动连接除外）。在 `fix_connection` Step 1 审计后自动执行；也可手动
`sumika-wifi purge-empty` 触发。

### 3.4 安全保障

| 保护 | 机制 |
|---|---|
| 不删当前连接 | `get_active_connection()` 返回活动连接名，跳过它 |
| secrets 读取失败不误删 | `_profile_has_psk` fail-safe 返回 True |
| 有密码的 profile 不删 | `has_credentials=True` 跳过 |

## 4. autoconnect 优先级

NM 断开后按 `autoconnect-priority` 从高到低选 profile 重连。`autoconnect-retries`
控制每个 profile 的重试次数（`0` = forever，`-1` = 默认 forever）。

### 4.1 本机配置（2026-08-08 修复后）

```
C40FA623BF09-2G       priority=50, retries=4   ← 主路由，最高
C40FA623BF09-5G       priority=50, retries=4
Extender-A-BB40       priority=10, retries=4   ← 扩展器，低于主路由
Extender-A-BB40-WPA3  priority=10, retries=4
```

### 4.2 规则

- **主路由优先级 > 扩展器**：断开后优先连主路由，不抢扩展器。
- **retries=4（有限）**：连不上的 profile 4 次后临时禁用，NM 轮转到下一个。
  不会像 `retries=0`（forever）那样卡在一个连不上的 profile 上空转。
- NM 在 profile 被禁用后约 5 分钟自动重新允许尝试，不会永久锁死。

## 5. 审计检查清单

维护 WiFi 恢复链路时需确认以下不变量：

| 检查点 | 期望 | 文件 |
|---|---|---|
| watchdog 触发 | `healthPollTimer`(5s) → `watchdogEvaluate` → 断连 3 次 → `sumika-wifi fix` | Network.qml |
| watchdog 防重入 | `watchdogRecovering` 在触发前 true，成功/失败后清零 | Network.qml |
| watchdog 无放弃上限 | 无 `watchdogMaxFail`，失败 15s 后无限重试 | Network.qml |
| watchdog 用 fix_connection | `watchdogFixProc.command: ["sumika-wifi", "fix"]`，不是 `nmcli connection up` | Network.qml |
| fix_connection 原子切换 | `connect_network` 用 `device wifi connect`，不是 `connection up` | sumika_wifi_ops.py |
| fix_connection 抑制 autoconnect | `device set <dev> autoconnect no`，done() 恢复 | sumika_wifi_ops.py |
| _profile_has_psk fail-safe | `rc != 0 → return True`（不误删） | sumika_wifi_ops.py |
| purge 跳过当前连接 | `if d.get("connected") or d.get("name") == active_name: continue` | sumika_wifi_ops.py |
| has_credentials 过滤 UI | `knownWifiNames` 和 `savedWifiProfiles` 只收 `has_credentials=true` | Network.qml |
| limited 触发恢复 | `wifi_status="limited"` ≠ "connected" → watchdog 累计 | sumika_wifi_ops.py |

## 6. 排查命令速查

```sh
# 当前 watchdog 状态（QML 属性，需从 bar 进程查）
# 无直接命令行接口；看 bar 日志：
journalctl --user -u sumika-bar.service --since "10 min ago" | grep -i watchdog

# 手动触发完整恢复
sumika-wifi fix --stream    # 实时日志
sumika-wifi fix             # JSON 结果

# 手动清理空壳 profile
sumika-wifi purge-empty

# 查看 autoconnect 优先级和重试次数
nmcli -t -f NAME,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY connection show | grep wireless

# 查看 profile 是否有真实 PSK
nmcli --show-secrets -g 802-11-wireless-security.psk connection show <uuid>
# 非空 = 有密码；空 = 空壳

# 查看已保存 profile 的 has_credentials
sumika-wifi list-saved | python3 -m json.tool

# 查看当前 inhibitor (keep-awake)
systemd-inhibit --list | grep keep-awake

# 断连事件时间线
journalctl --since "1 hour ago" | grep -E 'CTRL-EVENT-(DIS)?CONNECTED|state change.*->|reason'
```

## 7. 相关文件

| 文件 | 职责 |
|---|---|
| `quickshell/services/Network.qml` | watchdog 检测 + 触发；UI 列表过滤 |
| `quickshell/modules/wifi/bin/sumika_wifi_ops.py` | `fix_connection`、`purge_empty_profiles`、`_profile_has_psk`、`auto_fix_security_profile` |
| `quickshell/modules/wifi/bin/sumika-wifi` | CLI 入口（`fix`、`purge-empty`、`list-saved` 等） |
| `quickshell/modules/wifi/WIFI-WPA3-AUTOFIX.md` | WPA3 transition-mode 自动修复（`auto_fix_security_profile`） |