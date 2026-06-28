# OMD Voice Input — Design & Implementation

## Overview

OMD Voice Input is a voice-to-text module for the Quickshell status bar, inspired by [kazamo](https://github.com/iamcheyan/kazamo). It records audio via PulseAudio, transcribes using SenseVoice (sherpa-onnx), and auto-pastes text at the cursor via `wl-copy` + `ydotool`.

**Key design goals:**
- Zero-install for the user: first use triggers automatic dependency + model download
- Fast after warmup: long-lived Python daemon keeps model loaded in memory
- Clear feedback at every step: button animation, desktop notifications, popup panel
- Unified TUI style: follows the same GNOME Shell-inspired design system as the rest of OMD

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
| Feedback | terminal stdout | button animations + desktop notifications + history panel |
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
│  - Desktop notifications via `notify-send`                   │
│  - History management (max 20 entries)                       │
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
                           ▼                │
            ┌────────────────────────┐      │
            │  notify "⬇️ 准备中…"     │      │
            │  → setupProc (venv)      │      │
            │  → downloadProc (model)  │      │
            │  → auto startRecording() │      │
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
              │   recording     │ ◄──── 红色脉冲外圈动画
              │  (parecord)     │       按钮红色半透明背景
              └────────┬────────┘
         toggle()      │
                       ▼
              ┌─────────────────┐
              │  transcribing   │ ◄──── 图标旋转动画
              │  (socket →     │       蓝色半透明背景
              │   daemon)       │
              └────────┬────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
  ┌────────────┐            ┌─────────────┐
  │   success  │            │    error    │
  │ 绿色闪烁   │            │ 红色背景    │
  │ 1.5s后→idle│            │ 点击→check  │
  └────────────┘            └─────────────┘
```

**State → Visual mapping:**

| State | Button | Background | Animation | Notification |
|-------|--------|------------|-----------|--------------|
| `setup` | 灰色离线图标 | 蓝色半透明 | 旋转 | "⬇️ 正在准备语音输入…" |
| `idle` | 正常麦克风 | 透明 | 无 | 无 |
| `recording` | 静音麦克风 | 红色半透明 | 外扩脉冲环 | "🎤 开始录音，再次点击停止" |
| `transcribing` | 传输图标 | 蓝色半透明 | 旋转 | "⏳ 正在转写…" |
| `success` | 勾选图标 | 绿色半透明 | 闪烁 | "✅ 已粘贴：[文本]" |
| `error` | 警告图标 | 红色半透明 | 无 | "❌ 语音输入失败：[原因]" |

---

## File Layout

```
share/bin/
├── omarchy-voice-setup          # venv creation + pip install sherpa-onnx numpy
├── omarchy-voice-download       # curl SenseVoice ONNX INT8 model (~500MB)
├── omarchy-voice-record         # parecord lifecycle + graceful WAV finalization
└── omarchy-voice-transcribe     # Python daemon with Unix socket

quickshell/services/
└── VoiceInput.qml               # Singleton service: state machine, IPC, history

quickshell/modules/bar/
├── VoiceContextMenu.qml         # Right-click popup menu
├── modules/VoiceButton.qml      # Bar button with animations
├── RightModuleRegistry.qml      # registers "util:voice"
└── BarStatusPopup.qml           # adds voiceContent settings panel

quickshell/modules/common/
└── Config.qml                   # default rightModules includes "util:voice"

quickshell/config.json           # user override also includes "util:voice"
omarchy/hypr/bindings.lua        # ALT + A hotkey
```

---

## Scripts

### `share/bin/omarchy-voice-setup`

```bash
#!/bin/bash
set -eu
MODEL_DIR="${OMD_VOICE_MODEL:-$HOME/.cache/omd-voice/sense-voice-small-int8}"
VENV_DIR="$HOME/.cache/omd-voice/venv"

# 1. Create venv
python3 -m venv "$VENV_DIR"

# 2. Install deps
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install sherpa-onnx numpy

echo "venv-ready"
```

### `share/bin/omarchy-voice-download`

Downloads from HuggingFace:
- `model.int8.onnx` (~500MB)
- `tokens.txt` (~1KB)

### `share/bin/omarchy-voice-record`

Controls the temporary WAV recording used by `VoiceInput.qml`.

- `start` stops stale recorders for `/tmp/omd-voice-rec.wav`, removes the old
  WAV, starts `parecord`, and writes `/tmp/omd-voice-rec.pid`.
- `stop` sends SIGINT to `parecord`, waits up to roughly two seconds for a
  graceful exit, then leaves a finalized WAV for transcription.

The SIGINT-and-wait behavior intentionally follows kazamo. `parecord` must exit
cleanly so it can flush the WAV header; killing it too early can leave a file
that looks like WAV to `file(1)` but fails in Python with
`fmt chunk and/or data chunk missing`.

### `share/bin/omarchy-voice-transcribe`

Python script with two modes:

**Client mode** (default, with `wav_path` argument):
```python
if not is_daemon_running():
    start_daemon()  # fork + wait for socket
result = client_transcribe(wav_path)
print(json.dumps(result))
```

**Daemon mode** (forked child):
```python
# 1. Load sherpa_onnx.OfflineRecognizer.from_sense_voice()
# 2. Bind Unix socket /tmp/omd-voice.sock
# 3. while True:
#      conn = server.accept()
#      wav_path = conn.recv(...).decode()
#      text = transcribe_file(recognizer, wav_path)
#      conn.send(json.dumps({"text": text}))
```

The daemon stays warm in memory (~450MB RSS on Asahi M1 Pro) so subsequent calls are sub-second.

---

## QML Modules

### `VoiceInput.qml` (Singleton Service)

**Key properties:**
- `state`: string — current state (init/setup/idle/recording/transcribing/success/error)
- `recordingDuration`: real — seconds since recording started (updates every 100ms)
- `history`: list<var> — `{ text: "...", time: "HH:MM" }` entries, max 20
- `modelSizeMB`: int — du -sm of model dir
- `daemonRunning`: bool — socket LISTEN check
- `lastTranscription`: string — most recent result
- `lastError`: string — most recent error

**Key methods:**
- `toggle()` — main entry point (handles all states)
- `setup()` — trigger venv + model download
- `startRecording()` / `stopRecording()` — parecord control
- `testRecording()` — 3-second auto-stop test
- `checkState()` — refresh model/venv status
- `refreshModelInfo()` / `refreshDaemonStatus()` — update display props
- `openSettings()` — open BarStatusPopup voice panel
- `clearHistory()` — empty history list

**Desktop notifications:**
Every state transition triggers `notify-send` with appropriate icon and timeout (3s). First-time setup shows progress messages.

### `VoiceButton.qml` (Bar Module)

**Layout:** `Item > RippleButton + MouseArea(right-click) + Loader(context menu) + Rectangle(pulse) + CosmicIcon + Rectangle(success flash)`

**Left click:** `VoiceInput.toggle()` — starts/stops recording
**Right click:** opens `VoiceContextMenu.qml`

**Dynamic styling:**
- Background color changes per state (transparent → blue → red → green)
- Pulse ring animates during `recording` (scale 1→1.6, opacity 0.7→0)
- Icon rotates during `transcribing` / `setup`
- Success green flash fades over 200ms

### `VoiceContextMenu.qml` (Right-click Menu)

`PopupWindow` with 4 actions:
1. **语音设置** — opens `VoiceInput.openSettings()` (BarStatusPopup voice panel)
2. **安装并测试 / 测试录音(3秒)** — `VoiceInput.setup()` or `VoiceInput.testRecording()`
3. **清除历史 (N)** — `VoiceInput.clearHistory()`
4. **重新检查状态** — `checkState()` + `refreshModelInfo()` + `refreshDaemonStatus()`

Uses `StyledRectangularShadow` + `RippleButton` with CosmicIcon, following the same pattern as `BluetoothContextMenu.qml`.

### `BarStatusPopup` voiceContent

Added to the existing popup switch statement alongside wifi/bluetooth/audio/etc.

**Sections:**
1. **Header** — "VOICE INPUT" + current state label
2. **MODEL STATUS panel** — MODEL size, VENV ready, DAEMON running
3. **HISTORY panel** — scrollable list of recent transcriptions, click to copy
4. **ActionRow** — Test/Install, Check, Clear buttons

All styled with `TuiStyle` (bg, panel, line, accent, etc.) matching Control Center.

---

## History System

Every successful transcription is appended to `VoiceInput.history` as:
```javascript
{ text: "识别出的文本", time: "14:32" }
```

- Max 20 entries (oldest discarded)
- Displayed in settings panel with timestamp
- Click any entry to copy to clipboard
- Clear via right-click menu or settings panel

---

## IPC Interface

```qml
IpcHandler {
    target: "voice"
    function toggle(): void { root.toggle() }
}
```

Called from:
- `bindings.lua`: `ALT + A` → `qs -p ... ipc call voice toggle`
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
