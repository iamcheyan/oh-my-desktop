# Smart Paste kitty-only 化可行性调查

> 调查日期：2026-08-18
> 性质：**纯讨论，未改任何代码**
> 问题来源："这个功能可以只依靠 kitty 来实现吗？如果可以，任何剪贴板都能做了。"
> 结论先行：**可行，且比现状更通用**——真正绑定 Wayland 的依赖只有 `wl-paste` / `wl-copy` 两个调用，kitty 原生命令可完整替代。

---

## 一、现状梳理（代码实测核对）

现有实现在 `quickshell/modules/clipboard/bin/`，核心三脚本 + 中央粘贴管线：

| 文件 | 职责 |
|---|---|
| `sumika-kitty-smart-paste` | kitty 快捷键入口，检测剪贴板 MIME 分流图片/文本 |
| `sumika-clipboard-image-path` | SSH 感知：找焦点窗口 → 进程树 BFS 找 ssh → 解析 ssh 命令行 → `ssh cat >` 把图流到远端 |
| `sumika-paste-at-cursor` | 中央落字助手：主线 `kitty @ send-text --from-file --bracketed-paste`（OSC 5522），降级链 wtype → ydotool；XWayland 目标走 xsel + xdotool |

整条链路（入口 kitty.conf `map ctrl+shift+v launch --type=background sumika-kitty-smart-paste`）：

```
kitty 快捷键
  → wl-paste -l 列 MIME，image/* 分流
  → hyprctl 找焦点窗口 → kitty @ ls 解析焦点标签 shell pid
  → /proc BFS（限 24 层 500 pid）找 ssh，tmux client→server 穿透（最深 4 层）
  → 解析 ssh 命令行（提取地址 + -p/-l/-i/-F/-J/-o，丢远程命令段）
  → ssh -o BatchMode=yes 流图到远端 /tmp（绝不弹密码框）
  → sumika-paste-at-cursor 落远端路径；wl-copy 写回路径防 OpenCode 双贴
```

**设计原则**：所有失败路径都降级为"贴本地路径"，粘贴动作永远不会被 SSH 探测失败卡死。

## 二、现有部件 → kitty 原生能力逐项对照

| 现在依赖 | 作用 | kitty-only 替代 | 判定 |
|---|---|---|---|
| kitty.conf `map ... launch` | 触发 | 本来就是 kitty 的 | ✅ 零改动 |
| `hyprctl -j activewindow` | 找焦点窗口 | `kitty @ ls`（`is_focused`/`is_active`）；脚本 `candidate_roots` 已有此兜底路径（L228-245，`/tmp/mykitty-*` socket 探测），hyprctl 只是引导加速 | ✅ 已就绪 |
| `/proc` 进程树 BFS 找 ssh | SSH 感知 | 纯 POSIX，与桌面环境无关 | ✅ 原样可用（Linux） |
| tmux client→server 穿透 | 同上 | 纯 tmux 命令，无关 | ✅ 原样可用 |
| ssh 命令行解析 + `ssh cat >` | 图流到远端 | 无关 | ✅ 原样可用 |
| `kitty @ send-text --from-file --bracketed-paste` | 落字 | 本来就是主线（OSC 5522） | ✅ 零改动 |
| `wl-paste -l` / `wl-paste -t image/png` | 读剪贴板 | `kitten clipboard -g`（或 `kitty @ get-clipboard --mime`） | 🔄 **唯一真正的 Wayland 依赖** |
| `wl-copy` 写回路径文本 | 防 OpenCode 双贴 | `kitten clipboard`（写）/ `kitty @ set-clipboard` | 🔄 |
| wtype / ydotool / xsel / xdotool | 降级链 | 纯 kitty 场景不需要（它们服务**非 kitty** 目标） | ❌ 直接砍 |
| notify-send | 通知 | 可选，砍掉或换 kitty 提示 | ❌/可选 |

## 三、网上文档核实结果（Asahi 关机，改查官方文档）

**结论：全部支持，且比预想更好。**

1. **`kitten clipboard` 是现成的跨平台剪贴板读写命令**
   - `kitten clipboard` 写、`kitten clipboard --get-clipboard` 读
   - **官方明说 "It even works over SSH"**——SSH 会话里调它，操作的是**本地**剪贴板（kitty 内建转发）
   - 文档示例就是图片：`kitten clipboard -g picture.png`；列 MIME：`kitten clipboard -g --mime-types`
   - 底层走 OSC 5522（kitty 私有转义码，2022 年就有，持续维护中）
