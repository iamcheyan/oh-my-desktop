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

### omp appends the Wayland clipboard to every bracketed paste

**This is the root cause of the original "voice and clipboard paste twice in
omp" report.** omp's smart-paste path pulls text/images/paths from the Wayland
clipboard on *every* bracketed paste it receives — independent of the paste
content and independent of tmux. Confirmed by experiment: with the Wayland
clipboard holding `CLIPONLY_ZZZ`, a bracketed paste of `FILEONLY_AAA` lands in
omp as `FILEONLY_AAA`+`CLIPONLY_ZZZ` (both inside AND outside tmux, so tmux is
not the cause).

OMD's callers deliberately run `wl-copy < payload` before the helper to keep
the Wayland clipboard synced with the paste. With omp's behavior that means a
single paste inserts the payload **twice**: once as the bracketed content and
once as omp's clipboard read. One `omd-paste-at-cursor` invocation, one
`inject` line in `events.log`, two visible insertions.

The fix lives in the helper's kitty-remote path, not in the callers: clear the
Wayland clipboard (`wl-copy -c`) immediately before `send-text` so omp's
clipboard read yields nothing, then restore `wl-copy < payload` immediately
after so the clipboard stays synced. omp reads the clipboard during the paste
delivery (synchronously with `send-text`) and has no clipboard-change watcher,
so the clear-before / restore-after window is safe; a tiny `sleep 0.05` before
the restore guards against an async `wl-paste` read that finishes just after
`send-text` returns. The restore always runs, even if the send fails, so
callers are never left with an empty clipboard.

Because this only touches the Wayland clipboard around the `send-text`, it is
harmless for non-omp kitty targets (plain shells do not read the clipboard on a
bracketed paste) and for image-as-path paste (the caller already replaced the
image with the path text before calling the helper).

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
6. **omp clipboard-append regression:** with the Wayland clipboard set to a
   known string that differs from the paste payload, trigger one paste into
   omp and verify omp's input contains only the payload, not the clipboard
   string. If the clipboard string appears, the clear-before-send guard in the
   helper regressed.
