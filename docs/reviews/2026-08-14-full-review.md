# Code Review — 2026-08-14

Full-project review: OMD repository (QML core, Hyprland/labwc configs, shell
scripts) + all 9 installed extensions. Findings are grouped by severity and
status: **FIXED** (committed), **KNOWN** (documented, not changed), **WONTFIX**
(intentional behavior).

Review method: five parallel read-only scouts (core QML, shell scripts,
compositor configs, extensions A/B) with every claim verified against source
before acting; fixes applied in batches with a shell restart + log check
after each batch.

## Scope

- Repo: `quickshell/` (17 module dirs, `services/`, `core/`, registry),
  `hypr/` + `hypr/default/` (Lua), `labwc/`, `bin/` + `share/bin/` (~45
  scripts), `apps/` (bar/polkit/settings), `defaults/`, `Init.sh`, `tests/`.
- Extensions (9): sasayaki, voice, input-method, keyboard-remap, screenshot,
  file-backup, windows-vm, theme-settings, active-window.
- Config: `~/.config/sumika-shell/` (chezmoi-managed).

## FIXED — Critical

| # | Where | Bug |
|---|---|---|
| C1 | `quickshell/GlobalStates.qml` | `sessionConfirmLabel` never declared — `requestSessionConfirm()` threw on assignment, so **every** logout/reboot/poweroff confirm dialog (bar IPC, power popup, app launcher, overview palette) was dead |
| C2 | `apps/sumika-bar/shell.qml` + `core/runtime/ActionManager.qml` | Duplicate `IpcHandler { target: "action" }` in one process — one registration rejected at startup; bar also re-ran `_registerBuiltins()` (~60 duplicate-ID warnings per boot) |

## FIXED — High

| # | Where | Bug |
|---|---|---|
| H1 | `voice/popup/VoicePopup.qml` | Instantiated the `VoiceInput` singleton (illegal in QML) — entire voice popup failed to create |
| H2 | `keyboard-remap/popup/KeyboardPopup.qml` | Same singleton bug + missing `qs.modules.keyboardremap` import + undefined `root.close()` |
| H3 | `keyboard-remap/settings/*` | Both settings pages missing the module import → ReferenceError on every `KeyboardRemap.` binding |
| H4 | `theme-settings/bin/sumika-launch-settings-wallpaper-tui` | exec'd nonexistent `sumika-settings-tui` — wallpaper TUI launcher dead |
| H5 | `windows-vm/popup/WindowsVmPopup.qml` | `root.close()` on nonexistent id — VM Settings button threw before launching |
| H6 | `file-backup/FileBackup.qml` | `openSettings()` exec'd the musubi TUI binary without a terminal (dies instantly); status via unquoted `sh -c` path; runtime data under config dir (now `sumikaStateHome`) |
| H7 | `screenshot/bar/ScreenshotButton.qml` | Recording-indicator poll Process never started (Timer had no `onTriggered`) — red dot could never show |
| H8 | `hypr/.../utilities.lua` + `labwc/rc.xml` + `bin/sumika-launch-profile` | SUPER+CTRL+A/B/W bound `{sumika="audio"...}` → `sumika-launch-profile audio` which exits 2 (no such profile). Registered `audio.launch` action; audio/bluetooth now dispatch real actions |
| H9 | `powerIndicator/SessionAutoRestore.qml` | `disarmMarker()` referenced non-existent `disarmProc` id — stale session-restore markers never cleared |
| H10 | `modules/audio/AudioPopup.qml` | Media controls gated on `ModuleLoader.isEnabled("mpris")` — always true (no such module id) → media strip permanently hidden |

## FIXED — Medium