2. **macOS 同样支持**：OSC 5522 由 kitty 自己实现——Linux 读 Wayland/X11 剪贴板，macOS 读 NSPasteboard
3. **权限模型**：kitty 默认弹窗问"允许读剪贴板吗"，`clipboard_control` 配置可静默放行；快捷键触发一次授权终身有效
4. **比 `kitty @ get-clipboard` 更优**：`kitten clipboard` 根本不需要 remote-control socket，内部自动处理转发

## 四、kitty-only 目标链路

```
kitty 快捷键（任意平台）
  → kitten clipboard -g /tmp/img.png        # 读剪贴板图，本地/SSH 均可
  → /proc（Linux）或 ps -o ppid 爬树（macOS，约 30 行分支）找 ssh 会话
  → 解析 ssh 命令行 → ssh cat > 远端 /tmp
  → kitty @ send-text --bracketed-paste 贴远端路径
```

零 Wayland、零 Hyprland、零 wl-clipboard 依赖。kitty 在每个平台都是原生剪贴板客户端，所以"任何剪贴板都能用"成立——**比现状更通用**：现有 wl-paste 版出了 Wayland 就死，kitty-only 版连 macOS 都覆盖。

**前置条件仅两个**：
- kitty 开 remote control（本机已开，`/tmp/mykitty-*` socket）
- kitty 版本支持 `kitten clipboard`（2026 年的 kitty 均有；`get-clipboard` 约为 0.35 前后加入）

**Bonus 用例**：反向也通——远端服务器上 `kitten clipboard file`，本地 Mac 剪贴板即得该图，⌘V 直接贴进聊天窗。

## 五、代价（诚实说）

- **作用域缩到 kitty 窗口内**：foot/ghostty/GUI 应用目标没了——这是"随身带走"的取舍
- **cliphist 历史菜单带不走**：kitty 没有剪贴板历史，只能作用于*当前*剪贴板内容
- **macOS 上没有 /proc**：SSH 检测要换 `ps` 走树，该段需分平台
- **防双贴三层闸**（sha256 内容去重 / 路径抑制 `suppress_repeat_path` / payload 哈希 dedupe）是纯状态文件逻辑，原样搬，无平台问题

## 六、工作量预估

`sumika-clipboard-image-path` **今天就已经是近乎无组合器依赖的**（hyprctl 查不到时自动落到 `kitty @ ls` 兜底）。实际改造 ≈：

1. `sumika-kitty-smart-paste` 入口：`wl-paste -l` → `kitten clipboard -g --mime-types`，`wl-paste -t` → `kitten clipboard -g`（约 20 行）
2. 写回：`wl-copy` → `kitten clipboard`
3. macOS 分支：`ps` 爬树替代 `/proc` BFS（约 30 行）
4. 打包成单个自包含 kitten（或单 shell 脚本）

形态建议：**自包含 kitten + 两条 kitty.conf 配置随身带**（`listen-on` + 一条 map），任何装了 kitty 的机器 drop-in 即用。

## 七、遗留验证项

- [ ] Asahi 开机后确认 kitty 版号支持 `kitten clipboard`（唯一硬门槛）
- [ ] Linux 侧实测：读图 → SSH 检测 → 流图 → 落路径全链
- [ ] macOS 侧实测：`ps` 爬树找 ssh 段
- [ ] 确认 `clipboard_control` 静默放行配置

## 附：相关文件索引

- `docs/features/smart-paste.md` — 架构总览
- `docs/features/paste-kitty-conflicts.md` — OSC 5522 冲突与粘贴入口收编
- `quickshell/modules/clipboard/bin/sumika-kitty-smart-paste` — 入口（L91/105/136/153 为 wl-paste/wl-copy 调用点）
- `quickshell/modules/clipboard/bin/sumika-clipboard-image-path` — SSH 感知 + 传输（L228-245 为 kitty socket 兜底）
- `quickshell/modules/clipboard/bin/sumika-paste-at-cursor` — 中央落字 + 防双贴（L483-514 为 sha256/dedupe 闸）
