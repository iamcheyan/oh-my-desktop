# Sumika Shell Keybindings — 键位逻辑与完整列表

本文档描述 Hyprland 层的键位绑定:分层架构、组合规律、Super 状态机、ActionManager
路由,以及当前全部绑定的完整清单。硬件层键位重映射(keyd)见
[keyboard-remap.md](keyboard-remap.md)。

## 分层架构

```
hypr/hyprland.lua (入口, HYPRLAND_CMD 指向)
├── require("default.hypr.base")        ← 上游默认,不要直接改
│   └── helpers.lua                     ← o.* 包装层(o.bind / o.launch / o.window)
│       └── bindings/
│           ├── tiling-v2.lua           ← 窗口/工作区/分组/缩放
│           ├── utilities.lua           ← 通知/显示器/截图/音频控件
│           ├── media.lua               ← 媒体键 XF86*/精确调节
│           └── clipboard.lua           ← SUPER+C/V/X 通用剪贴板
├── input.lua / bindings.lua / looknfeel.lua / autostart.lua   ← 仓库可改层
└── ~/.config/sumika-shell/hypr/{input,bindings,looknfeel,autostart}.lua
                                     ← 用户覆盖层,最后加载,优先级最高
```

加载顺序:默认层 → 仓库层 → 用户层。用户层同名文件可覆盖或追加绑定。

### 关键机制

- **`hl`** 是 Hyprland 0.55.4 内置 Lua 支持的注入 API(`hl.bind` / `hl.unbind` /
  `hl.dsp.*` / `hl.config` / `hl.window_rule` 等)。
- **`o.bind(keys, description, dispatcher, options)`** 是 `helpers.lua` 的封装:
  自动补 `description`,并把 dispatcher 写成命令字符串。

| dispatcher 写法 | 翻译成 | 用途 |
|---|---|---|
| `{sumika = "terminal"}` | `sumika-launch-profile terminal` | 应用 profile(终端/浏览器/编辑器) |
| `{launch=, focus=}` | `sumika-launch-or-focus` | 启动或聚焦唯一实例 |
| `{launch=}` | `uwsm-app -- ...` | 直接启动 |
| `{webapp=}` | `sumika-launch-webapp` | 网页应用 |
| `{tui=}` | `sumika-launch-tui` | TUI 工具(浮动终端) |
| `hl.dsp.*` | 原生 Hyprland 派发 | 窗口/工作区操作 |
| 字符串 | `hl.dsp.exec_cmd` | 任意命令 |

## 核心规律:修饰键 = 语义分区

```
SUPER         窗口 / 工作区 / 应用        (主修饰)
SUPER+SHIFT   反向 / 移动 / 次级操作      (swap、move to ws、browser、lock)
SUPER+CTRL    系统控制                   (音频、蓝牙、WiFi、锁屏、缩放、bar)
SUPER+ALT     窗口高级                   (分组、精确 resize、scratchpad)
ALT           桌面级独立操作              (截图、剪贴板、窗口循环、鼠标拖动)
CTRL+ALT      系统级/多显示器             (关窗口、跨屏焦点、锁屏备选)
无修饰        硬件媒体键 XF86*            (音量/亮度/播放/背光)
```

组合越"重"操作越精细,以 resize 为例的递进:

| 组合 | 步长 | 说明 |
|---|---|---|
| `SUPER + -`/`=` | 100px | 粗调 |
| `SUPER+ALT + -`/`=` | 25px | 精确 |
| `SUPER+CTRL + -`/`=` | 300px | 大幅 |
| `SUPER+SHIFT + -`/`=` | 垂直方向 | 换轴 |

## 字母记忆法:首字母 = 英文功能词

**窗口(SUPER)**:`T`oggle float、`F`ullscreen、`P`seudo、`S`cratchpad、`G`roup、
`L`ayout、`J` split、`O` pop-out、`W` close

**系统(SUPER+CTRL)**:`A`udio、`B`luetooth、`W`iFi、`L`ock、`Z`oom

**剪贴板(SUPER)**:`C`opy、`V`aste、`X`cut(通用剪贴板,发送 `CTRL+Insert`/
`SHIFT+Insert` 模拟)

**通知(SUPER+COMMA)**:逗号 = 消息隐喻

**方向键组合**:SUPER=聚焦 / +SHIFT=交换窗口 / +SHIFT+ALT=移工作区到邻屏 /
+ALT=移入分组 / +CTRL=组内焦点

## 数字键用 `code:` 而非键名

