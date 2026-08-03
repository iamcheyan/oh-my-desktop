# Smart Paste

Smart paste converts image clipboard data to a temporary file path when the
target is a terminal. Text and GUI image paste retain native clipboard
behavior.

## User Behavior

- Selecting text in the clipboard menu pastes the decoded text.
- Selecting an image while a terminal is the target creates
  `/tmp/sumika-clip-<timestamp>.<ext>` and pastes that path.
- Selecting an image for a GUI application pastes its image MIME data.
- The explicit path action always converts the image to a path.
- Kitty `Ctrl+V` remains native; its configured smart-paste chord delegates to
  the same central pipeline.

## Single Paste Pipeline

Every programmatic paste must call:

```sh
sumika-paste-at-cursor
```

Feature code must not directly add `kitty @ send-text`, `wtype`, `ydotool`, or
Hyprland key injection. The helper owns payload capture, target resolution,
terminal dispatch, bracketed paste, fallbacks, duplicate suppression, and
diagnostic logging.

Prefer an immutable file payload:

```sh
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
printf '%s' "$text" > "$payload"
SUMIKA_PASTE_SOURCE=my-feature \
  sumika-paste-at-cursor --file "$payload" auto "$window_class" "$window_target"
```

The clipboard service decodes cliphist entries before invoking the helper. It
uses `hyprctl activewindow -j` or the saved target address to resolve the target window.

---

## Execution & Architecture Model (No Daemon)

The paste pipeline operates as an **on-demand, single-pass pipeline** with zero persistent background services:

```
[Voice Recognition / Clipboard Action]
                 │
                 ▼
 1. Snapshot Focus Window Info (class + address) at start of action
                 │
                 ▼
 2. Write Immutable Payload to Disk (/tmp/sumika-paste/payload.XXXXXX)
                 │
                 ▼
 3. Invoke `sumika-paste-at-cursor --file $payload auto $class $address`
                 │  (Spawns ephemeral bash process, exits immediately after paste)
                 ├───────────────────────────────┐
                 ▼                               ▼
       Wayland Native Target            XWayland Target
    ┌─────────────────────────┐     ┌─────────────────────────┐
    │ 1. wl-copy              │     │ 1. xsel -bi (X11 clip)  │
    │ 2. Kitty Remote / wtype │     │ 2. xdotool key --window │
    │ 3. ydotool fallback     │     └─────────────────────────┘
    └─────────────────────────┘
```

- **No Daemon Overhead**: `sumika-paste-at-cursor` is spawned as a short-lived process per paste invocation.
- **State & Deduplication**: Duplicate suppression is handled statelessly via atomic file locks (`flock`) and timestamp files in `$XDG_RUNTIME_DIR/sumika-paste/`.

---

## XWayland & Multi-Protocol Support

XWayland applications (e.g., WeChat, WPS Office, legacy GTK2/Qt4 apps) require specialized protocol handling due to Wayland isolation:

1. **Clipboard Separation**: `wl-copy` writes strictly to the Wayland clipboard data offer. XWayland clients read from the X11 `CLIPBOARD` selection. Without a bridge, `wl-copy` appears to succeed while XWayland apps see an empty or stale clipboard.
2. **Virtual Keyboard Isolation**: Wayland virtual keyboard protocols (`wtype` / `ydotool` via `uinput`) cannot synthesize events for XWayland surfaces because key events are routed through `Xwayland`. `wtype` returns exit status 0 (as the Wayland protocol accept succeeded), but key events never reach the X11 surface.

### Generalized Solution

`sumika-paste-at-cursor` automatically detects XWayland targets using compositor metadata:

- **Detection**: `resolve_xwayland()` checks `hyprctl clients` for `.xwayland == true` matching the target window address or active window. No per-app hardcoding is required.
- **X11 Clipboard Injection**: Writes the payload directly to the X11 `CLIPBOARD` via `xsel --input --clipboard`.
- **Targeted Keystroke Dispatch**: Uses `xdotool key --window $x11_wid --clearmodifiers ctrl+v`. The `--window` parameter delivers the key event directly to the target X11 window ID without stealing active compositor window focus or requiring X11 focus changes.

