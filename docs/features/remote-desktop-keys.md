# 远程桌面窗口的 Win 键处理

远程桌面（`remote-desktop` 启动器 → sdl-freerdp RDP）场景下，本机快捷键要
**留在本机生效**，而远程 Windows **不响应** Win 键——尤其是裸 Win 键（会弹出
远程的开始菜单，和本地快捷键冲突）。复制粘贴等未绑定键不受影响。

> 需求要点（易搞反）：不是"进入 RDP 后把本地快捷键让给远程"，而是
> **本地照常用、远程不吃 Win 键**。

## 再次点击启动器 = 跳转到已有会话

`remote-desktop` 是**单会话**启动器：如果 RDP 窗口已经在运行，再次点击
启动器不会开第二个会话，而是直接跳到已有窗口（聚焦 + 切到它所在的工作区）。

- 检测：`wlrctl toplevel find "title:Remote Desktop"`（foreign-toplevel，
  Hyprland / labwc 通用）。
- 跳转：`wlrctl toplevel focus`——labwc 在
  `desktop_focus_view_internal()` 里会 `workspaces_switch_to(view->workspace)`
  自动切到窗口所在工作区（Hyprland 的 foreign-toplevel activate 行为相同）。
- 命中即 `exit 0`，不启动客户端。

## 原理：labwc 的按键分发

labwc（0.20.1，`src/input/keyboard.c` 的 `process_key()`）对每个按键事件：

1. 用当前修饰符状态匹配全局 keybind（`match_keybinding()`）。
2. **命中** → 执行 action，按键被消费（记入 `key_state`），**不转发**给聚焦客户端。
3. **未命中** → 返回 `LAB_KEY_HANDLED_FALSE`，按键**转发**给聚焦客户端。

由此推出三件事：

| 按键 | labwc 判定 | 结果 |
|---|---|---|
| 已绑定的 Win 组合（`W-1..5`、`W-s`、`W-Tab`、`W-Return`、`W-C-*`…） | 命中 keybind | 本地执行，远程收不到 |
| 未绑定键（打字、`Ctrl+C/V`、方向键…） | 未命中 | 原样转发远程，正常用 |
| **裸 Win 键** | 无对应 keybind → 未命中 | 转发远程 → **远程弹开始菜单** ❌ |

要修的就是第三行：给裸 Win 键一个 keybind，让它命中并被消费。

## 实现：用空动作吃掉裸 Win 键

labwc 没有原生"空动作"；用 `Execute` 跑一个无害命令来消费按键即可。

`labwc/rc.xml`（`<keyboard>` 段末尾）：

```xml
<!-- Eat the bare Win key (Super_L/Super_R): swallow the keydown so it
     is never forwarded to the focused client. In an RDP session this
     stops the remote Windows desktop from popping its Start menu;
     locally the key has no standalone binding, so nothing is lost.
     Super COMBOS (W-1..5, W-s, W-Tab, …) are unaffected — their
     keybinds above match first and keep firing locally, and the
     unbound keys (typing, Ctrl+C/V, …) still reach the client. -->
<keybind key="Super_L">
  <action name="Execute" command="/bin/true" />
</keybind>
<keybind key="Super_R">
  <action name="Execute" command="/bin/true" />
</keybind>
```

生效：`labwc --reconfigure`（仓库内 `W-r` 已绑定；reconfigure 由当前 labwc 进程
通过 `LABWC_PID` 信号触发）。

### 为什么这样不会误伤

- **裸 Super 按下时修饰符为空**（`modifiers=0`），只会命中 `Super_L`/`Super_R`
  这个 keybind；组合键按下的瞬间修饰符是 `Super`，只会命中对应的 `W-*` keybind。
  两者按修饰符精确区分，互不干扰。
- 按 `W-1` 时：`Super` 先被消费（执行空动作），但键盘**物理修饰符状态**仍是
  Super 按住，`W-1` 的匹配只看修饰符状态 → 照常命中，本地切工作区。