JP/多布局下键名不可靠,所有数字绑定用 xkb keycode(布局无关):

```lua
for slot = 1, 10 do
  local key = "code:" .. tostring(slot + 9)   -- xkb code 10..19 = 数字 1..0
  hl.unbind("SUPER + " .. key)                  -- 覆盖 default 层的原始 ID 绑定
  hl.bind("SUPER + " .. key, hl.dsp.global("quickshell:workspaceSlot" .. tostring(slot)), ...)
end
```

`SUPER+数字` 打的是 Overview 的**动态 Slot**(全局可见占用槽位 + 每显示器一个 trailing
空槽),不是原始 workspace ID——见 [overview-workspaces.md](overview-workspaces.md)。

## 所有系统行为走 ActionManager

Hyprland 绑定层从不直接执行命令,统一经 `sumika-action <module>.<action-id>`:

```lua
o.bind("SUPER + CTRL + W", "WiFi", paths.root .. "/bin/sumika-action wifi.launch")
```

- `sumika-action` → IPC → bar 进程的 `ActionManager`(quickshell/core/runtime/ActionManager.qml)
- 好处:键位与 UI 按钮共用同一入口;模块禁用时静默拒绝;参数统一;状态可查询
  (`sumika-action list` / `status` / `isAvailable <id>`)
- 当前注册 **91 个 action**,按 owner 分组:

**core(49)**:`app-launcher.{open,close,toggle}`、`bar.{open,close,toggle}`、
`menus.close`、`overview.{open,toggle}`、`settings.open`、`shell.reload`、
`session.{lock,logout,reboot,shutdown,suspend,hibernate,*.save}`、
`audio.*`(volume-up/down/mute-toggle/input-mute-toggle/output-switch/up-precise/down-precise)、
`mpris.{play-pause,previous,next}`、
`display.*`(brightness-up/down/max/min/up-precise/down-precise/kbd-brightness-*/color-picker/
scaling-cycle/scaling-cycle-reverse/internal-toggle/internal-mirror-toggle/lid-close/lid-open)、
`input.touchpad-*`、`window.*`(close-all/gaps-toggle/pop-out/single-square-aspect-toggle/
transparency-toggle)、`workspace.layout-toggle`、`process_supervisor.{cancel,status}`

**模块(42)**:
`bluetooth.launch`、`wifi.launch`、`inputmethod.input-method.cycle`、
`clipboard.{toggle,toggleBar,open,close,paste,store-toggle,store-repair}`、
`notifications.{dismiss-last,dismiss-all,toggle-silent,edit-muted}`、
`screenshot.{capture,capture-edit,capture-ocr,freeze,unfreeze}`、
`voice.{toggle,cancel,translate-toggle}`、`keyboardremap.{toggle,refresh,apply}`、
`filebackup.{toggle,refresh,settings}`、`clock.notifications`、
`osd.{volume,brightness}`、`windows-vm.{toggle,refresh,settings}`

## Overview 的 Super 状态机

Super 键的按下/释放被拆成多个透明绑定,由 Quickshell 的 `GlobalShortcut`
(GlobalStates.qml + Overview.qml)协同处理:

| 事件 | GlobalShortcut | 行为 |
|---|---|---|
| `SUPER` 按下 | `workspaceNumber` | `superDown=true`, `superReleaseMightTrigger=true` |
| `SUPER` 单独释放 | `workspaceNumber` (release) | 若 `superReleaseMightTrigger` 仍为 true → toggle overview |
| `SUPER+任意键` | `superInterrupt` (透明) | 清 `superReleaseMightTrigger` → 释放 Super 不弹 overview |
| `SUPER+TAB` | `overviewNext` | 进入 grabbed 切换模式(+1) |
| `SUPER+SHIFT+TAB` | `overviewPrev` | 进入 grabbed 切换模式(-1) |
| grabbed 中释放 `SUPER` | `workspaceNumber` (release) | `commitGrabbedMode()` 提交切换 |
| `SUPER+SUPER_L/R` 释放 | `overviewCommit` (release) | 同上(双 Super 兜底) |
| `SUPER+数字` | `workspaceSlotN` | 聚焦对应槽位 |

状态变量(GlobalStates.qml):

| 变量 | 含义 |
|---|---|
| `superDown` | Super 是否按下 |
| `superReleaseMightTrigger` | 是否可能触发 toggle(被 superInterrupt 清除) |
| `overviewOpen` | overview 是否显示 |
| `overviewSearchMode` | 是否处于搜索模式 |
| `overviewSwitchingController.grabbed` | 是否处于 grabbed 切换模式 |
| `overviewSwitchingController` | OverviewSwitchingController 注入引用(null=bar 进程) |