---

## Component Dependency Breakdown & Standalone Decoupling

The voice input and paste stack is designed with modular boundaries. Below is a breakdown of generic Linux dependencies versus desktop-environment-specific integrations, along with the roadmap for decoupling into a standalone binary/CLI.

### Component Dependency Matrix

| Category | Component | Dependency | DE Dependence | Portable Replacement / Alternative |
|---|---|---|---|---|
| **Audio Capture** | `parecord` | PulseAudio / PipeWire | **None** (Generic Linux audio) | Standard `alsa-utils` / `pw-cat` / `sox` |
| **Voice Inference** | `sherpa-onnx` | Python 3 + SenseVoice Small | **None** (Generic Python) | Standalone C++ ONNX Runtime binary |
| **Wayland Clipboard** | `wl-copy` | `wl-clipboard` | **None** (Standard Wayland) | Any Wayland clipboard utility |
| **X11 Clipboard** | `xsel` | `xsel` / `xclip` | **None** (Standard X11) | `xclip -selection clipboard` |
| **Wayland Key Injection** | `wtype` | `wtype` | **None** (Wayland `virtual-keyboard-v1`) | `ydotool` / compositor-native key API |
| **X11 Key Injection** | `xdotool` | `xdotool` | **None** (Standard X11 / XTest) | `xdotool` / `xdotool type` |
| **Window Metadata & Focus** | `hyprctl activewindow / clients` | Hyprland IPC | **Hyprland Specific** | `swaymsg` (Sway), `xprop`/`xdotool` (X11), or `/proc` active window lookup |
| **Hotkey Triggering** | `hypr/bindings.lua` | Hyprland config | **Hyprland Specific** | `sxhkd`, `keyd`, `actkbd`, `sway` hotkeys, or DE shortcut manager |
| **UI & State Machine** | `VoiceInput.qml` | Quickshell (QtQuick) | **Sumika/Quickshell Specific** | Standalone GTK/Qt tray app, CLI runner, or D-Bus daemon |

### Decoupling Roadmap (Standalone Binary / CLI)

To package the voice-input and auto-paste feature into a standalone tool usable on **any** Linux desktop environment (GNOME, KDE, Sway, Wayfire, Hyprland):

1. **Replace Compositor Window Queries**:
   - For Wayland: Abstract window queries behind a generic provider (`hyprctl` for Hyprland, `swaymsg` for Sway, `wlrctl` or `ext-foreign-toplevel-list` for generic wlroots).
   - For XWayland/X11: Use `xdotool getactivewindow` and `xprop -id $wid WM_CLASS` directly.
2. **Decouple Triggering Mechanism**:
   - Provide a CLI interface (`sumika-voice toggle`, `sumika-voice record-start`, `sumika-voice record-stop`).
   - Allow user to bind the CLI command to any global hotkey manager (`sxhkd`, GNOME Keyboard Shortcuts, KDE Shortcuts, Sway `bindsym`).
3. **Standalone Runtime**:
   - Compile the Python daemon & `sherpa-onnx` into a single-file binary using PyInstaller or Rust/C++ bindings.
   - Run as a user-level `systemd --user` background service or socket-activated daemon.

---

## Key Files

- `quickshell/modules/clipboard/bin/sumika-paste-at-cursor`
- `extensions/voice/VoiceInput.qml`
- `extensions/voice/bin/omarchy-paste-at-cursor`
- `docs/features/voice-input.md`
- `docs/features/paste-kitty-conflicts.md`

## Verification

Test text and image entries against a GUI application, a plain shell, Kitty, an XWayland app (e.g. WeChat, `zenity`), and a raw-input CLI/TUI. Each user action must insert exactly once, and large text must arrive as one bracketed paste transaction rather than typed bytes.
