# Paste Pipeline and Kitty/TUI Conflicts

This document records how Sumika Shell sends clipboard and voice text into applications,
why duplicate insertion can occur, and the contract all paste features must
follow.

## Single Entry Point

All programmatic paste operations must use:

```sh
sumika-paste-at-cursor
```

Do not add another direct `kitty @ send-text`, `wtype`, `ydotool`, or Hyprland
key injection path in a feature module. The central helper owns:

- immutable payload capture;
- target window resolution;
- terminal versus GUI dispatch;
- Kitty remote-control socket validation;
- short-window duplicate suppression;
- diagnostic event logging.

## Payload Contract

Preferred invocation:

```sh
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
printf '%s' "$text" > "$payload"
wl-copy < "$payload"
SUMIKA_PASTE_SOURCE=my-feature \
  sumika-paste-at-cursor --file "$payload" auto "$window_class" "$window_target"
```

The helper also accepts `--stdin`. Calling it without either option remains
compatible with older callers and snapshots the current Wayland clipboard.

The payload file matters because `wl-copy` and UI/process callbacks are
asynchronous. Re-reading the clipboard later can retrieve content changed by a
different handler, especially in image-aware terminal applications.

For GUI applications and non-Kitty terminals, the helper emits one chord via
`wtype`. It only falls back to `ydotool` and then Hyprland
`send_key_state`. Hyprland's synthetic key-state dispatcher has a known local
history of leaving a key repeating, so it must not be the primary transport
for automatic paste. Kitty does not receive a synthetic key at all; it gets
the immutable payload through remote control.

## Current Callers

| Source | Payload source | Injection |
|---|---|---|
| Voice auto-paste | transcription text file | central helper |
| Voice manual paste | transcription text file | central helper |
| Clipboard text | decoded cliphist file | central helper |
| Clipboard image in a terminal | generated image path file | central helper |
| Kitty smart paste | clipboard snapshot/path file | central helper |

GUI applications still receive a normal paste key because they need native
clipboard MIME handling. Kitty receives the exact text payload through remote
control with bracketed-paste support.

## Duplicate Suppression

The helper fingerprints only the immutable payload bytes. It deliberately does
not include the resolved mode, target window, or target class: closing a popup
and restoring focus are asynchronous, so two callbacks from one action can see
different targets even though they belong to the same paste transaction.

An identical payload requested within 500 ms is ignored. The clipboard QML
service also rejects a second activation of the same history entry within 900
ms, before another helper process can be spawned. Voice input accepts only the
first meaningful final result from each recording. Together these guards catch
duplicate QML signals, repeated process output, focus races, and overlapping
terminal paste handlers without blocking a normal later paste. Override the
helper interval with `SUMIKA_PASTE_DEDUPE_MS` only for diagnostics.

Runtime records are stored under:

```text
$XDG_RUNTIME_DIR/sumika-paste/events.log
```

Each record includes source, action (`inject` or `deduped`), mode, target,
payload size, and fingerprint. When duplicate insertion is reported, inspect
this log first:

- two `inject` records mean the caller/target differs and needs investigation;
- one `inject` plus one `deduped` means Sumika Shell suppressed a repeated request;
- one `inject` but two visible insertions means the receiving application or
  terminal interpreted one transport event twice. Check the recorded mode and
  transport next; GUI injection should normally use `wtype`, not Hyprland.

## Kitty Rules

Current mappings:

```ini
map ctrl+v paste_from_clipboard
map ctrl+shift+v launch --type=background sumika-kitty-smart-paste
```

`Ctrl+V` stays native. `Ctrl+Shift+V` provides Sumika Shell image-to-path behavior, but
the helper script must delegate injection to `sumika-paste-at-cursor`.

### `send-text` exit status lies

Kitty `send-text` **always reports success (`exit 0`) even when it delivers to
the wrong window, to no window, or to multiple windows.** Confirmed by
experiment: a `stty raw` + `od -c` dumper window received zero bytes while
`send-text` returned 0; in the same run a literal `send-text --match state:focused`
planted the payload in a *different* kitty window. `kitty @ ls` validating the
socket is therefore necessary but **not sufficient** — a live socket can still
accept a `send-text` that does not reach the intended target.

### `--match state:focused` multi-delivers

`--match state:focused` is **not** a precise single-window target. In certain
focus states (notably when the OS-window keyboard focus and kitty's internal
"focused" flag diverge — e.g. a remote-control `focus-window` was issued, or a
second kitty window/tmux pane shares the focused OS window) `state:focused`
matches **more than one window** and `send-text` writes the payload into *all*
of them. One `sumika-paste-at-cursor` invocation (one `inject` line in
`events.log`) then produces two visible insertions. This is the root cause of
the long-standing "voice and clipboard paste twice" report.

Empirical sweep in a two-omp-window kitty instance:

| `send-text` match | win1 (tmux/omp) | win5 (focused) |
|---|---|---|
| `--match state:focused`        | 0 or 1, drifts with focus; observed =2 | 1 |
| no `--match` (active tab active window) | 1 | 0 |
| `--match id:$id` (resolved from `kitty @ ls`) | 0 | 1 ✅ |

Only `--match id:$id` reliably delivers to exactly one window.

### Resolution contract

Because of the above, the helper must **resolve a single kitty window id** and
send with `--match id:$id`, never with `--match state:focused` or a bare
`send-text`. The resolution order is, from `kitty @ --to $socket ls`:

1. the OS window with `is_focused: true` — **no fallback to the first OS
   window** (on labwc the focus check is the only guard that keeps the remote
   path from hijacking an unfocused kitty window);
