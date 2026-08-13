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

## KNOWN High — closed in the 2026-08-14 finish pass

All K items below were triaged in the finish pass. K3–K8 are **FIXED
(2026-08-14)**; K1/K2 carry the quick reversible hardening with the complete
root-helper redesign parked as **DEC-001 (WAITING)** in `DECISIONS_PENDING.md`.
Extension fixes ship as repacked tarballs under `website/downloads/` (version
bumped, patch level). Details:

| # | Where | Status |
|---|---|---|
| K1 | `file-backup` polkit rule | **FIXED (2026-08-14)** — rule now pins exact argv0 (`mount.cifs`/`umount` only, no bash wrappers), requires active session + `wheel`/`sumika` group. 16-case polkit-engine simulation passes (malicious `pkexec bash -c 'mount.cifs # payload'` rejected; legit mounts allowed). Full root-helper + own `.policy` = **DEC-001 (WAITING)**. Shipped in `sumika-ext-file-backup.tar.gz` v2.0.1. |
| K2 | `keyboard-remap` polkit rule + `omarchy-keyboard-apply` | **FIXED (2026-08-14)** — apply payload pinned to a single exact shape the rule validates byte-for-byte (path may not contain quotes/whitespace/`;`/`$`); program must be bash; active + group required. Non-systemd fallback dropped from the pkexec payload (falls back to run0/sudo with password). Same simulation suite. Shipped in `sumika-ext-keyboard-remap.tar.gz` v1.0.1. Root-helper redesign: **DEC-001**. |
| K3 | `windows-vm` script | **FIXED (2026-08-14)** — compose file now written `0600` with YAML-escaped credentials (verified: round-trips `pa$s "quote"\slash` exactly through a YAML parser); `remove` rm -rf guarded by `safe_rm_rf` (exact defaults whitelisted; env overrides must be ≥2 levels under `$HOME` and outside Documents/.config/.local/…; 12-case matrix passes); missing `scripts/windows-rdp` shipped (reads port + creds from compose, execs xfreerdp3/xfreerdp). Shipped v2.0.1. |
| K4 | `input-method` schemas | **FIXED (2026-08-14)** — bundled `config/schemas.json` now carries the 4 default schemas (sbzr, sbzr_mix, easy_en, jaroomaji); popup Repeater driven by `im.schemas` from the config (hardcoded list kept only as display fallback). Fresh installs get working buttons; `sumika-input-method set <id>` no longer rejects every schema. Shipped v2.0.1. |
| K5 | `voice` daemon socket | **FIXED (2026-08-14)** — socket moved to `$XDG_RUNTIME_DIR/sumika-voice.sock` (bind under 0177 umask + explicit chmod 0600); pid file, recording wav/pid, cancel flag and all status probes moved off `/tmp`; stale legacy `/tmp` socket is unlinked with a warning. Daemon unit test (stubbed sherpa-onnx) verifies: socket in runtime dir, mode 0600, legacy cleanup, client round-trip. Shipped v1.0.1. |
| K6 | `sasayaki` data races | **FIXED (2026-08-14)** — `opTranslate`/`testSpeechOnly` now snapshotted under `opMu` (were read unlocked in the pipeline goroutine); `recordingPath`/`recordingGeneration` reads in `finishRecording`/`Cancel` moved under `stateMu`; `Shutdown` now cancels a daemon `shutdownCtx` first so in-flight engine calls return promptly (pipeline ctx derives from it) and the worker is shut down outside `opMu`; `Run` dials the socket before unlinking so a second start can no longer steal a live daemon's socket. Also fixed a crash the new regression test exposed: `finishRecording` now flips the phase to `Transcribing` synchronously, so `Cancel` can never deref a nil recorder in the old `Recording` window (original tree panics on `TestConcurrentOperationsNoRace`; fixed tree passes `go test -race ./...`). Shipped v1.0.1. Note: public `github.com/iamcheyan/sasayaki` is an unrelated scaffold (README+go.mod only) — the shipped extension source is canonical; upstream sync is a separate task. |
| K7 | `ModuleLoader.overlays` never instantiated | **FIXED (2026-08-14)** — registry generator (`quickshell/scripts/quickshell`) now stamps absolute `file://` component paths + `moduleId` for `overlays` (and `overviewProviders`, same gap); bar `ShellRoot` instantiates registry overlays once (createObject, id-deduped, guarded by `registryLoaded`) and the previously hardcoded duplicates were removed (`OnScreenDisplay {}` + inline notification PanelWindow; `notificationPopup/NotificationPopup.qml` now uses `BarPopupGeometry` margins to keep visuals). Registry generation verified: 3 overlays (hyprsunset, notification-popup, on-screen-display), all component paths exist. No extension declares overlays, so no double-instance risk from the extension side. GUI verification pending (no compositor on the fix machine) — check `/tmp/sumika-bar.log` for `[Bar] overlay loaded:` lines after `sumika-restart`. |
| K8 | `qs ipc call action list/query` empty | **FIXED (2026-08-14, workaround)** — `action.list`/`action.query` now return JSON **strings** (bools were the only serializable return type on this build); `sumika-action` normalizes possibly-quoted CLI output (bare vs quoted both parse; jq handles either). Upstream Quickshell IPC serialization gap remains — if a future quickshell serializes `var` returns, the string form still works. |