## 完整键位列表

### 应用与系统 — `hypr/bindings.lua`(仓库层)

| 键位 | 功能 | 路由 |
|---|---|---|
| `SUPER+RETURN` | 应用启动器 | `app-launcher.toggle` |
| `SUPER+A` | 应用启动器 | `app-launcher.toggle` |
| `SUPER+Q` | 终端 | `sumika-launch-profile terminal` |
| `SUPER+ALT+RETURN` | Tmux | `sumika-launch-profile terminal-tmux` |
| `SUPER+SHIFT+RETURN` | 浏览器 | `sumika-launch-profile browser` |
| `SUPER+SHIFT+B` | 浏览器 | `sumika-launch-profile browser` |
| `SUPER+SHIFT+ALT+B` | 浏览器(隐私) | `sumika-launch-profile browser --private` |
| `SUPER+SHIFT+N` | 编辑器 | `sumika-launch-profile editor` |
| `SUPER+R` | 重载 Hyprland 配置 | `hyprctl reload` |
| `SUPER+CTRL+B` | 蓝牙 | `bluetooth.launch` |
| `SUPER+CTRL+W` | WiFi | `wifi.launch` |
| `SUPER+SPACE` | 下一输入法 | `input-method.cycle` |
| `SUPER+SHIFT+SPACE` | 上一输入法 | `input-method.cycle -- -1` |
| `SUPER+CTRL+SPACE` | 切换 bar | `bar.toggle` |
| `ALT+S` | 区域截图 | `screenshot.capture` |
| `ALT+SHIFT+S` | 区域截图(编辑) | `screenshot.capture-edit` |
| `ALT+V` | 剪贴板管理 | `clipboard.toggle` |
| `ALT+mouse:272` | 拖动窗口 | Hyprland native |
| `ALT+mouse:273` | 调整窗口大小 | Hyprland native |
| `SUPER+SHIFT+L` | 锁屏(用户层新增) | `session.lock` |

> 注释中的示例(未启用):`SUPER+SHIFT+F/D/G/O/W`(应用)、`SUPER+SHIFT+A/C/E/Y/X`
> (网页应用)、`SUPER+SHIFT+R`(SSH)。按需取消注释。

### 窗口与工作区 — `default/hypr/bindings/tiling-v2.lua`

| 键位 | 功能 |
|---|---|
| `SUPER+W` | 关闭窗口 |
| `CTRL+ALT+DELETE` | 关闭所有窗口 |
| `SUPER+J` | 切换窗口分割方向 |
| `SUPER+P` | 伪平铺 |
| `SUPER+T` | 切换浮动/平铺 |
| `SUPER+F` | 全屏 |
| `SUPER+CTRL+F` | 平铺全屏 |
| `SUPER+ALT+F` | 最大化宽度 |
| `SUPER+O` | 弹出窗口(浮动+置顶) |
| `SUPER+L` | 切换工作区布局 |
| `SUPER+方向` | 聚焦相邻窗口 |
| `SUPER+数字` | 切到工作区 N(原始 ID,仓库层被覆盖为 Slot) |
| `SUPER+SHIFT+数字` | 移动窗口到工作区 N |
| `SUPER+SHIFT+ALT+数字` | 静默移动窗口到工作区 N |
| `SUPER+S` | 切换 scratchpad |
| `SUPER+ALT+S` | 移动窗口到 scratchpad |
| `SUPER+TAB` / `SUPER+SHIFT+TAB` | 下一/上一工作区(仓库层覆盖为 overview) |
| `SUPER+CTRL+TAB` | 上个工作区 |
| `SUPER+SHIFT+ALT+方向` | 移动工作区到邻屏 |
| `SUPER+SHIFT+方向` | 交换窗口方向 |
| `ALT+TAB` / `ALT+SHIFT+TAB` | 循环聚焦窗口 / 置顶 |
| `CTRL+ALT+TAB` / `CTRL+ALT+SHIFT+TAB` | 循环聚焦显示器 |
| `SUPER+(-/=/SHIFT/ALT/CTRL)` | 窗口 resize(见递进表) |
| `SUPER+mouse_down/up` | 滚动切工作区 |
| `SUPER+mouse:272/273` | 拖动/调整窗口(default 层,仓库层改 ALT) |
| `SUPER+G` | 切换窗口分组 |
| `SUPER+ALT+G` | 移出分组 |
| `SUPER+ALT+方向` | 移入相邻分组 |
| `SUPER+ALT+TAB` / `+SHIFT+TAB` | 组内下一/上一窗口 |
| `SUPER+CTRL+方向` | 组内移动焦点 |
| `SUPER+ALT+数字` | 切到分组窗口 N |
| `SUPER+code:61` / `SUPER+ALT+code:61` | 循环显示器缩放 / 反向 |

