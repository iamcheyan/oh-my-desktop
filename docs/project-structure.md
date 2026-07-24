# Sumika Shell Project Structure

This document describes the repository as it exists today. It is not the
future Core/Service/Plugin design; that target and its migration sequence are
defined in
[`architecture/sumika-core-plugin-migration-plan.md`](architecture/sumika-core-plugin-migration-plan.md).

## Repository Root

| Path | Current responsibility |
| --- | --- |
| `apps/` | Remaining standalone Quickshell process roots (`omd-bar`, `omd-settings`, `omd-polkit`) |
|| `modules/` | 18 modules (active-window, audio, clock, display, input-method, launcher, mpris, notification, notification-popup, on-screen-display, overview, power-indicator, session, settings, systray, wifi, workspaces) + `battery-power` (shared) with module.json manifests; application modules are registry-driven processes |
| `services/` | Shared QML services (31 Singletons, same module `qs.services` as original) |
| `shared/` | Shared UI components, TuiStyle, icons, utils — module `qs.shared` / `qs.shared.ui` |
| `quickshell/` | Single-source QML root — all `qs.core.*`, `qs.services.*`, `qs.shared.*` imports resolve via QML_IMPORT_PATH symlink |
| `bin/` | User-facing `omd-*` commands and Python TUI programs |
| `scripts/` | Development, reload, diagnostics, and integration helpers |
| `lib/` | Shared shell/runtime libraries, including the path contract |
| `hypr/` | Hyprland Lua configuration, bindings, rules, and autostart |
| `defaults/` | Versioned baseline configuration copied or merged by `Init.sh` |
| `config/` | Repository-managed integration snippets |
| `share/` | Themes, desktop entries, helper scripts, and installed data |
| `icons/` | Project icon assets |
| `tests/` | Static and focused integration checks |
| `docs/` | Maintained architecture and feature documentation; see [`README.md`](README.md) |

## Current Running Processes

Processes launched at startup, driven by registry module.json `entry` blocks:

```text
apps/
├── omd-bar/         # Main Sumika Shell UI host (hardcoded bridge process)
├── omd-settings/    # Settings dialog (hardcoded or module entry)
└── omd-polkit/      # Polkit authentication agent (hardcoded)

modules/              # Registry-driven application modules
├── launcher/        # Application launcher (entry: launcher/shell.qml)
├── notification/    # Notification popup (entry: notification/shell.qml)
└── overview/        # Workspace overview (entry: overview/shell.qml)
```

Former `apps/omd-clipboard` and `apps/omd-screenshot` were moved to modules/
and now run as `bin/omd-clipboard-store` (compat shim, not a Quickshell process)
and `bin/omd-screenshot` (standalone Python script).
## Core Framework

The Core runtime lives under `quickshell/core/` (single source, not root-level):

```text
quickshell/core/
├── runtime/         # ActionManager, ProcessSupervisor, ServiceManager, ModuleLoader
├── api/             # ActionApi, ServiceApi, schema definitions (registry-schema.json)
├── ui/              # TopBar host, Overview host (qs.core.ui)
├── layout/          # Shell layout module (qs.core.layout)
└── diagnostics/     # DiagnosticReporter (qs.core.diagnostics)
```

Root-level `core/` was dead drift (no qmldir, no consumers) and was removed
in Phase B of the migration. All consumers import from `qs.core.*`.
## Shared UI Components

```text
shared/
├── ui/              # 46 widget QML files (qs.shared.ui)
├── utils/           # Shared utilities
├── icons/           # Icon assets
├── TuiStyle.qml     # Design tokens
├── Appearance.qml
├── Config.qml
├── Directories.qml
├── Persistent.qml
└── qmldir           # module qs.shared
```

QML import resolution: repo root is in `QML_IMPORT_PATH` (set by `quickshell/scripts/quickshell`),
so `import qs.services`, `import qs.core.runtime`, `import qs.shared` all resolve from new root-level directories.
Original `quickshell/` paths remain as fallback for backward compatibility.

## Data Ownership

| Data | Path | Ownership |
| --- | --- | --- |
| Source, QML, themes, assets | repository root | Git |
| User overrides | `~/.config/sumika-shell/` | User / chezmoi |
| Generated runtime state | `~/.local/state/sumika-shell/` | Runtime, not Git |
| Runtime code compatibility link | `~/.config/omd -> <repo>` | `Init.sh` |
| Quickshell source link | `~/.config/quickshell -> <repo>/quickshell` | `Init.sh` |

The default configuration is
`defaults/config/quickshell/config.json`. The user override is
`~/.config/sumika-shell/sumika.json`. Code must not recreate the removed
`~/.config/sumika-shell/quickshell/config.json` split.

## Path Contract

Shell code sources `lib/paths.sh` and uses:

- `SUMIKA_SHELL_ROOT`
- `SUMIKA_SHELL_CONFIG_HOME`
- `SUMIKA_SHELL_STATE_HOME`
- `SUMIKA_SHELL_DATA_HOME`
- `SUMIKA_SHELL_RUNTIME_DIR`

`OMD_ROOT` remains a compatibility alias for the repository root. QML uses
`Directories.sumikaStateHome` for generated state. Lua uses
`default.hypr.paths`. Do not add new literal `~/.config/omd` or
`~/.local/state/omd` data paths.

