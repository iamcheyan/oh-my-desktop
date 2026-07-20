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

Kitty `send-text` always reports success even if it did not reach a window.
Therefore the central helper validates a candidate socket with `kitty @ ls`
before sending. It must not issue a synthetic fallback paste after an accepted
remote send, because that would create a real second insertion.

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