2. within it, the tab with `is_active: true` (fall back to the first tab);
3. within it, the window with `is_focused: true` (fall back to the tab's first
   window).

If that resolves to zero windows the helper must treat the send as failed and
fall back to the synthetic-key path. It must not issue a synthetic fallback
paste after an accepted remote send, because that would create a real second
insertion.

### omp 下剪贴板内容双贴的原因和修复

**问题：** kitty 有个叫 OSC 5522 enhanced paste 的协议。用 `kitty @ send-text` 发带
bracketed paste 标记的内容时，kitty 会把**当前 Wayland 剪贴板里的内容也附加上**再发给
程序。omp 正好用了这个协议，所以一次粘贴 omp 收到两份：`send-text` 的真实内容 + 剪贴板
内容。

我们的 helper 为了让 omp 能读剪贴板拿到 payload（omp 的做法），会先 `wl-copy < payload`
再把剪贴板设成 payload，然后 `send-text` 发同样一份。结果 omp 收到两遍同样的内容。

**当前修复（send-text 直接送达优先）：**

1. helper 将不可变 payload 同步到 Wayland clipboard；
2. 从 `kitty @ ls` 解析唯一窗口 ID（要求 OS 窗口 `is_focused: true`，否则视为
   焦点未知、放弃 remote 路径）；
3. 调用 `kitty @ send-text --match id:<id> --from-file <payload> --bracketed-paste auto`
   直接把 payload 文本注入目标窗口，CLI/TUI 会收到一个完整的 bracketed-paste
   transaction。发送前临时 `wl-copy -c`，发送后恢复 payload，从而规避 OMP 的
   OSC 5522 二次读取；
4. 仅当 `send-text` 不可用时，才降级到 `kitty @ action paste_from_clipboard`
   （kitty 原生粘贴），再降级到 wtype 合成按键。

**为什么不用 `paste_from_clipboard` 作主线：** kitty 的 `paste_from_clipboard` /
`shift+Insert` 读取的是 kitty **内部剪贴板缓冲**（默认 `clipboard_control` 只授予
写入权限，不授予读取权限），即用户上次在 kitty 窗口内复制的片段——而不是系统
Wayland 剪贴板里的 payload。labwc 等非 Hyprland 合成器下无法用 `hyprctl` 解析
焦点窗口 class，`WIN_CLASS` 为空，旧代码走 `*)` 分支注入 shift+Insert，于是剪贴板
菜单里选任何条目粘出来的都是 kitty 内部缓冲里那段旧文本（实测为过时的
`id="toolbar"`）。`send-text` 直接发送 payload 字节，完全绕开 kitty 内部缓冲，
不受剪贴板权限或内部状态影响。

两条路径都按整块粘贴处理，禁止使用 `--bracketed-paste disable` 发送正文。

此前使用过 `--bracketed-paste disable` 来避开 OSC 5522。虽然可以阻止 OMP 双贴，
但它会把正文作为普通 PTY 输入字节流交给应用。部分 raw-input CLI/TUI 因此逐字处理和
重绘，大文本粘贴非常慢。该方案已经废弃，不应恢复。

---

**技术背景（供深度排查参考）：** omp 启用 kitty OSC 5522 enhanced paste 协议
（`\x1b[?5522h`），`EnhancedPasteController` 解析 OSC 5522 包携带的 MIME 数据，
作为一次独立 `pasteText` 插入。本文已经合并原调查记录中仍然有效的结论。

### Socket naming

Do not assume `listen_on unix:/tmp/mykitty` from `kitty.conf` is the live
socket. Older kitty instances (or instances started before the config change)
listen on `/tmp/mykitty-$pid` instead. The helper must probe
`/tmp/mykitty-$pid`, then `/tmp/mykitty*`, then the runtime-dir variants.

## OMP/OpenCode

OMP has its own clipboard actions and Kitty enhanced-paste support. Sumika Shell must not
patch files under `~/.bun`, `~/.omp`, or another application's installation to
solve a desktop integration problem; those edits are machine-local and are
lost on upgrades.

Instead, Sumika Shell sends one bracketed payload through the terminal and keeps the
Wayland clipboard synchronized with that same payload. Application-specific
keybindings remain the application's responsibility. If OMP binds the same
manual chord as Kitty, configure one owner for that chord rather than adding a
second injection path.

## Verification

Static checks:

```sh
sh -n share/bin/omarchy-paste-at-cursor
sh -n "$SUMIKA_SHELL_EXTENSIONS_DIR/clipboard/bin/sumika-kitty-smart-paste"
```

Runtime checks:

1. Paste text from the clipboard menu into a plain shell and OMP.
2. Paste an image from the clipboard menu into both; terminal targets should
   receive one `/tmp/sumika-clip-*` path.
3. Run voice auto-paste in both targets.
4. Inspect `$XDG_RUNTIME_DIR/sumika-paste/events.log` and confirm one `inject` per
   user action.
5. **Multi-window regression:** with two kitty windows in the same OS window
   (e.g. a second omp or shell tab), trigger one paste and verify the payload
   lands in exactly one window. Count the marker with
   `kitty @ --to $SOCK get-text --match id:$ID | grep -c MARKER` for every
   window id; the sum across all windows must equal 1.
6. **send-text 主线：** payload 为 `FILE_B`，触发一次 paste 进 omp，确认日志为
   `transport=kitty-bracketed-send`，只收到一次 `FILE_B`，且不是逐字输入。重复 10 次
   确认 0 双贴。
7. **兼容回退路径：** 模拟 `send-text` 失败，确认只走一次
   `paste_from_clipboard`（`transport=kitty-native-paste`），无双贴。
8. **多行 payload：** 三行文本，确认在 omp 中多行插入不提交。