| # | Where | Bug |
|---|---|---|
| M1 | `modules/notificationPopup/module-actions.qml` | Four actions delegated to never-registered `notification.*` ids — now call Notifications service directly |
| M2 | `modules/clock/module-actions.qml` | Missing `import qs` — `clock.notifications` threw on GlobalStates |
| M3 | `services/Brightness.qml` | BrightnessMonitor objects leaked on every screen hotplug; `ddcMonitors` never declared ("Invalid write to global property" on every parse); ddc-detect parse crashed on missing lines |
| M4 | `services/Notifications.qml` | Discard paths never stopped/destroyed NotifTimers — later fires hit dead objects (TypeError) and leaked |
| M5 | `core/runtime/ProcessSupervisor.qml` | One Process object leaked per restart cycle |
| M6 | `services/Audio.qml` | User aliases (free text) interpolated unescaped into wireplumber config |
| M7 | `modules/systray/SysTray.qml` | Read `bar.trayIconSpacing`; schema defines `tray.trayIconSpacing` — spacing option never worked |
| M8 | `modules/wifi/WifiPopup.qml` | Two self-referencing `rotation: cond ? rotation : 0` binding loops |
| M9 | `services/PolkitService.qml` + `polkit/PolkitContent.qml` | `!a ?? true` precedence — the "treat as password" default was dead |
| M10 | `file-backup/bin/sumika-launch-musubi-tui` | `uwsm-app` exec'd without existence check — launcher dead when absent |
| M11 | `screenshot/bar/ScreenshotButton.qml` | Infinite pulse animation ran while invisible (constant repaint ticks) |
| M12 | `keyboard-remap/icon.png` | 1.4 MB icon for a ≤64 px render — resized to 256 px (34 KB) |

## FIXED — Low / hygiene

- Dead `core/api/` removed (instantiated singletons via `createQmlObject` —
  can never work; zero consumers).
- `_registerFromRegistry` no longer warns for modules whose actionsProvider
  registers handlers itself.
- ActionManager same-owner re-registration replaces silently.

## KNOWN — High, needs a decision (not fixed)

