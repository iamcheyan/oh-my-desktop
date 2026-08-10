# labwc 窗口切换器 OSD 卡顿——诊断与"自愈"记录

> 2026-08-09。现象：labwc 0.20.1 会话里 Alt+Tab / Win+Tab 切换窗口后，
> window switcher OSD 不自动消失（"卡一下"）。用户自述"之前没有、肯定哪里改坏了"，
> 要求查本地配置。最终结论：**本地配置没坏**；问题是上游设计行为 + 虚拟键盘残留
> 状态叠加。用户重启 ydotoold 后"好了"——本文记录发生了什么变化、为什么。

## 结论摘要

1. **设计行为（上游，非 bug）**：先松修饰键（Alt/Super）、Tab 还按着时，
   labwc 刻意等 **Tab 也释放**才结束切换器（`handle_modifiers` 的
   `should_cancel_cycling_on_next_key_release` 机制，2022-08-30 commit
   `20c4ffa5` 引入，防 XWayland 客户端卡键）。此时 OSD 停留 = **按住 Tab 继续
   浏览窗口**的功能，不是故障。
2. **叠加异常（真正的"卡一下"）**：ydotoold 虚拟键盘（uinput 设备）残留了
   **只 down 不 up** 的按键状态，污染 labwc 的键盘状态 → 切换器结束判断失效，
   **无论先松哪个键 OSD 都不消失**。
3. **变化点**：2026-08-09 23:07:54 用户 `sudo kill 862`（旧 ydotoold）→
   systemd `Restart=always` 自动拉起新实例（pid 2054793）→ uinput 虚拟键盘
   设备销毁重建 → **残留按键状态被内核清空** → 恢复正常。
4. **设计行为仍在**：重启后复测（ydotool 注入 + grim 截图）：先松 Alt、Tab 按着
   → OSD 残留（设计）；先松 Tab 再松 Alt → OSD 立即消失。用户"好了"是因为
   残留状态被清，日常先松 Tab（或快速松键）不触发设计残留路径。

## 时间线（全部 2026-08-09，证据来自 journal/sudo 记录/ps/strace）

| 时间 | 事件 |
|---|---|
| 19:58 | labwc 会话启动（`labwc -C …/OMD/labwc`，pid 1362 未重启过）；ydotoold 862（systemd）、keyd 844、fcitx5 2735 |
| ~22:3x | 用户报告 OSD 卡顿，开始自行排查（`sudo strace -p 862` 追 ydotoold） |
| 22:41 | strace 捕获 ydotoold 写入 uinput 的 **KEY_STOP(128) down、KEY_UNDO(131) down**（无 up） |
| 22:59-23:04 | 注入测试：先松 Alt → OSD 残留（符合设计）；**先松 Tab 也残留**（异常，非设计） |
| 23:05 | 用户 strace 又捕获 **KEY_J(36) down、KEY_STOP(128) down**（无 up）；keyd strace 0 字节（keyd 空闲） |
| 23:07:21 | 用户执行留下的 `/tmp/verify-step.py`（复现） |
| 23:07:54 | 用户 `sudo kill 862` + 观察；**systemd 自动重启 ydotool.service**（新 pid 2054793，新 uinput 设备 input10/event4）；keyd journal 同步 `removed` → `ignoring` |
| 23:09-23:22 | 用户继续验证（监听 event4、解析键码、cat strace 输出） |
| 23:15:16 | 用户手动启动 sumika bar（quickshell sumika-bar/polkit/launcher） |
| 23:23 | 复测确认：先松 Alt 残留（设计行为），先松 Tab 正常 |
| 之后 | 用户："现在好了" |

## 机制细节

### 设计行为（labwc 0.20.1 `src/input/keyboard.c`）

```
handle_modifiers():  切换中且所有修饰键释放时：
    key_state_nr_bound_keys() 非空（Tab 仍被吸收）→ should_cancel_cycling_on_next_key_release = true
    否则 → cycle_finish(true)（OSD 立即消失）
handle_key_release(): 该 flag 置位时，任意 bound 键释放 → cycle_finish(true)
```

- 先松 Alt、Tab 按着 → flag 置位 → OSD 等到 Tab up 才消失（**浏览窗口功能**）。
- 引入 commit `20c4ffa5`（2022-08-30）："do not end window-cycling on modifier
  release only"，提交信息原文说明是防 XWayland 客户端（hexchat）在
  `modifier up` 时误认为 Tab 按下、又因释放事件被吸收而 stuck。
- 运行二进制 = 官方未修改构建（md5 `f3c83524c5ff4feedc5358d59b470a37` 与
  `~/development/labwc-upstream/build/labwc` 一致）。
- 本地配置与此无关：`<windowSwitcher preview="yes" outlines="yes">` 自初始
  commit 未变；`<popupTime>0</popupTime>` 只关 workspace OSD；A-Tab/W-Tab
  走同一 cycle 机制。**没有任何配置项能改这个释放时序**。

### 叠加异常（虚拟键盘残留状态）

- ydotoold 是 uinput 虚拟键盘（libinput 设备）→ 进 labwc 的 keyboard group /
  键盘状态追踪。
- 若某 ydotool 客户端注入 **只 down 不 up** 的键（进程崩溃、命令被杀、脚本
  bug），ydotoold **不会补发 up**，uinput 保持该键按下。
- 残留键（尤其 modifier）→ `keyboard_get_all_modifiers()` 恒非零 →
  `handle_modifiers` 的结束分支永不执行 → **无论先松哪个键 OSD 都不消失**。
- 恢复手段：重启 ydotoold（uinput 设备销毁时内核自动释放所有按键）或注入
  对应 up。

### 注入源（未完全确认）

- 22:41 / 23:05 / 23:12 三次 strace 均捕获到 down-only 键注入
  （KEY_STOP 128、KEY_UNDO 131、KEY_J 36）。23:23 监听新设备 6 秒无注入
  → 偶发而非持续。
- 候选：用户 22:41:46 启动的 omp 会话（`bun …/omp`，pid 1764761）或残留的
  ydotool 测试脚本（历史命令含 `ydotool key 29:1 47:1 47:0 29:0`、
  `ydotool type "hello from ydotool"`、`ydotool-scancode-test`）。
- **未再出现则不再追查**；复发时先监听 `/dev/input/event4`（sudo）确认注入源。

## 处置建议

- **不修改任何配置**（本地配置本来就无责；上游不能动）。
- **操作习惯**：切换时先松 Tab 再松修饰键 → OSD 立即消失（设计行为绕行）。
  若需要按住 Tab 浏览，OSD 停留是功能。
- **若再出现"切换器不消失"**：重启 ydotoold 即可，无需动 labwc/桌面：

  ```sh
  sudo systemctl restart ydotool   # Restart=always，uinput 重建、按键状态清零
  ```

  （若 bar 的 WlSessionLock 占用，严禁用 pkill 杀 bar——见 docs/features/lock-screen.md；
  ydotoold 与 bar 无关，重启安全。）
- **测试约定**：任何 ydotool/wtype 注入脚本必须 down+up 配对，结束时全键
  release（`ydotool key 56:0 15:0 1:0 …`），避免制造下一次残留。
