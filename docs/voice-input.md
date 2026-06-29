# OMD Voice Input — Design & Implementation

## Overview

OMD Voice Input is a voice-to-text module for the Quickshell status bar, inspired by [kazamo](https://github.com/iamcheyan/kazamo). It records audio via PulseAudio, transcribes using SenseVoice (sherpa-onnx), and auto-pastes text at the cursor via `wl-copy` + `ydotool`.

**Key design goals:**
- Zero-install for the user: first use triggers automatic dependency + model download
- Fast after warmup: long-lived Python daemon keeps model loaded in memory
- Clean, focused feedback: three-state color system on the bar icon with transparent background
- Unified TUI style & layout: terminal companion tools utilize OMD's TUI design system and open as floating window dialogs

---

## Reference Project: kazamo

[kazamo](https://github.com/iamcheyan/kazamo) is a standalone voice input tool that we forked concepts from. Key differences in our implementation:

| Aspect | kazamo | OMD Voice |
|--------|--------|-----------|
| UI | CLI + optional tray icon | Quickshell bar button + popup panel |
| Architecture | per-arch binaries (ARM vs x86) | single Python codebase via sherpa-onnx |
| Model | ARM: SenseVoice ONNX INT8; x86: Whisper GGUF | single model: SenseVoice Small ONNX INT8 (works on both) |
| Inference | direct Python call each time | long-lived Unix socket daemon |
| Auto-paste | `wl-copy` + `ydotool` | same, but with clipboard fallback |
| Feedback | terminal stdout | button colors + hover tooltip + history panel |
| Integration | standalone binary | integrated into OMD bar module system |

We chose **sherpa-onnx** (instead of faster-whisper/whisper.cpp) because:
1. Single wheel works on both ARM (Asahi) and x86 — no per-arch logic
2. Model is ~500MB INT8 vs 1-3GB for Whisper — smaller download
3. Startup is acceptable after first daemon load (~2-3s on M1 Pro)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Layer                            │
│  ALT+A (hotkey)  ──or──  Bar mic button click               │
│  Right-click button → Context menu → Settings/Test/Clear    │
└──────────────────────┬──────────────────────────────────────┘
                       │ IPC (qs ipc call voice toggle)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              VoiceInput.qml (QML Singleton)                  │
│  State machine: init → setup → idle → recording →            │
│                 transcribing → success/error                 │
│  - Property bindings: state, history[], modelSizeMB, etc.    │
│  - ESC key cancellation binding & listener via IPC           │
└──────────────────────┬──────────────────────────────────────┘
                       │ Process { command: [...] }
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Shell Scripts (bash)                      │
│  omarchy-voice-setup     → python3 -m venv + pip install     │
│  omarchy-voice-download  → curl model.int8.onnx + tokens.txt │
└──────────────────────┬──────────────────────────────────────┘
                       │ Process { command: python3 ... }
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           omarchy-voice-transcribe (Python daemon)           │
│  Fork model: first caller starts daemon, waits for socket    │
│  Socket: /tmp/omd-voice.sock                                 │
│  Loop: accept → recv wav_path → transcribe → send JSON       │
│  Output: {"text": "..."} or {"error": "..."}                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ parecord /tmp/omd-voice-rec.wav
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              System Layer (PulseAudio / PipeWire)            │
│  parecord --format=s16le --rate=16000 --channels=1           │
│  WAV → sherpa_onnx.OfflineRecognizer.from_sense_voice()      │
│  → wl-copy + ydotool key Ctrl+V (auto-paste)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## State Machine

```
                    ┌──────────────┐
                    │     init     │
                    └──────┬───────┘
                           │ Component.onCompleted: checkState()
                           ▼
                    ┌──────────────┐
                    │    setup     │ ←──────┐
                    │  (model/venv │        │
                    │   missing)   │        │
                    └──────┬───────┘        │
          click/setup()    │                │
                           │                │
                           ▼                │
            ┌────────────────────────┐      │
            │  → setupProc (venv)    │      │
            │  → downloadProc (model)│      │
            │  → auto startRecording()│     │
            └───────────┬────────────┘      │
                        │                    │
                        ▼                    │
              ┌─────────────────┐            │
              │      idle       │ ←──────────┘
              │   (ready)       │  checkState()
              └────────┬────────┘
         toggle()      │
                       ▼
              ┌─────────────────┐
              │   recording     │ ◄──── 黄色脉冲环 (ESC 取消)
              │  (parecord)     │
              └────────┬────────┘
         toggle()      │
                       ▼
              ┌─────────────────┐
              │  transcribing   │ ◄──── 黄色脉冲环
              │  (socket →      │
              │   daemon)       │
              └────────┬────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
  ┌────────────┐            ┌─────────────┐
  │   success  │            │    error    │
  │ 图标复位   │            │ 红色闪烁两次│
  │            │            │ 2.0s后→idle │
  └────────────┘            └─────────────┘
```

### Visual & Interactive Feedback

The status bar button (`VoiceButton.qml`) uses a simplified three-state indicator with a completely transparent background to reduce UI clutter:

- **Idle (闲置)**: The microphone icon is rendered in the default text color (White).
- **Active (录音与转写)**: The microphone icon and an outer pulsing ring are colored **Yellow** (`#F5C542`).
- **Error (失败)**: The microphone icon turns **Bright Red** (`#FF3B30`) and **flashes twice** before automatically resetting back to **Idle** after 2 seconds.
- **Hover (悬浮)**: Moving the cursor over the icon shows a tooltip with active shortcut bindings: `语音输入 (ALT + A / Globe)`.

---

## Active Key Bindings

| Key | Mode | Description |
|-----|------|-------------|
| `ALT + A` | Global | Toggles recording (press to start, press again to transcribe). |
| `Globe` (MacBook Fn) | Global | Hardware key (keycode `472`) mapped to toggle recording. |
| `ESC` | Recording-only | Cancels active recording, stops `parecord`, and returns state to `idle` silently. |

### Recording-only ESC Key Hook

To minimize global hotkey conflicts, `escape` is dynamically bound **only during the recording phase**:
1. When `state` becomes `"recording"`, QML runs `hyprctl eval` to bind `escape` to dispatch `voice cancel`.
2. When `state` leaves `"recording"` (success, error, or cancel), QML runs `hyprctl eval` to execute `hl.unbind("escape")`.
3. This ensures the ESC key functions normally in all other applications when not actively recording.

---

## Key Capture Tool (`scripts/key-test`)

Because Wayland input protocols isolate keystrokes, capturing raw hardware events (like the MacBook Fn/Globe key or Super key modifier combos) is impossible within a standard terminal shell.

To resolve this, `scripts/key-test` is written as a native **GTK4 / Libadwaita** application that runs in its own Wayland client window, allowing it to capture raw events from the compositor while styled with custom CSS to look like a premium terminal utility.

**Key features:**
- **Wayland Shortcut Inhibition**: Calls `surface.inhibit_system_shortcuts(None)` on realize so the compositor passes system events to the window.
- **Dynamic Hotkey Suspension**: When focused (`is-active = True`), it temporarily runs `hl.unbind` for conflicting OMD hotkeys (`ALT + A`, `code:472`, `ALT + S`, `CTRL + SHIFT + V`, `SUPER + SPACE`, `SUPER + V`) to prevent them from intercepting test keys.
- **Automatic Restore via `atexit`**: When the window loses focus or the process exits (via window close, pressing Q/ESC, or being killed), a Python exit-hook runs `hyprctl reload` to restore all keybinds instantly.
- **Clipboard Output**: Formats the captured keys (e.g. `ALT + A` or `code:472`) and runs `wl-copy` to copy them to the clipboard automatically.

---

## Diagnostic Tool (`scripts/voice-diagnose`)

A curses-based terminal application designed to troubleshoot the voice input environment. It runs in a floating window matching OMD's TUI design system.

It runs automated tests for the following components:
1. **Python Virtual Environment**: Checks that `~/.cache/omd-voice/venv` is present.
2. **Required Libraries**: Assures `sherpa-onnx` and `numpy` import properly.
3. **Model Files**: Verifies `model.int8.onnx` and `tokens.txt` integrity.
4. **Unix Socket Daemon**: Connects to `/tmp/omd-voice.sock` to check engine responsiveness.
5. **Recording Utilities**: Confirms presence of `parecord`.
6. **Audio Helper**: Confirms `ffmpeg` is available for audio resampling.
7. **Clipboard & Paste Support**: Assures `wl-copy` and `ydotool` are configured.

Failed checks display actionable troubleshooting steps at the bottom of the interface.

---

## File Layout

```
share/bin/
├── omarchy-voice-setup          # venv creation + pip install sherpa-onnx numpy
├── omarchy-voice-download       # curl SenseVoice ONNX INT8 model (~500MB)
├── omarchy-voice-record         # parecord lifecycle + graceful WAV finalization
└── omarchy-voice-transcribe     # Python daemon with Unix socket

scripts/
├── voice-test-tui               # Curses-based TUI recording test
├── key-test                     # GTK4 Advanced key capture tool (Wayland raw keycodes)
└── voice-diagnose               # Curses-based voice environment diagnostic tool

quickshell/services/
└── VoiceInput.qml               # Singleton service: state machine, IPC, ESC hook

quickshell/modules/bar/
├── VoiceContextMenu.qml         # Right-click popup menu (Start, Test, Capture, Diagnostic)
├── modules/VoiceButton.qml      # Bar button with simplified state colors + Tooltip
├── RightModuleRegistry.qml      # registers "util:voice"
└── BarStatusPopup.qml           # adds voiceContent settings panel

omarchy/hypr/
└── looknfeel.lua                # Hyprland window rules for floating TUI tools (1000x700)
```

---

## IPC Interface

```qml
IpcHandler {
    target: "voice"
    function toggle(): void { root.toggle() }
    function cancel(): void { root.cancel() }
}
```

The IPC is triggered by global keybinds or the dynamic `escape` hook to control recording states asynchronously.

---

## Related Files

- `omarchy/hypr/bindings.lua` — key bindings definitions
- `omarchy/hypr/looknfeel.lua` — window floating rules
- `quickshell/services/VoiceInput.qml` — voice service state machine
- `quickshell/modules/bar/modules/VoiceButton.qml` — bar status button
- `scripts/key-test` — GTK4 key capture
- `scripts/voice-diagnose` — TUI diagnostic tool
gs.lua`: `ALT + A` → `qs -p ... ipc call voice toggle`
- `VoiceButton.qml`: left click
- `VoiceContextMenu.qml`: test action

The bar also exposes `barPopup` IPC for opening the settings panel:
```bash
qs -p $HOME/.config/omd/apps/omd-bar ipc call barPopup open voice
```

---

## Auto-Paste Mechanism

```javascript
function onTranscriptionResult(text) {
    // 1. Always copy to clipboard (reliable)
    Quickshell.execDetached(["bash", "-c",
        `printf '%s' '${StringUtils.shellSingleQuoteEscape(text)}' | wl-copy`])
    // 2. Delay then attempt auto-paste (ydotool may fail if no focused input)
    Quickshell.execDetached(["bash", "-c",
        `sleep 0.3 && ${root.pressPasteCommand} || true`])
}
```

`pressPasteCommand`:
```bash
YDOTOOL_SOCKET=/tmp/.ydotool_socket ydotool key -d 1 29:1 47:1 47:0 29:0
```
(29 = Ctrl, 47 = V)

Even if ydotool fails (no focused text field), the text is already in the clipboard.

---

## Cache & Paths

| Path | Purpose |
|------|---------|
| `~/.cache/omd-voice/` | Root cache dir |
| `~/.cache/omd-voice/venv/` | Python venv with sherpa-onnx |
| `~/.cache/omd-voice/sense-voice-small-int8/` | ONNX model + tokens |
| `/tmp/omd-voice.sock` | Unix socket for daemon |
| `/tmp/omd-voice-rec.wav` | Temporary recording file |
| `/tmp/omd-voice-rec.pid` | parecord PID file |

---

## Performance Notes

- **First startup:** ~30s (venv creation + pip install + model download)
- **Model load (daemon fork):** ~2-3s on Apple M1 Pro, ~4-6s on typical x86
- **Warm transcription:** ~200-800ms for 3-5 second recordings
- **Memory:** ~450MB RSS for loaded model
- **Disk:** ~229MB model + ~150MB venv

---

## Known Limitations

1. **Language:** Currently hardcoded to Chinese (`zh`) in `omarchy-voice-transcribe`. To support other languages, change `LANGUAGE` env var or add a setting.
2. **ydotool dependency:** Auto-paste requires `ydotoold` running. If missing, text is still copied to clipboard.
3. **Single model:** Only SenseVoice Small INT8 is supported. Adding Whisper or other models would require significant changes to the transcribe script.
4. **No VAD:** Recording continues until user manually stops (no voice activity detection auto-stop).

---

## Future Ideas

- [ ] Language selector in settings panel (zh/en/ja/ko/yue)
- [ ] VAD auto-stop (use webrtcvad or silero-vad)
- [ ] Live streaming transcription (instead of file-based)
- [ ] Per-app paste target (paste to specific window)
- [ ] Model hot-swap (Whisper vs SenseVoice)
- [ ] Audio input device selector
- [ ] Export history to file

---

## Related Files

- `docs/tui-style-system.md` — visual design tokens
- `docs/module-split-plan.md` — Quickshell app process architecture
- `AGENTS.md` — agent working agreement & project conventions
