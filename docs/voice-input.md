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
              │   mic / white   │
              └────────┬────────┘
         toggle()      │
                       ▼
              ┌─────────────────┐
              │   recording     │ ◄──── 黄色脉冲环 + 麦克风闪烁 (ESC 取消)
              │  (parecord)     │      icon: mic (yellow, blinking)
              └────────┬────────┘
         toggle()      │
                       ▼
              ┌─────────────────┐
              │  transcribing   │ ◄──── 蓝色环 + 漏斗旋转
              │  (socket →      │      icon: hourglass 0.72× (blue, rotating)
              │   daemon)       │
              └────────┬────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
  ┌────────────┐            ┌─────────────┐
  │   success  │            │    error    │
  │ 图标复位   │            │ 红色闪烁4次 │
  │            │            │ 2.0s后→idle │
  └────────────┘            └─────────────┘
```

### Visual & Interactive Feedback

The status bar audio button (`AudioButton.qml`) provides distinct visual states so the
user can tell at a glance whether the system is recording, transcribing, or idle:

| State | Icon | Color | Animation | Ring |
|-------|------|-------|-----------|------|
| **Idle** | mic | white (default text) | none | none |
| **Recording** | mic (normal size) | yellow `#F5C542` | blink 1.0↔0.3 opacity (500ms breath) | pulsing yellow ring (scale 1.0→1.65, 750ms) |
| **Transcribing** | hourglass (0.72× size) | blue `#5B9BD5` | slow rotation 0→180° (2s, InOutQuad) | static blue ring |
| **Setup** | mic | yellow | none | pulsing yellow ring |
| **Error** | current icon | red `#FF3B30` | fast blink 4× (80ms each) then auto-reset | none |
| **Hover** | — | — | tooltip: `语音输入 (ALT + A / Globe)` | — |

Design rationale for separate recording vs transcribing icons:
- A **blinking microphone** during recording gives the user confidence the mic
  is live (like a recording indicator on a dictaphone).
- A **smaller, rotating hourglass** during transcription makes it obvious the
  model is working, not that the mic is still recording.
- The hourglass icon (`fa-hourglass` U+F254) is visually large at the same
  font size as the mic, so it is rendered at 0.72× the normal bar icon size to
  match optical weight.
- Color separation (yellow → blue) reinforces the phase transition at a glance.

---

## Active Key Bindings

| Key | Mode | Description |
|-----|------|-------------|
| `ALT + A` | Global | Toggles recording (press to start, press again to transcribe). |
| `Globe` (MacBook Fn) | Global | Hardware key (keycode `472`) mapped to toggle recording. |
| `ESC` | Recording-only | Cancels active recording, stops `parecord`, and returns state to `idle` silently. |

Additional bindings are read from:

```sh
~/.config/omd/config/voice_bindings.txt
```

Edit them in Settings Center (Voice page) or through `scripts/voice-bind-tui`. The capture tool uses `scripts/key-test --hotkey`, so it captures the final key after keyd remaps rather than the physical source key.

### Recording-only ESC Key Hook

To minimize global hotkey conflicts, `escape` is dynamically bound **only during the recording phase**:
1. When `state` becomes `"recording"`, QML runs `hyprctl eval` to bind `escape` to dispatch `voice cancel`.
2. When `state` leaves `"recording"` (success, error, or cancel), QML runs `hyprctl eval` to execute `hl.unbind("escape")`.
3. This ensures the ESC key functions normally in all other applications when not actively recording.

---

## Key Capture Tool (`scripts/key-test`)

Because Wayland input protocols isolate keystrokes, capturing hotkeys (like F13 generated by keyd, the MacBook Fn/Globe key, or Super key modifier combos) is impossible within a standard terminal shell.

To resolve this, `scripts/key-test --hotkey` is written as a native **GTK4 / Libadwaita** application that runs in its own Wayland client window, allowing it to capture the final key events seen by applications after keyd remaps while styled with custom CSS to look like a premium terminal utility. Keyboard Remap uses `--remap-source` instead when it needs physical source keys.