| # | Where | Issue | Options |
|---|---|---|---|
| K1 | `file-backup/polkit/50-sumika-backup.rules` | Polkit rule returns YES for **any** pkexec command line containing the substring `mount.cifs` — any active local user gets passwordless root (`pkexec bash -c 'mount.cifs # <payload>'`) | (a) dedicated root helper + own .policy action (correct); (b) exact-match argv0 + group restriction (quick) |
| K2 | `keyboard-remap/share/polkit-1/rules.d/50-sumika-keyboard.rules` | Same class: substring match on `/etc/keyd/sumika.conf` etc. in any bash payload | same |
| K3 | `windows-vm/bin/sumika-settings-windows-vm` | RDP connect path requires `$SUMIKA_SHELL_ROOT/scripts/windows-rdp` which doesn't exist; compose file stores VM password world-readable (no chmod 600, unescaped YAML); `remove` rm -rf's env-derived dirs with no sanity guard | ship extension-local rdp launcher; validate+chmod; guard rm targets |
| K4 | `input-method/config/schemas.json` | Bundled fallback has `"schemas": []` — fresh installs get a popup whose buttons do nothing (works only where the user hand-created the config) | ship the 4-schema default; drive popup Repeater from config |
| K5 | `voice/bin/omarchy-voice-transcribe` | Daemon socket at fixed `/tmp/sumika-voice.sock`, chmod 0666, transcribes any client-supplied path — local arbitrary-file oracle on multi-user hosts | move to `$XDG_RUNTIME_DIR` 0600 |
| K6 | `sasayaki internal/service` | Data races: recorder fields written under `stateMu` read under `opMu`; `opTranslate`/`testSpeechOnly` read unlocked; `Shutdown` can stall 120s racing engine spawn; second `serve` steals a live socket | Go fixes — one lock owner; add stopCh case; dial-before-listen |
| K7 | `quickshell/core/runtime/ModuleLoader.qml` | `overlays` contributions collected but never instantiated — `notification-popup` overlay and `display/HyprsunsetOverlay.qml` (night light) never load via registry (night light only starts via clock's ≤60 s fallback) | instantiate Repeater in bar ShellRoot |
| K8 | `qs ipc ... call action list/query` | Returns empty output for list/object returns on this Quickshell build (bools work) — `sumika-action list/status` shows nothing | upstream Quickshell IPC serialization; workaround: string returns |

## KNOWN — Medium/low (documented, deferred)

- `windows-vm`: desktop entry Exec/icon assume core-repo paths; settings page
  `du -sb` over VM storage every 5–10 s; phase detection flips to error on any
  log line containing "error".
- `screenshot`: hardcoded `~/development/OMD` fallback for bar freeze IPC;
  pre-capture snapshots leak in `/tmp/quickshell/...`; `Directories.recordScriptPath`
  doesn't exist (dead branch); OCR auto-install uses bare `pip` (fails PEP 668);
  `/tmp/sumika-screenshot-active` fixed path; Search uploads to uguu.se (privacy).
- `voice`: `/tmp` wav/pid/cancel paths + cache-dir divergence vs QML
  (`Directories.genericCache`); curl without `--fail`/checksum (HTML error page
  becomes the model); `\r` progress never updates heartbeat → concurrent-setup
  race; dead 316-line `VoiceModelStatusPopup.qml`; hardcoded `~/.config` path in
  VoicePage; dev-machine fallback path in settings TUI.
- `keyboard-remap`: preset table duplicated QML/jq (drifted already: dead
  `meta-f13`); settings-keyboard resolves helpers via `SUMIKA_SHELL_ROOT` where
  they don't exist; TUI launcher/fallback broken like voice's was.
- `theme-settings`: TUI framework fallback `~/.config/sumika-shell/bin` wrong;
  ~7–8 MB preview PNGs unused by its own TUI; hardcoded state path written into
  config; **oceanblack theme ships no preview.png** (only current theme without
  one — website uses a synthesized swatch).
- `active-window`: labwc Force Quit appId→`pkill -x` misses (Chrome/Electron/
  flatpak comm names); unknown distro falls back to Fedora icon. (Hyprland
  Force-Quit address-scoping was fixed in user's pending work, committed.)
- `sasayaki`: `TestToggle` == `TestToggleSpeech` (test-mode pipeline dead);
  boundedBuffer short-write loses engine stderr; dead protocol errors; escape
  unbind spams hyprctl on every state flip.
- `file-backup`: 2.4 MB prebuilt `sumika-backup` ELF — unauditable; QML probes
  stdout by substring; polkit rules dir vs README drift; dead `bar/BackupButton.qml`
  + `WindowsVmButton.qml` (manifests declare `widgets: []`).
- Core: `ModuleLoader.registryPath` fallback `"/run/user/" + env("UID")` (UID
  rarely exported); `ApplicationManager` retry timer uncapped;
  `FirstRunExperience`/`ConflictKiller` reference nonexistent QML entry files and
  are never instantiated (docs promise the behavior); `SystemPage` autostart
  split on `|`; `OverviewWindow.monitorData?.reserved[0]` member guard;
  `KeyringStorage` "illogical-impulse" branding; audio settings gear hardcodes
  pavucontrol instead of `Config.apps.volumeMixer` (action now honors it);
  `defaults/config/quickshell/config.json` drift vs `Config.qml` schema (two
  default sources; baseline never installed by Init.sh).
- Compositor: `hypr/xdph.conf` `custom_picker_binary = hyprland-preview-share-picker`
  (binary doesn't exist); `sumika_tui_ids` drift (settingstui producer missing);
  dead `hypr/default/hypr/config.lua` module; SUPER+CTRL+B/W double-bound
  (utilities.lua + bindings.lua — Hyprland fires both); window_rules user
  override only for repo dir; monitors.lua shadowed variable + 0-mode output
  overlap.
- AGENTS.md drift: says 12 core modules / themes in `share/themes/` — actual:
  17 module dirs, themes live in the theme-settings extension.

## WONTFIX / verified-not-bugs

- labwc `rc.xml` "malformed XML" claim — xmllint passes; comment opener present.
- slurp layer namespace "selection" — matches upstream; hyprctl grep correct.
- WindowsVmPage Remove — guarded by SettingsDangerZone two-click confirm.
- Extension services inside extension dirs (no `quickshell/services/` pollution).
- App-ids across extensions are alnum-with-dots (no underscores) — compliant.
- QML uses `Quickshell.env` everywhere (no unsupported `Qt.environmentVariable`).

## Verification

- `bin/sumika-doctor` — OK (warnings only for not-yet-created log dir).
- `hyprctl reload` — ok.
- `bin/sumika-restart` × 3 during fix batches — bar active, zero ERROR /
  binding-loop / invalid-write / duplicate-action lines in `/tmp/sumika-bar.log`.
- New actions live: `audio.launch`, `clock.notifications`,
  `notifications.dismiss-all` all `isAvailable → true` via IPC.
- One regression during the batch (duplicate `Component.onCompleted` in
  Brightness.qml crashed the bar) — caught by foreground probe run, fixed, and
  the restart-loop unit recovered on next launch. This is exactly why
  `sumika-restart` (not systemctl) is the only sanctioned restart path.

## Website

`website/` — pure static (no build chain; `tools/build.py` regenerates store
pages from `registry.json`). Homepage, store with search/filter, 9 extension
detail pages, 22-theme gallery, downloadable tarballs under `downloads/`.
Ready to push to GitHub Pages as-is.
