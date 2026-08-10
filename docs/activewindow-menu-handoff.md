# ActiveWindow 窗口菜单 — 交接文档（多模态智能体续做）

> 状态：**代码已全部实现，UI 点击验证卡住**。本会话模型无视觉能力，无法可靠
> 确认截图内容（bar 位置、菜单是否弹出、焦点窗口），需要有多模态能力的智能体
> 接手完成验证。所有改动**未提交**（用户自行 commit）。

## 一、任务目标

顶部 bar 的 ActiveWindow（当前窗口标题）区域增加右键/左键菜单：

1. **菜单内容**：Minimize / Maximize / Close Window / 分割线 / Force Quit
2. **Force Quit 语义**：无论什么情况都强制关闭目标窗口的进程
3. **Toggle 行为**：点击标题一次展开菜单，再点一次收起

## 二、已完成（代码就绪）

| 文件 | 改动 |
|---|---|
| `quickshell/modules/common/widgets/NerdIconMap.qml` | 新增 `windowMinimize`/`windowMaximize`/`windowClose`/`windowKill` 4 个图标（codepoint 已用 fontTools 验证） |
| `~/.local/share/sumika-shell/extensions/active-window/ActiveWindowMenu.qml` | 新建菜单组件（见下） |
| `~/.local/share/sumika-shell/extensions/active-window/ActiveWindow.qml` | RippleButton 包裹标题区 + toggle 逻辑 + `menuTarget` 快照 + `BarContextMenu` 接线 + 调试 `console.log` |
| `labwc/rc.xml` | `<keepBorder>no</keepBorder>`（W-f 两态循环）+ `W-A-k → Kill` keybind |

### ActiveWindowMenu.qml 设计（当前版本）

- **Minimize/Maximize/Close**：走 `zwlr_foreign_toplevel_management_v1`（Quickshell
  `Toplevel` API：`t.minimized = true`、`t.maximized = !t.maximized`、`t.close()`），
  labwc 与 Hyprland 通用，已确认 labwc 实现全部 request handler。
- **Force Quit**（`forceQuit()`）：
  - Hyprland 会话（`HYPRLAND_INSTANCE_SIGNATURE` 存在）：`hyprctl dispatch killactive`
  - labwc 会话：`pkill -x <comm名>`（SIGTERM），2 秒后窗口仍在则 `pkill -9 -x <comm名>`
  - comm 名 = `appId` 最后一个点段（`org.kde.ark` → `ark`），去除单引号防注入
  - **wtype 注入已弃用**：实测 labwc 虚拟键盘不处理 wtype 的多 modifier 组合
    （W-A-k 注入无效），故改为直接按进程名 signal。
- `targetToplevel` 为点击时捕获的 toplevel 快照，避免菜单打开期间焦点漂移。

## 三、当前卡点（需要视觉确认）

### 现象

1. ydotool 注入点击 ActiveWindow 区域，**菜单未确认弹出**。
2. 已加 `console.log("[ActiveWindow] clicked ...")`，点击后
   `journalctl --user -u sumika-bar.service` **无该输出** → 点击位置未命中按钮
   （坐标未对准，或 bar 输入区域有偏移）。
3. 历次点击实验的焦点判断被干扰：Ark 有 3 个窗口（主窗/密码/解压进度），
   解压完成时"正在解压所有文件"窗口自动关闭会导致焦点自然变化，与点击无关，
   之前误判为"点击穿透激活了 Firefox/Ark"。

### 已知坐标事实（截图分析得出）

- 屏幕 3024x1964；顶部 bar 可视内容在 **y≈18–44**（bar 高 32px，疑似从 y≈14 起，
  文字 y18–28 中心）。**y<18 是 bar 上方空隙，点击会穿透到窗口**。
- bar 内 ActiveWindow 标题段（含图标）约 **x447–682**，中心 x≈565；
  ActiveWindow 的 `implicitWidth: 280`、`implicitHeight: 28`。
- 左端 workspaces 区 x40–200；右端托盘 x2169–2977。
- ydotool 绝对坐标换算：物理 `(px, py)` → 绝对 `(px*32767/3024, py*32767/1964)`。
  例：物理 (565,25) → 绝对 (6123, 417)。

### 待验证步骤（按序）

1. **精确定位并点击**：先用 `grim` 截图 + `inspect_image` 确认 bar 实际位置与
   ActiveWindow 标题段坐标（注意 y<18 穿透、y18–44 才是 bar）。
   推荐先点物理 (565,25)（绝对 6123,417），点击后立即
   `journalctl --user -u sumika-bar.service` 看是否有 `[ActiveWindow] clicked` 日志。
   **有日志 = 命中按钮**；无日志 = 坐标偏了。
