# WiFi WPA3 Transition-Mode 连接失败 — 根因与自动修复

> 记录 2026-08-03 排查并修复的 C40FA623BF09-5G/2G「手动连不上、重启后才能连上」
> 问题。本文档供以后遇到类似「AP 广播 WPA2/WPA3、连接循环失败」时参考。

## 1. 症状

- `C40FA623BF09-5G` / `C40FA623BF09-2G` 手动连接**必失败**;重启系统(或 NM)后
  又能连上。
- 自动恢复(`fix_connection`)反复尝试也连不上,日志里每个候选都失败。
- 其它网络(Extender 系列)一切正常。

## 2. 诊断证据

### 2.1 AP 广播的安全模式与 profile 配置不匹配

```
$ nmcli -t -f SSID,BSSID,SIGNAL,SECURITY device wifi list | grep C40FA623BF09
C40FA623BF09-5G:C4\:0F\:A6\:23\:BF\:0A:100:WPA2 WPA3:5180 MHz   ← 主 AP(5G)
C40FA623BF09-2G:C4\:0F\:A6\:23\:BF\:08:99:WPA2 WPA3:2412 MHz   ← 主 AP(2G)
C40FA623BF09-5G:68\:E1\:DC\:19\:BB\:43:74:WPA2:2452 MHz        ← Extender 中继(WPA2-only)
```

主 AP 广播 **`WPA2 WPA3`**(transition mode,同时声明 WPA2 与 WPA3 能力),
但保存的 profile 配置的是:

```
$ nmcli -f 802-11-wireless-security.key-mgmt connection show <C40-5G-uuid>
802-11-wireless-security.key-mgmt:      wpa-psk    # 纯 WPA2
```

### 2.2 NM 下发给 wpa_supplicant 的 key_mgmt 不含 SAE

NM journal 显示,连接时生成的 wpa_supplicant 配置:

```
Config: added 'key_mgmt' value 'WPA-PSK WPA-PSK-SHA256 FT-PSK'   # wpa-psk profile → 无 SAE
Config: added 'key_mgmt' value 'SAE FT-SAE'                      # sae profile(对照,可用)
```

对照:工作正常的 `Extender-G-BB40-WPA3` profile 是 `sae`,NM 生成
`SAE FT-SAE`,wpa_supplicant 用 SAE 认证,关联成功。

### 2.3 wpa_supplicant 关联被 AP 拒绝,循环 20ms

```
supplicant interface state: scanning → associating → disconnected
```

- 周期约 20ms,AP 端拒绝关联,从未进入 `ip-config`(DHCP)。
- `nmcli device wifi connect` 返回 rc=0 是**假成功**——nmcli 在 config 阶段就
  返回,不等真正 connected。
- 重启后能连上:状态干净时首次关联偶发走 WPA2 成功;一旦连过别的网络
  (尤其 WPA3 的 Extender),再用纯 PSK 关联 transition-mode AP 就被拒。

## 3. 根因

**AP 是 WPA2/WPA3 transition mode,要求客户端要么 SAE、要么 PSK;但 profile
固定 `wpa-psk`,wpa_supplicant 只提供 `WPA-PSK`(无 SAE),关联被 AP 拒绝。**
重启清空状态后偶发成功,掩盖了配置错误。

对比:

| 网络 | AP 广播 | profile key-mgmt | NM 下发 key_mgmt | 结果 |
|---|---|---|---|---|
| C40FA623BF09-5G/2G | WPA2 WPA3 | `wpa-psk`(错) | `WPA-PSK WPA-PSK-SHA256 FT-PSK` | ❌ 关联被拒循环 |
| C40FA623BF09-5G/2G(修复后) | WPA2 WPA3 | `sae` | `SAE FT-SAE` | ✅ |
| Extender-G-BB40-WPA3 | WPA3 | `sae` | `SAE FT-SAE` | ✅ |
| Extender-G-BB40 | WPA2 | `wpa-psk` | `WPA-PSK …` | ✅(AP 纯 WPA2,PSK 正确) |

## 4. 一次性修复(手工)

把 profile 的 key-mgmt 改为 `sae`(SAE 兼容 WPA2/WPA3 transition AP):

```sh
nmcli connection modify <uuid> 802-11-wireless-security.key-mgmt sae
# 5G 与 2G 两个 profile 都要改
```

注意:NM 的 key-mgmt 选项没有「wpa-psk sae」组合值,只有
`none | ieee8021x | wpa-psk | wpa-eap | sae | owe` 单选。transition-mode AP
用 `sae` 即可(SAE 握手同时覆盖 AP 的 WPA2/WPA3 两种宣告)。

## 5. 自动修复(代码)

`quickshell/modules/wifi/bin/sumika_wifi_ops.py` 新增
`auto_fix_security_profile()`,在 **`connect_network()` 发起任何激活动作之前**
执行,覆盖 popup 手动连接、TUI 连接、`fix_connection` auto-recover 全部入口。

判断逻辑:

1. 从扫描缓存读目标 SSID 最强 BSS 的广播安全类型(`nmcli device wifi list`)；
   缓存没有该 SSID 时先触发一次 rescan 再判断。
2. 若广播含 **WPA3**(`WPA2 WPA3` 或纯 `WPA3`)。
3. 且已保存 profile 的 `key-mgmt` 是 `wpa-psk`。
4. → `nmcli connection modify uuid <uuid> 802-11-wireless-security.key-mgmt sae`,
   并输出日志:

```
auto-fix: AP advertises WPA2 WPA3 but profile used wpa-psk — switched profile to sae
```

保守边界(以下情况**不动** profile,也不阻塞连接):

- 纯 WPA2 AP(广播不含 WPA3)→ `wpa-psk` 本就正确。
- profile 已是 `sae` / 空。
- enterprise(802.1X)、owe、wep 等非 `wpa-psk` profile。
- 全新网络(尚无 profile,`uuid=None`)→ 本次没有可修改的 profile，交给 NM
  创建；下一次连接会重新审计该 profile。

连接命令的退出码不是最终成功依据：现在还会等待目标 SSID 实际激活，并确认
IPv4 与默认网关已经出现，才向 Popup/TUI 报告「Connected」。

`R` 自动恢复会先刷新扫描，并审计所有当前可见的已保存 profile，因此即使当前
transition-mode 网络暂时仍能联网，也会把遗留的 `wpa-psk` 修正为 `sae`，避免
下一次重连重新触发关联循环。

## 5.1 空壳 profile 清理(empty-shell purge)

NM 在用户**发起连接的瞬间**就创建 profile；如果用户取消密码输入框，profile
会留下但 PSK 为空(`psk-flags=0`、`psk` 为空)。这些空壳:

- 在 UI 里显示为"已保存"，但点击后 `secrets are required` 连不上；
- 同一 SSID 的多个空壳(`Foo`、`Foo 1`、`Foo 2`)会互相抢占，连上的被没密码的
  切走(见 2026-08-08 的 `C40FA623BF09-5G 1` 抢占事件);
- autoconnect 时反复失败，拖累整网恢复。

**检测**:`_profile_has_psk(uuid)` 用 `nmcli --show-secrets -g psk` 读取真实
PSK(普通 `nmcli -g psk` 永远显示 `<hidden>`，无法区分空与非空)。PSK 非空 =
有凭据；PSK 为空 = 空壳。Open 网络无 key-mgmt，视为有凭据；enterprise(EAP)
排除(需要 nmtui)。

`get_saved_networks()` 的 `has_credentials` 字段现在反映真实 PSK 存在与否。
UI 侧(`Network.qml` 的 `knownWifiNames` 和 `savedWifiProfiles`)只展示
`has_credentials=true` 的 profile，空壳不再出现在 WiFi 列表和设置页。

**清理**:`purge_empty_profiles(on_log)` 删除所有 `has_credentials=false`
的 profile(当前活动连接除外)。在 `fix_connection` Step 1 审计后自动执行；
也可手动 `sumika-wifi purge-empty` 触发。

## 6. 相关提交

| commit | 内容 |
|---|---|
| `6b20d6d` | `connect_network` 重写:`device wifi connect` 原子切换(根因修复①:`connection up` 不能切换网络) |
| `c807b1e` | `fix_connection` 全程抑制 NM autoconnect(根因修复②:候选间隙 NM 抢连) |
| `4863b64` | **本问题**:`auto_fix_security_profile()` WPA2/WPA3 transition 自动修复 |

## 7. 排查命令速查

```sh
# AP 广播安全模式
nmcli -t -f SSID,BSSID,SIGNAL,SECURITY,FREQ device wifi list | grep <ssid>

# profile key-mgmt
nmcli -g 802-11-wireless-security.key-mgmt connection show <uuid>

# NM 实际下发的 wpa_supplicant key_mgmt
journalctl -u NetworkManager --since "21:00" --no-pager | grep "Config: added.*key_mgmt"

# wpa_supplicant 关联状态循环(scanning→associating→disconnected = AP 端拒绝)
journalctl -u NetworkManager --no-pager | grep "supplicant interface state"
```

## 8. 相关背景(同批排查的另外两个根因)

- `connection up <uuid>` 不能切换网络:已关联别的 SSID 时 NM 直接拒绝
  (`The base network connection was interrupted`,rc=4)。切换必须用
  `device wifi connect`(GUI 点 SSID 等价,原子断开+激活)。见 `6b20d6d`。
- NM autoconnect 会劫持候选间隙:修复期间 `device wifi connect` 被 enqueue 时,
  NM 按 profile 优先级抢连别的 autoconnect=yes 网络。修复全程
  `nmcli device set <dev> autoconnect no`,结束恢复 yes。见 `c807b1e`。


## 9. 相关文档

- [WIFI-AUTO-RECOVERY.md](WIFI-AUTO-RECOVERY.md) — WiFi 自动恢复链路完整设计：
  watchdog → `fix_connection` → 候选排序 → radio reset；空壳 profile 清理；
  autoconnect 优先级配置；审计检查清单。