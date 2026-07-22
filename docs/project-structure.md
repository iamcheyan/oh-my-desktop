# Sumika Shell Project Structure

This document describes the repository as it exists today. It is not the
future Core/Service/Plugin design; that target and its migration sequence are
defined in
[`architecture/sumika-core-plugin-migration-plan.md`](architecture/sumika-core-plugin-migration-plan.md).

## Repository Root

| Path | Current responsibility |
| --- | --- |
| `apps/` | Remaining standalone Quickshell process roots (`omd-bar`, `omd-settings`, `omd-polkit`) |
| `modules/` | Migrated module process roots (clipboard, screenshot, launcher, notification, overview) |
| `core/` | Core framework: runtime (ActionManager, ProcessSupervisor, etc.), api, ui hosts, layout, diagnostics |
| `services/` | Shared QML services (31 Singletons, same module `qs.services` as original) |
| `shared/` | Shared UI components, TuiStyle, icons, utils — module `qs.shared` / `qs.shared.ui` |
| `quickshell/` | Original QML root (kept for compatibility; new root-level dirs added via QML_IMPORT_PATH) |
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

## Current Quickshell Processes

Migrated process roots (apps → modules):

```text
apps/
├── omd-bar/         # Main Sumika Shell UI host
├── omd-settings/    # Settings dialog
└── omd-polkit/      # Polkit authentication agent

modules/
├── clipboard/       # Clipboard history (ex apps/omd-clipboard)
├── screenshot/      # Screenshot tool (ex apps/omd-screenshot)
├── launcher/        # Application launcher (ex apps/omd-applauncher)
├── notification/    # Notification popup (ex apps/omd-notification)
└── overview/        # Workspace overview (ex apps/omd-overview)
```

## Core Framework

```text
core/
├── runtime/         # ActionManager, ProcessSupervisor, ServiceManager, ModuleLoader
├── api/             # ActionApi, ServiceApi, schema definitions
├── ui/              # TopBar host, Overview host (qs.core.ui)
├── layout/          # Shell layout module (qs.core.layout)
└── diagnostics/     # DiagnosticReporter (qs.core.diagnostics)
```

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
The registry is generated by `quickshell/scripts/quickshell` from builtin manifests
(`quickshell/registry/builtin/`) and external module manifests (`$SUMIKA_MODULES_HOME`).

### Registered bar widgets by slot

| Widget ID | Component | Slot | Module | Role |
|---|---|---|---|---|
| workspaces | `modules/bar/Workspaces.qml` | left | core-bar | Desktop workspace indicators |
| appLauncher | `modules/bar/AppLauncherButton.qml` | left | core-bar | Application launcher trigger |
| activeWindow | `modules/bar/ActiveWindow.qml` | left | core-bar | Focused window title |
| systray | `modules/bar/SysTray.qml` | right | core-bar | XEmbed/DBus tray icons |
| clipboard | `modules/bar/modules/ClipboardButton.qml` | right | core-bar | Clipboard history trigger |
| tools | `modules/bar/modules/ToolsButton.qml` | right | core-bar | Quick tools menu |
| clock | `modules/bar/ClockWidget.qml` | right | core-bar | Date/time display |
| sidebarIndicators | `modules/bar/SidebarIndicators.qml` | right | core-bar | Sidebar toggle indicator |

Additional widgets registered via per-feature builtin manifests:

| Widget ID | Component | Slot | Module |
|---|---|---|---|
| audio | `modules/bar/modules/AudioButton.qml` | right | audio |
| wifi | `modules/bar/modules/WifiButton.qml` | right | wifi |
| display | `modules/bar/modules/DisplayButton.qml` | right | display |
| inputMethod | `modules/bar/modules/InputMethodButton.qml` | right | input-method |
| session | `modules/bar/modules/SessionButton.qml` | right | session |

### Actions registered by ActionManager

All system actions (session management, clipboard, settings, etc.) route through
`ActionManager.invoke()`. Builtin actions registered in `_registerBuiltins()`:

- `shell.reload`, `session.lock`, `session.logout`, `session.reboot`, `session.shutdown`
- `settings.open`, `overview.open`
- `clipboard.toggle`, `clipboard.open`, `clipboard.close`, `clipboard.paste`

Module-contributed actions are registered via `_registerFromRegistry()` which reads
module manifests from the runtime registry.

### IPC channels

| Target | Handler location | Owner |
|---|---|---|
| bar | `quickshell/modules/bar/Bar.qml` | core |
| action | `apps/omd-bar/shell.qml` | core (bridge to ActionManager) |
| clipboard | `modules/clipboard/shell.qml` | clipboard module |
| screenshot | `modules/screenshot/shell.qml` | screenshot module |
| appLauncher | `modules/launcher/shell.qml` | launcher module |
| notification | `modules/notification/shell.qml` | notification module |
| overview | `modules/overview/shell.qml` | overview module |