2. **确认菜单弹出**：截图 + `inspect_image` 找菜单（含 Minimize/Maximize/Close
   Window/Force Quit 四项，BarContextMenu 弹出位置在 bar 下方或上方）。
3. **验证 toggle**：再点一次标题，菜单应收起。
4. **验证菜单动作**：Minimize（窗口最小化）、Maximize（最大化切换）、
   Close Window（窗口关闭），用 `wlrctl toplevel list` + 截图确认。
5. **验证 Force Quit（labwc 路径）**：用用户长跑的 ark 进程测试
   （`pgrep -x ark`，用户明确要求拿它试，**不要再开测试进程**）。
   点 Force Quit → `pgrep -x ark` 应消失。若 ark 是单窗口可直接验证；
   若 SIGTERM 后 2s 窗口仍在会走 `pkill -9`。
6. **验证 Hyprland 路径**（当前是 labwc，可仅静态确认 `hyprctl dispatch killactive` 分支）。

## 四、环境与命令

```bash
# 会话
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000
export YDOTOOL_SOCKET=/tmp/.ydotool_socket   # 必须，否则连不上 daemon

# bar 重启（禁止 systemctl restart / pkill quickshell —— WlSessionLock 在 bar 进程内）
cd /home/tetsuya/development/OMD && timeout 60 bin/sumika-restart
# 注意：exit code 4 属正常（后续单元启动），bar 本身 active 即可

# 日志（bar 已把 stdout/stderr 重定向到 /tmp/sumika-bar.log）
journalctl --user -u sumika-bar.service --since "1 min ago" --no-pager

# 注入点击
ydotool mousemove --absolute <X> <Y> && sleep 0.3 && ydotool click 0xC0

# 截图 + 窗口列表
grim /tmp/x.png
wlrctl toplevel list          # 注意：列表顺序 ≠ 焦点顺序，别用它判焦点

# 焦点判断：裁剪 bar 标题段 (440,16)-(720,46) 放大 3 倍后 inspect_image 读文字
# 当前焦点窗口的标题会显示在 bar 里（如 "经典复刻版Mud3.7z — Ark"）
```

## 五、已知陷阱

- **wlrctl 列表顺序 ≠ 焦点顺序**，判焦点只能看 bar 标题文字或 `wlrctl toplevel focus` 后的截图。
- **inspect_image 偶尔 500 错误**，重试一次即可。
- 点击 bar 上方空隙（y<18）会穿透到下层窗口并改变焦点。
- Ark 解压窗口自动关闭会造成"焦点自己变"的假象。
- `wlrctl toplevel focus app_id:org.kde.ark` 可聚焦 ark（多个匹配会聚焦其中一个）。
- 扩展目录是独立 git 仓（`~/.local/share/sumika-shell/extensions/`），
  文件改动在**扩展仓**；NerdIconMap/rc.xml 改动在 **OMD 主仓**。
- 不要创建新的测试窗口/进程（用户明确要求，直接用现有 ark）。

## 六、相关文件

- 扩展仓：`~/.local/share/sumika-shell/extensions/active-window/ActiveWindow.qml`（已改）、
  `ActiveWindowMenu.qml`（新建）
- OMD 主仓：`quickshell/modules/common/widgets/NerdIconMap.qml`（已改）、
  `labwc/rc.xml`（已改）
- 参考范式：`quickshell/modules/common/widgets/BarContextMenu.qml`、
  `PowerContextMenu.qml` + `PowerIndicator.qml`（现有菜单调用方式）
- 截图素材：`/tmp/menu-*.png`、`/tmp/e1/e2*.png`、`/tmp/*-title.png` 等

## 七、之前的验证结论（勿重复）

- wtype 双 modifier（W-A-k）注入在 labwc **无效**（虚拟键盘 modifier 处理问题）→ 已弃用，改 pkill。
- ydotool evdev 注入按键有效（`ydotool key 125:1 56:1 37:1 ...`），但**点击坐标**问题未解决。
- labwc `Kill` action = SIGTERM；无 IPC、wlr-ftm 无 kill request → 无法拿 PID，进程名匹配是唯一路径。
- 点击 bar 本身（如 workspaces 区）不改变焦点（layer surface），已实测 y18 点击后焦点不变。