- `Ctrl+C/V` 在 labwc 里没有 keybind（rc.xml 全是 `W-*`/`A-*`/`XF86*` 绑定）→
  未命中 → 转发远程，复制粘贴正常。

## 验证（2026-08-09 实测）

1. 启动 RDP（`remote-desktop`，自动切到 workspace 0，窗口以 workarea 尺寸
   铺满可用屏幕——见下方"为什么不用 maximize"）。
2. 按 `W-s` / `W-1`：本地工作区照常切换，远程无反应。
3. 按裸 `Super`：**远程不弹开始菜单**，本地也无任何弹层。
4. 远程浏览器里 `Ctrl+C/V` 正常。

> 测试注意：RDP 服务器（192.168.3.65）是**单会话**服务器，连接约 90 秒后
> `Network disconnect` 掉线；测试完要 `pkill sdl-freerdp` 释放会话。

## 为什么 labwc 分支不用 maximize

FreeRDP 的 SDL3 客户端（3.26）**会撤销合成器的 maximize**：窗口 map 后客户端
按其内部状态机主动 `set_maximized(false)`，`wlrctl toplevel maximize`、
rc.xml 的 `windowRule Maximize` 都实测被立即打回（连续 15 次 wlrctl 调用无一
保持；协议日志里客户端从未收到带 MAXIMIZED 状态的 configure）。fullscreen 虽
不被撤销，但会盖掉顶栏，不符合使用习惯。

替代方案：**让窗口以精确尺寸打开**。labwc 输出 scale=2 时，FreeRDP 的
`resizeToScale()` 会把 `/w:/h:` 按像素密度除以 2，所以传**物理分辨率**
（`/w:3024 /h:1900` = 输出 3024×1964 减去顶栏 32 逻辑×2）得到的窗口正好等于
逻辑 workarea（1512×950），左/右/底贴边、顶部贴住顶栏，视觉上就是最大化，
且**没有任何 maximize 状态可被客户端撤销**。远程分辨率随窗口 1:1 渲染，内容
清晰无黑边。窗口尺寸由 `labwc_rdp_size()` 从 `wlr-randr --json` 动态计算
（物理宽高 + scale），换显示器/分辨率也成立。

## 副作用与边界

- **全局生效**：裸 Win 键在所有窗口（不只 RDP）都被吃掉。本地目前没有应用依赖
  裸 Win 键，无实际损失；若将来需要，可用 keyd（`~/.local/state/sumika-shell`）
  在更底层做窗口感知处理。
- labwc **没有**"只对特定窗口吃特定键"的原生机制：
  - `windowRule` + `ToggleKeybinds` 会抑制该窗口聚焦时的**全部** keybind——
    那正好相反（本地快捷键被让给远程），不可用。
  - `zwp_keyboard_shortcuts_inhibit_v1` 协议 labwc 0.20.1 未实现。
  - sdl-freerdp 的 `+grab-keyboard` 是把键盘整体交给远程，方向相反。
- 因此当前方案是"全局吃裸 Win 键"这一最简单可靠的折中。

## 相关改动

- `labwc/rc.xml`（OMD 仓库）：`Super_L`/`Super_R` 空动作 keybind。
- `remote-desktop`（chezmoi 源 `dot_config/sumika-shell/scripts/executable_remote-desktop`）：
  - labwc 分支 `launch_args` 加 `+dynamic-resolution`——sdl-freerdp 缺它时窗口被
    锁成不可调整大小（`setResizeable()` 置 `SDL_SetWindowResizable(false)`）。
  - labwc 分支加 `labwc_rdp_size()`：从 `wlr-randr --json` 取当前输出物理分辨率
    和 scale，算出 workarea 尺寸（物理宽，高 = (物理高/scale − 32)×scale），
    以 `/w:/h:` 传给客户端；`maximize_rdp_window`（wlrctl）已删除——见上节
    "为什么 labwc 分支不用 maximize"。
  - 新增 `focus_existing_rdp()`：`wlrctl toplevel find` 检测已有会话，命中则
    `focus` 跳转并退出，不重复启动（见"再次点击启动器"一节）。