**Key features:**
- **Wayland Shortcut Inhibition**: Calls `surface.inhibit_system_shortcuts(None)` on realize so the compositor passes system events to the window.
- **Dynamic Hotkey Suspension**: When focused (`is-active = True`), it temporarily runs `hl.unbind` for conflicting OMD hotkeys (`ALT + A`, `code:472`, `ALT + S`, `CTRL + SHIFT + V`, `SUPER + SPACE`, `SUPER + V`) to prevent them from intercepting test keys.
- **Automatic Restore via `atexit`**: When the window loses focus or the process exits (via window close, pressing Q/ESC, or being killed), a Python exit-hook runs `hyprctl reload` to restore all keybinds instantly.
- **Clipboard Output**: Formats the captured keys (e.g. `ALT + A` or `code:472`) and runs `wl-copy` to copy them to the clipboard automatically.

### Capture modes

Running `scripts/key-test` without arguments opens an in-window mode switch.
It defaults to **Current key value**, which leaves keyd running, and can switch
to **Original key value**, which temporarily pauses keyd. Changing modes clears
the previous result so values from the two layers are not mixed.

Integration callers use two explicit preferred modes. The switch remains
visible for inspection, but only a capture made in the caller's expected mode
is exported back to that workflow:

| Mode | Used by | keyd state | Captures |
|------|---------|------------|----------|
| `--remap-source` | Keyboard Remap source capture | Temporarily stopped | Physical source key for keyd `from` |
| `--hotkey` | Voice binding / app hotkeys | Left running | Final key seen by apps after keyd |

Voice Input must use `--hotkey`. If a spare physical key is remapped by keyd to an extended function key, the voice binding should capture the post-remap key.

### F13 / XF86Tools note

Extended F keys are not always presented to applications as literal `F13` through `F24`. On the current JP layout, mapping a physical key to keyd `f13` may be seen by GTK/GDK as `Tools`; Hyprland expects the binding name `XF86Tools`.

Correct workflow:

1. Keyboard Remap: map the physical key to `f13`.
2. Apply keyd changes.
3. Voice bindings: run capture through `scripts/voice-bind-tui` (`key-test --hotkey`).
4. Save the captured result, e.g. `XF86Tools`.

Do not manually save `TOOLS`; Hyprland reports `Unknown keysym: "TOOLS"`. If this happens, replace it with `XF86Tools` and reload:

```sh
sed -i 's/^TOOLS$/XF86Tools/' ~/.config/omd/config/voice_bindings.txt
hyprctl reload
```

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
├── key-test                     # GTK4 Advanced key capture tool (hotkey mode captures final keys after keyd remaps)
└── voice-diagnose               # Curses-based voice environment diagnostic tool

quickshell/services/
└── VoiceInput.qml               # Singleton service: state machine, IPC, ESC hook

quickshell/modules/bar/
├── VoiceContextMenu.qml         # Right-click popup menu (Start, Test, Capture, Diagnostic)
├── AudioVoiceHoverPopup.qml     # Hover details for the combined audio/voice button
├── modules/AudioButton.qml      # Combined audio popup button and voice state/action button
├── BarContent.qml               # instantiates AudioButton directly in the fixed topbar
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

## Settings UI

The Settings Center Voice panel is being redesigned as a master–detail page
(status + trial record on the left; keybindings and advanced tools on the
right). Full product/layout plan:

- `docs/voice-settings-redesign.md`

Implementation: `quickshell/modules/settings/pages/VoicePage.qml`.

## Related Files

- `hypr/bindings.lua` — key bindings definitions (reads `config/voice_bindings.txt`)
- `hypr/looknfeel.lua` — window floating rules
- `quickshell/services/VoiceInput.qml` — voice service state machine
- `quickshell/modules/bar/modules/AudioButton.qml` — combined bar audio/voice button
- `quickshell/modules/settings/pages/VoicePage.qml` — Settings Center voice page
- `scripts/key-test --hotkey` — GTK4 hotkey capture after keyd remaps
- `scripts/voice-diagnose` — TUI diagnostic tool
- `docs/voice-settings-redesign.md` — settings UX redesign plan

### Bar entry points

- `bindings.lua`: voice toggles → `qs -p ... ipc call voice toggle`
- `AudioButton.qml`: left click while voice is active toggles recording; otherwise opens audio status popup
- `VoiceContextMenu.qml`: test action

The bar also exposes `barPopup` IPC for opening the settings panel:

```bash
qs -p $HOME/.config/omd/apps/omd-bar ipc call barPopup open voice
```

---

## Auto-Paste Mechanism

Auto-paste adapts the keystroke to the focused window class so that both
terminals (which bind paste to `Shift+Insert` / `Ctrl+Shift+V`) and GUI apps
(which bind paste to `Ctrl+V`) get the right key.

```javascript
// 录音开始时记录焦点窗口 class
function startRecording() {
    focusClassProc.running = true   // 异步刷新 focusedWindowClass
    ...
}

function onTranscriptionResult(text) {
    // 1. Always copy to clipboard (reliable)
    Quickshell.execDetached(["bash", "-c",
        `printf '%s' '${StringUtils.shellSingleQuoteEscape(text)}' | wl-copy`])
    // 2. 按 class 选 paste 命令，延迟发送
    const pasteCmds = root.resolvePasteCommands()
    Quickshell.execDetached(["bash", "-c",
        `sleep 0.3 && ${pasteCmds.primary} || true`])
}
```

`pasteCommandForClass` 映射（见 `VoiceInput.qml`）：

| 窗口 class                              | paste 命令               | 原因                    |
|----------------------------------------|--------------------------|-------------------------|
| `foot` / `kitty` / `alacritty` / `ghostty` / `wezterm` / `konsole` / `xterm` … | `wtype -M shift -k Insert` | 终端粘贴绑定 Shift+Insert |
| `google-chrome` / `firefox` / `code` / `obsidian` / `telegram` / `discord` … | `wtype -M ctrl -k v`      | GUI 应用粘贴绑定 Ctrl+V  |
| 未知 class                             | `wtype -M shift -k Insert` | 默认：终端+GUI 通用     |

### 为什么不用 ydotool

`ydotool` 发的是 Linux kernel scancode（`47` = `KEY_V`），但 Hyprland 把
`ydotoold` 虚拟键盘按当前 XKB layout（如 JP）解释，scancode 47 在 JP 布局下不
是字母 `V`，导致 `Ctrl+V` 按成别的键、粘贴失效。`wtype` 走 Wayland
`virtual-keyboard` 协议直接发 keysym，绕过 layout 映射，更可靠。

### 为什么终端用 Shift+Insert 而非 Ctrl+V

终端（foot/kitty/ghostty）的粘贴绑定是 `Shift+Insert` 或 `Ctrl+Shift+V`，不是
`Ctrl+V`——`Ctrl+V` 在终端里被当作普通控制字符传给程序。Hyprland 的 `Super+V`
全局粘贴之所以在终端里有效，是因为 `share/default/hypr/bindings/clipboard.lua`
把 `Super+V` 映射成发送 `Shift+Insert`。语音输入法沿用同样的键。

Even if auto-paste fails (no focused text field), the text is already in the clipboard.

---

## Cache & Paths

| Path | Purpose |
|------|---------|
| `~/.cache/omd-voice/` | Root cache dir |
| `~/.cache/omd-voice/venv/` | Python venv with sherpa-onnx |
| `~/.cache/omd-voice/sense-voice-small-int8/` | ONNX model + tokens |
| `~/.cache/omd-voice/transcribe.log` | Per-call timing log (JSON lines) |
| `/tmp/omd-voice.sock` | Unix socket for daemon |
| `/tmp/omd-voice-rec.wav` | Temporary recording file |
| `/tmp/omd-voice-rec.pid` | parecord PID file |
| `/tmp/omd-voice.pid` | Daemon PID file |

---

## Performance Notes

### End-to-end latency breakdown

The total perceived delay from "user presses stop" to "text appears in the
target window" is the sum of several stages:

| Stage | Typical time | Notes |
|-------|-------------|-------|
| Recording stop (`omarchy-voice-record stop`) | 100–200ms | kill parecord + `sleep 0.1` for WAV finalization |
| FFmpeg preprocessing | 40–50ms | resample to 16kHz mono + 20dB gain |
| sherpa-onnx inference (decode) | 350–450ms | for 3–5s audio on Intel i5-10310U (4 threads) |
| Paste delay (`OMD_PASTE_DELAY`) | 150ms | sleep before simulating Ctrl+V / Shift+Insert |
| wtype / ydotool key dispatch | ~50ms | Wayland virtual-keyboard paste |
| **Total** | **~700–900ms** | from stop-press to text-in-window |

