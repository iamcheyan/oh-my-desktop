# Trackpad Revive（Apple SPI 触摸板传输死锁自愈）

## 症状

MacBook（Apple Silicon, Asahi）上触摸板完全无反应，但：

- 内核完整识别设备（`Apple SPI Trackpad`，spi-hid-apple-of + magicmouse）
- libinput / Hyprland 正常注册（`hyprctl devices` 可见）
- **零输入事件**：`/dev/input/eventN` 无任何输出
- 无任何内核错误日志

2026-08-15 在 MacBook Pro 14" M1 Max（Fedora Asahi 44, 内核 6.19.14-400.asahi.fc44）实测，观察到**两种死型**：

|死型|SPI 控制器 IRQ（39b10c000.spi）|备注|
|---|---|---|
|A. 风暴死|~900/s 疯狂中断，报文全被丢|首次冷启动出现|
|B. 静默死|触摸时也归零|level-1 重绑后数分钟内出现|

键盘与触摸板共用同一条 SPI 传输（spi1.0），两种死型下键盘都可能仍"正常"。

## 修复 = 重跑 SPI 握手（unbind/bind）

```sh
sumika-trackpad-revive              # 自动：检测 → 死锁则 SPI 重绑复活
sumika-trackpad-revive --check      # 只检测：rc 0 健康/空闲 / 1 死锁
sumika-trackpad-revive --status     # 打印拓扑（事件节点/SPI设备/HID设备）
sumika-trackpad-revive --force      # 跳过检测，直接 SPI 重绑
sumika-trackpad-revive --force-hid  # 仅实验用：只重绑 HID（见下，不可靠）
```

复活分两级，自动按需升级：

1. **设备级**：`spi1.0` 在 `spi-hid-apple-of` 上 unbind → 3s → bind。键盘断约 5 秒（共用总线，预期）。
2. **控制器级**：设备重绑后若 IRQ 风暴仍 ≥100/s（无需触摸即可观测），升级为 `39b10c000.spi` 在 `apple-spi` 上 unbind/bind，3 轮重试。2026-08-15 实测设备重绑后风暴不停的一次被此路径救回。

需要 root（脚本经 `sudo -n` 自提升，依赖 NOPASSWD）。成功时弹 swayosd 提示，日志在 `~/.local/state/sumika-shell/trackpad-revive.log`。

**为什么不做 HID 级自动升级**：只重绑触摸板 HID 设备（magicmouse）曾恢复过报文流，但数分钟后触摸板再次死锁（静默死）。自动路径直奔 SPI 整绑。

## 检测签名（`check_health`，无需用户配合）

3 秒窗口内并行观察：SPI 控制器 IRQ 增量、触摸板事件节点、（同控制器的）键盘事件节点。

|判定|条件|
|---|---|
|healthy|IRQ 增量 ≥ 50（有人在碰）且触摸板事件节点有字节|
|dead（风暴死）|IRQ 增量 ≥ 50 且触摸板零事件|
|dead（静默死）|键盘有事件但控制器 IRQ 增量 ≈ 0（打字必然推动总线）|
|idle|IRQ 静止且键盘无事件 → 跳过（无法与无人使用区分）|

**已知盲区**：静默死 + 用户只滑触摸板不打字时，与 idle 不可区分，timer 不会触发。此时手动 `sumika-trackpad-revive --force`（或任意 `--force*`）即可。

## 实现陷阱（勿再踩）

- **`dd`/`head` 读 evdev 直接 EINVAL**（它们走 `pread`，字符设备不支持）——秒回失败被误判成"无事件"。必须用 `cat`。
- `/proc/bus/input/devices` 的 stanza 是多行记录，`awk -v RS=''` 匹配后**不能管道 `head -n1`**（会把记录截成第一行），要 `{print; exit}`。
- 触摸板重绑后 event 节点号会变（input9→input10→…），**每次检测前重新 discover**，不要缓存。
- SPI HID 的 hidraw/事件权限是 root:input 0600，脚本整体 sudo 运行。
- **卡死的传输层可能让 sysfs unbind/bind 写入直接失败**（2026-08-15 20:28 实测：unbind 失败、错误被 `2>/dev/null` 吞掉、service 3 秒退出）。rebind 必须捕获错误文本写日志并重试（脚本已做：两轮尝试 + bind 单独补试）。
- **HID 实例号是十六进制**：重绑多次后实例号过 0009 会出现 `000A`、`000C`…（2026-08-15 实测第 9 次重绑后 `[0-9]{4}` 正则失配，整个自愈变瞎 20 分钟）。实例后缀必须用 `[0-9A-F]{4}`。
- dmesg 用单调时钟、journal 用墙钟——NTP 校时后两者会差几十分钟，交叉核对事件时**别拿墙钟直接换算 dmesg 时间戳**，容易误判"重绑没生效"。
- **风暴死有时会自行解除**（同日 20:28:41 检测到死锁、20:29:48 已恢复，期间零重绑痕迹）。timer 每分钟重跑天然形成重试兜底。

## 自动自愈

`share/systemd/sumika-trackpad-revive.{service,timer}`（用户级单元）每分钟跑一次自动检测：

- 健康/idle 路径开销 ≈ 3 秒 cat 窗口 + 两次 `/proc/interrupts` 读取
- 只有判定 dead 才重绑
- `ConditionPathExists=/sys/bus/spi/drivers/spi-hid-apple-of`：非 Apple SPI 机器上整个单元惰性失效

单元由 `sumika-restart` 每次会话启动时渲染 `@SUMIKA_SHELL_ROOT@` 并链接启用（与 session-save 单元同一机制）。

## 手动应急（工具不可用时）

```sh
echo spi1.0 | sudo tee /sys/bus/spi/drivers/spi-hid-apple-of/unbind
sleep 3
echo spi1.0 | sudo tee /sys/bus/spi/drivers/spi-hid-apple-of/bind
```

重绑后 dmesg 可能出现 `status message mismatch` / `get report failed: -110`（magicmouse 拿精确尺寸失败改用回退值）——无害，触摸板照常工作。

## 排查时确认过的非原因

- 不是 libinput/Hyprland/配置：设备在 `hyprctl devices` 可见、无 disabled 配置项
- 不是 keyd/touchegg 类拦截：root 直读事件节点同样零字节（问题在 evdev 之下）
- 不是 Syncthing/权限/udev：`ID_INPUT_TOUCHPAD=1` 正常，合成器经 logind seat 拿设备
