# Sumika Shell Project Structure

This document describes the repository as it exists today. It is not the
future Core/Service/Plugin design; that target and its migration sequence are
defined in
[`architecture/sumika-core-plugin-migration-plan.md`](architecture/sumika-core-plugin-migration-plan.md).

## Repository Root

| Path | Current responsibility |
|---|---|
| `apps/` | Core Quickshell process roots: `omd-bar` (main shell), `omd-settings` (settings window), `omd-polkit` (auth agent) |
| `modules/` | Empty (README only) — all feature modules moved to `$SUMIKA_MODULES_HOME` |
| `quickshell/services/` | Shared QML services (29 singletons, module `qs.services`) — transitional, being consumed into Core |
| `quickshell/core/` | Core framework: ActionManager, ModuleLoader, ProcessSupervisor, ServiceManager |
| `quickshell/modules/` | Core shared QML import modules (3): `bar`, `common`, `polkit` |
| `bin/` | User-facing `omd-*` commands — thin shims delegating to `share/bin/omarchy-*` or Core infrastructure |
| `scripts/` | Development, reload, diagnostics, and integration helpers |
| `lib/` | Shared shell/runtime libraries, including the path contract |
| `hypr/` | Hyprland Lua configuration, bindings, rules, and autostart |
| `defaults/` | Versioned baseline configuration copied or merged by `Init.sh` |
| `config/` | Repository-managed integration snippets |
| `share/` | Themes, desktop entries, helper scripts (`share/bin/omarchy-*` implementations), and installed data |
| `icons/` | Project icon assets |
| `tests/` | Static and focused integration checks |
| `docs/` | Maintained architecture and feature documentation; see [`README.md`](README.md) |

## Current Running Processes

Core processes launched at startup via `bin/omd-restart`:

```text
apps/
├── omd-bar/         # Main Sumika Shell UI host (hardcoded bridge process)
├── omd-settings/    # Settings dialog (on-demand via bin/omd-settings)
└── omd-polkit/      # Polkit authentication agent (hardcoded)

External modules (SUMIKA_MODULES_HOME) provide registry-driven processes:
├── launcher/        # Application launcher (entry: launcher/shell.qml)
├── overview/        # Workspace overview (entry: overview/shell.qml)
└── ...              # Other modules with "application" kind
```

All feature modules live in `$SUMIKA_MODULES_HOME` (default `~/development/sumika-modules/`).
OMD/modules/ is empty — all module.json manifests are external.

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

Design tokens live in `quickshell/modules/common/TuiStyle.qml`.
Shared widgets live in `quickshell/modules/common/widgets/`.
The `shared/` directory (`qs.shared` module) was removed in the module-split
refactor — it was dead code with zero runtime consumers.

QML import resolution: `quickshell/scripts/quickshell` sets `QML_IMPORT_PATH`
to a transient symlink at `$XDG_RUNTIME_DIR/sumika-shell/qml/qs → <repo>/quickshell`,
so `import qs.core.*` and `import qs.services` resolve from the single QML root.
External modules are added via `$SUMIKA_MODULES_HOME/*/` added to `QML_IMPORT_PATH`.

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
| Shared visual token | `quickshell/modules/common/TuiStyle.qml` or per-module settings token file |
| Shared QML service | `quickshell/services/` (module `qs.services`) — Core-owned |
| Process entry point (Core) | `apps/omd-*/` |
| Process entry point (module) | `$SUMIKA_MODULES_HOME/<id>/shell.qml` via module.json `entry` |
| User command | `bin/omd-*` (thin shim delegating to share/bin/omarchy-* or module) |
| Hyprland behavior | `hypr/*.lua` |
| Baseline option | `defaults/config/quickshell/config.json` plus its QML schema/default |
| User-specific option | `~/.config/sumika-shell/sumika.json` |
| Generated machine state | `~/.local/state/sumika-shell/` |
Setting up a module in external repo | `$SUMIKA_MODULES_HOME/<id>/` with `module.json` — not in OMD |

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
The registry is generated by `quickshell/scripts/quickshell` from module manifests
in `$SUMIKA_MODULES_HOME/*/module.json`. OMD/modules/ provides no widget manifests.

Every widget component path is relative to its module directory in sumika-modules.

### Registered bar widgets by slot

| Widget ID | Component | Slot | Module (in sumika-modules) |
|---|---|---|---|
| workspaces | `Workspaces.qml` | left | workspaces |
| appLauncher | `AppLauncherButton.qml` | left | launcher |
| clock | `ClockWidget.qml` | right | clock |
| systray | `SysTray.qml` | right | systray |
| audio | `AudioButton.qml` | right | audio |
| display-bar-button | `bar/DisplayButton.qml` | right | display |
| wifi | `WifiButton.qml` | right | wifi |
| input-method-bar-button | `bar/InputMethodButton.qml` | right | input-method |
| session-bar-button | `bar/SessionButton.qml` | right | session |
| powerIndicator | `PowerIndicator.qml` | right | power-indicator |

Former widgets from `ommbar/` are no longer registered — the bar's module content was
dissolved; each widget is owned by its feature module in sumika-modules.

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

| Module | Actions | Location |
|--------|---------|----------|
| clock | `clock.notifications` | sumika-modules |
| launcher | `app-launcher.toggle/open/close` | sumika-modules |
| mpris | `mpris.play-pause/next/previous` | sumika-modules |
| notification-popup | `notifications.dismiss-last/dismiss-all/toggle-silent/edit-muted` | sumika-modules |
| on-screen-display | `osd.volume/brightness/input-method` | sumika-modules |
| overview | `overview.toggle/open` | sumika-modules |
| clipboard | `clipboard.toggle/open/close/paste` | sumika-modules |
| screenshot | `screenshot.capture/capture-ocr/capture-edit` | sumika-modules |
| voice | `voice.toggle` | sumika-modules |
| wifi | `wifi.launch` | sumika-modules |
| input-method | `input-method.cycle` | sumika-modules |

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