## Where Changes Belong

| Change | Preferred location |
| --- | --- |
| Shared visual token | `shared/TuiStyle.qml` or the relevant shared settings token file |
| Shared QML service | `services/` (root-level) — also available at `quickshell/services/` for compat |
| Process entry point | `apps/omd-*/` or `modules/*/` depending on migration status |
| User command | `bin/omd-*` |
| Hyprland behavior | `hypr/*.lua` |
| Baseline option | `defaults/config/quickshell/config.json` plus its QML schema/default |
| User-specific option | `~/.config/sumika-shell/sumika.json` |
| Generated machine state | `~/.local/state/sumika-shell/` |
| Future module boundary/API | follow the Core/Plugin migration plan before moving files |

## Verification

Run focused syntax checks for edited files, then:

```sh
hyprctl reload
bash scripts/reload-quickshell
~/.config/omd/bin/omd-doctor
```

Do not infer architecture completion from a successful reload. Module
isolation, ownership direction, and removal of feature code from Core must be
verified against the migration gates in the architecture plan.

## Bar Widget Registry

All bar widgets are loaded via `ModuleLoader` Repeaters from the unified registry.
The registry is generated by `scripts/quickshell` from module manifests in
`modules/*/module.json` and `$SUMIKA_MODULES_HOME/**/module.json`.

Every widget component path is relative to its module directory.

### Registered bar widgets by slot

| Widget ID | Component | Slot | Module |
|---|---|---|---|
| workspaces | `Workspaces.qml` | left | workspaces |
| appLauncher | `AppLauncherButton.qml` | left | app-launcher |
| clock | `ClockWidget.qml` | right | clock |
| systray | `SysTray.qml` | right | systray |
| audio | `AudioButton.qml` | right | audio |
| display-bar-button | `bar/DisplayButton.qml` | right | display |
| wifi | `WifiButton.qml` | right | wifi |
| input-method-bar-button | `bar/InputMethodButton.qml` | right | input-method |
| session-bar-button | `bar/SessionButton.qml` | right | session |
| powerIndicator | `PowerIndicator.qml` | right | power-indicator |

Former widgets from `modules/bar/` (`activeWindow`, `clipboard`, `tools`, `sidebarIndicators`)
are no longer registered — the bar module was dissolved; each widget is owned by its
feature module.

### Actions

System behavior routes through `ActionManager.invoke()`. Builtin actions registered
in `_registerBuiltins()` in `quickshell/core/runtime/ActionManager.qml`:

- **Session lifecycle**: `session.lock`, `session.logout`, `session.reboot`,
  `session.shutdown`, `session.suspend`, `session.hibernate`,
  `session.logout.save`, `session.reboot.save`, `session.shutdown.save`
- **Shell**: `shell.reload`
- **Settings**: `settings.open`
- **Overview**: `overview.open`
- **Process supervising**: `process_supervisor.cancel`, `process_supervisor.status`
- **Bluetooth**: `bluetooth.launch` (conditional — only if no bluetooth module present)
- **Audio**: `audio.volume-up/down/mute-toggle/input-mute-toggle/up-precise/down-precise/output-switch`
- **Display**: `display.brightness-up/down/max/min/up-precise/down-precise`,
  `display.kbd-brightness-up/down/cycle`,
  `display.internal-toggle/mirror-toggle/lid-close/lid-open/color-picker`,
  `display.scaling-cycle/scaling-cycle-reverse`
- **Input**: `input.touchpad-toggle/enable/disable`
- **Window**: `window.transparency-toggle/gaps-toggle/single-square-aspect-toggle/close-all/pop-out`
- **Workspace**: `workspace.layout-toggle`

Module-contributed actions are registered via `_registerFromRegistry()` which
reads module manifests from the registry. Contributing modules:

| Module | Actions |
|--------|--------|
| clock | `clock.notifications` |
| launcher | `app-launcher.toggle/open/close` |
| mpris | `mpris.play-pause/next/previous` |
| notification-popup | `notifications.dismiss-last/dismiss-all/toggle-silent/edit-muted` |
| on-screen-display | `osd.volume/brightness/input-method` |
| overview | `overview.toggle/open` |
| clipboard (external) | `clipboard.toggle/open/close/paste` |
| screenshot (external) | `screenshot.capture/capture-ocr/capture-edit` |
| voice (external) | `voice.toggle` |
| wifi (external) | `wifi.launch` |
| input-method (external) | `input-method.cycle` |
|
### IPC channels

The main bar process (`apps/omd-bar`) provides three IPC targets:

| Target | Handler location | Purpose |
|---|---|---|
| `action` | `apps/omd-bar/shell.qml` | Route action IDs to ActionManager (invoke, query, list, status) |
| `session` | `apps/omd-bar/shell.qml` | Session confirmation prompts (logout, reboot, shutdown) |
| `menus` | `apps/omd-bar/shell.qml` | Close open menus (Hyprland ESCAPE binding) |

Application modules expose their own IPC targets for communication with their
own process:

| Target | Module | Entry command |
|---|---|---|
| `appLauncher` | launcher | `omd-applauncher toggle` |
| `overview.toggle` | overview | IPC to overview process's `overview.toggle` |
| `osdVolume` / `osdBrightness` | on-screen-display | Shared component in bar process |

