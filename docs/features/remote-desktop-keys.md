# 远程桌面窗口的 Win 键处理

远程桌面（`remote-desktop` 启动器 → sdl-freerdp RDP）场景下，本机快捷键要
**留在本机生效**，而远程 Windows **不响应** Win 键——尤其是裸 Win 键（会弹出
远程的开始菜单，和本地快捷键冲突）。复制粘贴等未绑定键不受影响。

> 需求要点（易搞反）：不是"进入 RDP 后把本地快捷键让给远程"，而是
> **本地照常用、远程不吃 Win 键**。

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

1. 启动 RDP（`remote-desktop`，自动切到 workspace 0 并最大化）。
2. 按 `W-s` / `W-1`：本地工作区照常切换，远程无反应。
3. 按裸 `Super`：**远程不弹开始菜单**，本地也无任何弹层。
4. 远程浏览器里 `Ctrl+C/V` 正常。

> 测试注意：RDP 服务器（192.168.3.65）是**单会话**服务器，连接约 90 秒后
> `Network disconnect` 掉线；测试完要 `pkill sdl-freerdp` 释放会话。

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
- `remote-desktop`（chezmoi 源 `dot_config/sumika-shell/scripts/executable_remote-desktop`，
  已提交 `ba89e08`）：labwc 分支 `launch_args` 加 `+dynamic-resolution`——
  sdl-freerdp 缺它时窗口被锁成不可调整大小（`setResizeable()` 置
  `SDL_SetWindowResizable(false)`），labwc 的 maximize 被固定尺寸挡住；加上后窗口
  可 resize、最大化生效，且窗口尺寸变化会同步 RDP 会话分辨率（内容跟随，无黑边）。
