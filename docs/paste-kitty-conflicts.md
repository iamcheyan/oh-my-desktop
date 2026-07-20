# Paste Pipeline and Kitty/TUI Conflicts

This document records how OMD sends clipboard and voice text into applications,
why duplicate insertion can occur, and the contract all paste features must
follow.

## Single Entry Point

All programmatic paste operations must use:

```sh
~/.config/omd/bin/omd-paste-at-cursor
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
OMD_PASTE_SOURCE=my-feature \
  omd-paste-at-cursor --file "$payload" auto "$window_class" "$window_target"
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
helper interval with `OMD_PASTE_DEDUPE_MS` only for diagnostics.

Runtime records are stored under:

```text
$XDG_RUNTIME_DIR/omd-paste/events.log
```

Each record includes source, action (`inject` or `deduped`), mode, target,
payload size, and fingerprint. When duplicate insertion is reported, inspect
this log first:

- two `inject` records mean the caller/target differs and needs investigation;
- one `inject` plus one `deduped` means OMD suppressed a repeated request;
- one `inject` but two visible insertions means the receiving application or
  terminal interpreted one transport event twice. Check the recorded mode and
  transport next; GUI injection should normally use `wtype`, not Hyprland.

## Kitty Rules

Current mappings:

```ini
map ctrl+v paste_from_clipboard
map ctrl+shift+v launch --type=background ~/.config/omd/bin/omd-kitty-smart-paste
```

`Ctrl+V` stays native. `Ctrl+Shift+V` provides OMD image-to-path behavior, but
the helper script must delegate injection to `omd-paste-at-cursor`.

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
of them. One `omd-paste-at-cursor` invocation (one `inject` line in
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

1. the OS window with `is_focused: true` (fall back to the first OS window);
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

**修复（双路决策）：**

- **主线（~95% 场景）**：payload 是纯文本、路径等不带控制字符的内容 → `--bracketed-paste disable`
  发原始字节，不发 bracketed paste 标记 → kitty 不触发 OSC 5522 → omp 不去读剪贴板 →
  完全不碰剪贴板，零副作用，对 omp/bash/任何 TUI 都安全。
- **回退（~5% 场景）**：payload 含 `ESC` / `Ctrl+C` 等控制字符（用 bracket 包裹安全） →
  `--bracketed-paste auto` + 发前 `wl-copy -c` 清空剪贴板 + 发后 `wl-copy < payload` 恢复。
  这样 omp 读剪贴板时读到空，不会多插一遍。

**如何判断 "含控制字符"：** `is_control_char_free()` 用 POSIX `od` 扫描 payload 每个字节，
放行 `\t\n\r`，只要有其他 C0 控制符（`\x00-\x08\x0b\x0c\x0e-\x1f`）或 `\x7f`(DEL) 就算。

---

**技术背景（供深度排查参考）：** omp 启用 kitty OSC 5522 enhanced paste 协议
（`\x1b[?5522h`），`EnhancedPasteController` 解析 OSC 5522 包携带的 MIME 数据，
作为一次独立 `pasteText` 插入。触发链和上游 issue 见
`docs/omp-bracketed-paste-double-investigation.md` 第 11 节。

### Socket naming

Do not assume `listen_on unix:/tmp/mykitty` from `kitty.conf` is the live
socket. Older kitty instances (or instances started before the config change)
listen on `/tmp/mykitty-$pid` instead. The helper must probe
`/tmp/mykitty-$pid`, then `/tmp/mykitty*`, then the runtime-dir variants.

## OMP/OpenCode

OMP has its own clipboard actions and Kitty enhanced-paste support. OMD must not
patch files under `~/.bun`, `~/.omp`, or another application's installation to
solve a desktop integration problem; those edits are machine-local and are
lost on upgrades.

Instead, OMD sends one bracketed payload through the terminal and keeps the
Wayland clipboard synchronized with that same payload. Application-specific
keybindings remain the application's responsibility. If OMP binds the same
manual chord as Kitty, configure one owner for that chord rather than adding a
second injection path.

## Verification

Static checks:

```sh
sh -n share/bin/omarchy-paste-at-cursor
sh -n bin/omd-kitty-smart-paste
```

Runtime checks:

1. Paste text from the clipboard menu into a plain shell and OMP.
2. Paste an image from the clipboard menu into both; terminal targets should
   receive one `/tmp/omd-clip-*` path.
3. Run voice auto-paste in both targets.
4. Inspect `$XDG_RUNTIME_DIR/omd-paste/events.log` and confirm one `inject` per
   user action.
5. **Multi-window regression:** with two kitty windows in the same OS window
   (e.g. a second omp or shell tab), trigger one paste and verify the payload
   lands in exactly one window. Count the marker with
   `kitty @ --to $SOCK get-text --match id:$ID | grep -c MARKER` for every
   window id; the sum across all windows must equal 1.
6. **原始字节路径（主线）：** 剪贴板设 `CLIP_A`，payload 为 `FILE_B`，触发一次
   paste 进 omp 并确认只收到 `FILE_B`。验证 `wl-paste` 仍返回 `CLIP_A`
   （剪贴板未被动过）。重复 10 次确认 0 双贴。
7. **控制字符回退路径：** payload 含 ESC（如 `printf 'ab\x1bcd'`），确认走
   `--bracketed-paste auto` + 清空/恢复，无双贴。
8. **多行 payload：** 三行文本，确认在 omp 中多行插入不提交。