### Inference benchmarks (Intel i5-10310U 1.70GHz, 8 cores)

Measured on the actual development machine using the long-lived daemon
(`~/.cache/omd-voice/transcribe.log`):

| Audio duration | ffmpeg_ms | load_ms | decode_ms | total_ms | RTF |
|---------------|-----------|---------|-----------|----------|-----|
| 3s | 40 | 0 | 350 | 391 | 0.13× |
| 5s | 49 | 0 | 439 | 489 | 0.10× |
| 5s | 46 | 0 | 414 | 460 | 0.09× |

RTF (real-time factor) = decode_ms / audio_ms. Values < 1.0 mean faster than
real-time. The i5-10310U achieves ~0.1–0.13× RTF, which is excellent for a
low-voltage mobile CPU.

### Thread count benchmark

| Threads | 5s inference | Notes |
|---------|-------------|-------|
| 1 | 700ms | CPU-bound, serial |
| 2 | 490ms | good improvement |
| **4** | **430ms** | **optimal** (current default) |
| 8 | 480ms | slight regression (thread contention on 4C/8T) |

4 threads is the optimal setting for this CPU. More threads cause contention
on the 4 physical cores and actually slow down inference.

### What is NOT the bottleneck

- **Model load**: only happens once at daemon startup (~2s). Subsequent
  calls reuse the loaded recognizer — zero reload cost.
- **FFmpeg preprocessing**: negligible (~40ms). parecord already outputs
  16kHz mono s16le, so ffmpeg's main job is the 20dB gain, not resampling.
- **WAV loading**: <1ms for short clips (numpy `frombuffer` is instant).
- **Socket I/O**: <1ms (Unix socket, local file path only).

### What IS the bottleneck

- **sherpa-onnx decode**: 350–450ms — this is the pure ONNX runtime
  executing the SenseVoice model on CPU. This is the hard floor for this
  hardware. On Apple M1 Pro the same model does ~80–120ms.
- **Recording stop sleep**: 100ms `sleep 0.1` in `omarchy-voice-record` to
  ensure parecord flushes the WAV header. Could be reduced but risks
  truncated audio.
- **Paste delay**: 150ms `OMD_PASTE_DELAY` before sending the paste
  keystroke, to ensure `wl-copy` has propagated. Could be tuned down.

### Conclusion

On the i5-10310U, the model inference (~400ms) is at the hardware limit.
The remaining ~300–500ms of pipeline overhead (recording stop + paste delay)
could be trimmed by ~200ms if desired, but the total is already under 1s
for typical 3–5s utterances. Further speedup would require a different model
(smaller/quantized) or hardware acceleration (GPU/NPU), neither of which
is currently viable for SenseVoice on this platform.

### General performance characteristics

- **First startup:** ~30s (venv creation + pip install + model download)
- **Model load (daemon fork):** ~2s on Intel i5-10310U, ~2-3s on Apple M1 Pro
- **Warm transcription:** ~350–450ms decode for 3–5s audio on i5-10310U
  (total pipeline ~700–900ms including recording stop + paste)
- **Memory:** ~400MB RSS for loaded model daemon
- **Disk:** ~229MB model + ~150MB venv

---

## Known Limitations

1. **Language:** Default is `auto` (SenseVoice auto-detects zh/en/ja/ko/yue).
   Override with `OMD_VOICE_LANG` env var (e.g. `zh`, `en`, `ja`, `ko`, `yue`).
2. **wtype dependency:** Auto-paste uses `wtype` (Wayland virtual-keyboard) for
   reliable paste across keyboard layouts. `ydotool` is a fallback. If both
   fail, text is still copied to clipboard.
3. **Single model:** Only SenseVoice Small INT8 (229MB) is supported. Adding
   Whisper or other models would require changes to the transcribe script.
4. **No VAD:** Recording continues until user manually stops (no voice
   activity detection auto-stop). See Future Ideas.
5. **CPU-bound inference:** On low-power CPUs (e.g. i5-10310U), decode takes
   ~400ms for 5s audio. This is the hardware limit — no software optimization
   can significantly reduce it without model or hardware changes.

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
