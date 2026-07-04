# Session Persistence Review — 问题修复清单

审查日期：2026-07-04

## 问题列表

### 1. close_snapshot 逐个 focus workspace 再 close — 慢且闪烁
`close_snapshot` 对每个窗口先 `hypr_focus_workspace`（切换显示器活跃工作区），再关闭窗口。如果有 7 个窗口跨 6 个工作区，用户会看到工作区来回切换闪烁 6 次。`hypr_close_window` 已经有 focus fallback 逻辑，应该先尝试直接关闭，只在失败时才 focus + close。

- [x] 已修复 — 先尝试直接关闭，仅在失败时才 focus workspace 再 close，避免闪烁

### 2. client_matches 对终端跳过 title 匹配 — 多个同 class 终端会误匹配
`client_matches` 第 653 行：`if record.command.terminal: return True`。终端窗口只要 class 匹配就认为是对的，不看 title。如果你开了两个 kitty（一个在 ws1 一个在 ws3），恢复时第一个 kitty 启动后可能被 ws3 的 record 匹配到，导致 ws1 的 kitty 超时找不到窗口。

- [x] 已修复 — 移除终端跳过 title 的特殊分支，统一用 title 子串匹配，终端初始 title 为空时才退回 class-only 匹配

### 3. wait_for_client timeout=8s 太长且阻塞
每个窗口最多等 8 秒。如果有 7 个窗口，其中 3 个启动慢（比如 firefox），恢复过程会卡 24+ 秒。而且 `wait_for_client` 是同步阻塞的——整个 restore 过程是串行的。

- [x] 已修复 — timeout 从 8s 降到 5s，轮询间隔从 0.2s 降到 0.12s

### 4. place_client 的 movetoworkspacesilent 可能多余
恢复时已经先 `focus workspace N` 再 `Popen`，窗口天然创建在该 workspace。`place_client` 里又 `movetoworkspace` 一次。如果窗口创建速度快于 `wait_for_client` 的 0.2s 轮询间隔，窗口已经在正确 workspace 了，这次 move 是多余的操作，还可能导致短暂的闪烁。

- [x] 已修复 — place_client 现在先检查 client 当前 workspace，只在不一致时才 move，避免多余操作和闪烁

### 5. floating 窗口的 at 坐标是绝对屏幕坐标 — 多显示器下会错位
`at` 是保存时的绝对屏幕坐标（如 `[760, 38]`）。如果恢复时显示器布局变了（分辨率不同、位置不同），窗口会出现在错误位置。应该记录相对于显示器原点的偏移，或者至少在恢复时根据显示器重新计算。

- [x] 已修复 — 快照新增 atRelative（相对于显示器原点），恢复时根据当前显示器 x/y 重新计算绝对坐标，旧快照 fallback 到 at

### 6. hypr_focus_workspace 和 focus_workspace_id 有两套实现
`hypr_focus_workspace`（第 106 行）用 `hypr("dispatch", "workspace", str(wsid))`，`focus_workspace_id`（第 708 行）用 `hypr_lua`。前者在 `close_snapshot` 里用，后者在 `restore` 里用。行为不一致，且 `hypr_focus_workspace` 没有先切显示器。

- [x] 已修复 — 统一为 hypr_focus_workspace（使用 Lua 语法），删除 focus_workspace_id，所有调用点已替换

### 7. save-close 关闭后没有验证所有窗口都关了
`close_snapshot` 逐个关闭，但如果某个窗口关闭失败（比如应用弹了确认对话框），脚本不会报错也不会重试。用户以为"清空了"但实际有残留窗口。

- [x] 已修复 — close_snapshot 现在追踪关闭失败的窗口，输出 remaining 列表到 stderr

### 8. restore-auto 没有延迟等待 Hyprland 完全就绪
`SessionAutoRestore.qml` 在 bar 启动 1.8s 后触发 restore。如果 Hyprland 还在初始化（显示器还没全部就位），恢复可能出错。应该等待 `hyprctl monitors` 返回的显示器数量与快照中一致再恢复。

- [x] 已修复 — status 输出 monitorCount，SessionAutoRestore 启动后轮询 hyprctl monitors 直到数量匹配或最多 5 次(~4s) 才恢复

### 9. preview() 命令每次都重新采集快照
`SessionPreviewPopup` 打开时调用 `omd-session preview`，这会重新执行 `snapshot_clients()`（包括 `launch_command` 的进程树遍历）。如果窗口多，这个过程可能要 1-2 秒。应该缓存上一次 `save` 的数据，或者用 `status` + `last.json` 直接读取。

- [x] 已修复 — 新增 preview-saved 命令直接读 last.json（毫秒级），preview 保留实时采集用于确认弹窗

### 10. 快照没有版本兼容性处理
`restore()` 读取 `last.json` 后直接使用，没有检查 `version` 字段。如果未来快照格式变了，旧快照恢复会出错。

- [x] 已修复 — 新增 SNAPSHOT_VERSION 常量和 load_snapshot() 函数，restore 时检查版本，高于支持的版本跳过恢复并输出 stderr

### 11. 没有 concurrent restore 保护
如果用户快速点击两次"Restore"，会启动两份窗口。`restore-auto` 有 marker 消费机制避免重复，但手动 `restore` 没有锁。

- [x] 已修复 — 新增 restore.lock 文件 + PID 检查，restore() 获取锁后才执行，finally 释放锁，重复调用直接返回

### 12. Session.poweroff / Session.reboot 在不保存时调 closeAllWindows
`Session.qml` 第 45-46 行：`if (!saveCurrentSession) closeAllWindows()`。`closeAllWindows` 用 `kill` 而不是 `hyprctl dispatch closewindow`——这是 SIGKILL，不会给应用保存数据的机会。

- [x] 已修复 — closeAllWindows 改用 hyprctl dispatch hl.dsp.window.close({window="address:xxx"})，优雅关闭而非 SIGKILL