## KNOWN — Medium/low (documented, deferred)

Partial progress 2026-08-14: screenshot's fixed `/tmp/sumika-screenshot-active`
flag + temp edit path moved to `$XDG_RUNTIME_DIR` (v2.0.1); voice's `/tmp`
wav/pid/cancel paths fixed with K5 (v1.0.1). The `mktemp`-based screenshot
intermediates stay in `/tmp` deliberately (mktemp is 0600-random; safe).
Everything else below remains deferred as originally documented.

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

## FIXED — Script layer (second batch)

| # | Where | Bug |
|---|---|---|
| S1 | `share/bin/sumika-hyprland-*` | The `sumika-hyprland-toggle{,-enabled,-disabled}` + `sumika-notification-send` helper family **did not exist anywhere** — monitor-internal, monitor-internal-mirror, window-gaps-toggle, single-square-aspect-toggle silently exited 127 on every call, wired to live bindings and lid actions. Implemented over the marker-file contract `toggles/hypr/<name>.lua` the Lua config loads |
| S2 | `bin/sumika-session` | Every native `hyprctl dispatch` (resizewindowpixel, movewindowpixel, focuswindow, fullscreen, killactive, closewindow, movetoworkspacesilent, togglespecialworkspace) is a **Lua syntax error on Hyprland 0.55+ that still exits 0** — floating size/position, fullscreen, and special-workspace restore were all dead. Converted to verified `hl.dsp.*` forms |
| S3 | `bin/sumika-module-validate` | Undefined `SERVICE_ID_PATTERN` — validator crashed on `contributes.services` and the module was silently dropped from the registry; also rejected the schema-legal `center` slot and `process:` handlers |
| S4 | `share/bin/sumika-launch-webapp` | Non-chromium default browsers coerced to `chromium.desktop` → empty Exec → webapp launch broken for Firefox-default users |
| S5 | `bin/sumika-kb-layout` | Read/wrote the repo `hypr/input.lua` that the user override masks — `get` reported `us` while `jp` was active; `set` was a no-op for override users |
| S6 | `share/bin/sumika-system-lock` | Failed open: exit 0 with no lock — hypridle would suspend an unlocked session. Now falls back to `loginctl lock-session`, exits nonzero without a lock |
| S7 | `bin/sumika-restart` | Hardcoded `/usr/bin/quickshell` in pkill + lock-guard patterns — user-local installs left stacked bars and the WlSessionLock guard failed open |

## KNOWN — Script layer (deferred)

- `sumika-session`: unguarded `notify-send` (missing binary aborts save after
  snapshot write but before arming restore); non-atomic `last.json`; TOCTOU
  restore lock.
- `sumika-keep-awake`: PID-reuse liveness on a persistent pid file (can kill
  an innocent process after reboot).
- `sumika-sni-reconcile`: misses unique-name SNI registrations (verified 0
  matches with 1 item registered).
- `sumika-doctor`: PAM check misses `/usr/lib64` (Fedora); predictable `/tmp`
  output file; dead `check_link()`.
- `sumika-sync-launchers`: zombie sweep would delete user-authored
  `sumika-*.desktop` (no ownership marker).
- `sumika-launch-or-focus`: unquoted `eval exec setsid $LAUNCH_COMMAND`;
  regex-injection into jq `test()`; dead native fallback.
- `sumika-launch-tui`: `foot -e` fallback broken (foot has no `-e`).
- `sumika_tui_framework.py`: curses color-pair collisions (swatch pair 9 =
  C_PANEL; image pool stomps reserved pairs 31/32).
- `lib/paths.sh`: `BASH_SOURCE` breaks real-POSIX `/bin/sh` (dash);
  `lib/config.sh` is entirely dead code.
- `Init.sh`: predictable `/tmp` download; labwc build failure aborts silently
  under `set -eu`; migration collision makes reruns non-idempotent; `read -p`
  auto-proceeds on EOF.
- `quickshell/scripts/quickshell`: duplicate-instance guard false-positives on
  `qs ipc call` probes; registry-empty diagnostic can never fire;
  `QS_COMPOSITOR=hyprland` hardcoded.
- Verified clean: bin→share wrapper uniformity, session-save systemd ordering,
  system-sleep Bluetooth hook, migrate.sh atomicity, no curl|sh, no hardcoded
  credentials.

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