### 通知 / 显示器 / 系统 — `default/hypr/bindings/utilities.lua`

| 键位 | 功能 |
|---|---|
| `SUPER+BACKSPACE` | 切换窗口透明度 |
| `SUPER+SHIFT+BACKSPACE` | 切换窗口间距 |
| `SUPER+CTRL+BACKSPACE` | 切换单窗口方屏 |
| `SUPER+COMMA` | 关闭最后通知 |
| `SUPER+SHIFT+COMMA` | 关闭所有通知 |
| `SUPER+CTRL+COMMA` | 切换通知静音 |
| `SUPER+CTRL+Delete` | 切换笔记本内屏 |
| `SUPER+CTRL+ALT+Delete` | 切换内屏镜像 |
| `SUPER+PRINT` | 取色器 |
| `PRINT` | 截图 |
| `SUPER+CTRL+PRINT` | 截图 OCR |
| `SUPER+CTRL+A` | 音频控制 |
| `SUPER+CTRL+T` | 活动监控(btop TUI) |
| `SUPER+CTRL+Z` | 光标放大 |
| `SUPER+CTRL+ALT+Z` | 重置光标缩放 |
| `SUPER+CTRL+L` | 锁屏 |

### 媒体键 — `default/hypr/bindings/media.lua`

| 键位 | 功能 |
|---|---|
| `XF86AudioRaiseVolume` / `LowerVolume` / `Mute` / `MicMute` | 音量控制 |
| `XF86MonBrightnessUp/Down`、`SHIFT+` 变体 | 亮度控制 |
| `XF86KbdBrightness*` | 键盘背光 |
| `XF86TouchpadToggle/On/Off` | 触摸板 |
| `ALT+XF86Audio*` / `ALT+XF86MonBrightness*` | 精确调节 |
| `XF86AudioNext/Prev/Pause/Play` | 媒体播放 |
| `SUPER+XF86AudioMute` | 切换音频输出 |

所有媒体键绑定带 `{locked = true, repeating = true}`。

### 剪贴板 — `default/hypr/bindings/clipboard.lua`

| 键位 | 功能 |
|---|---|
| `SUPER+C` | 通用复制(send `CTRL+Insert`) |
| `SUPER+V` | 通用粘贴(send `SHIFT+Insert`) |
| `SUPER+X` | 通用剪切(send `CTRL+X`) |

用 `send_key_state` 模拟,绕 Hyprland `send_shortcut` 按键卡死 bug
(https://github.com/hyprwm/Hyprland/discussions/14099)。

### 用户覆盖层 — `~/.config/sumika-shell/hypr/bindings.lua`

当前只有一条(2026-08-01 新增):

| 键位 | 功能 | 路由 |
|---|---|---|
| `SUPER+SHIFT+L` | 锁屏 | `sumika-action session.lock` |

用户 input.lua 另有 4 指手势:上滑 = overview,捏合 = 启动器。

## 添加/修改键位

1. **写用户覆盖层**(推荐,不动仓库):`~/.config/sumika-shell/hypr/bindings.lua`
   追加 `o.bind(...)`,然后 `hyprctl reload`。
2. **改仓库默认**:编辑 `hypr/bindings.lua`(或 default 层),`hyprctl reload`。
3. **覆盖现有绑定**:先 `hl.unbind(...)` 再 `o.bind(...)`(数字键循环即此模式)。

## 注意事项

- **不要对 `SUPER+SPACE` 做 unbind/rebind**:仓库层给每个 SUPER+键注册了透明的
  `superInterrupt` 绑定,unbind 会连带清掉它,导致输入法切换后释放 Super 误弹
  overview(用户 bindings.lua 文件头注释有详细说明)。
- **数字键用 `code:` 不用键名**,避免布局差异。
- **TUI 工具 app-id 不能含下划线**(Wayland 会静默丢弃),见 AGENTS.md TUI 规则。
- 键位与状态查询:
  - `hyprctl binds -j` — 当前生效的全部 Hyprland 绑定
  - `sumika-action list` / `sumika-action status` — ActionManager 注册表
