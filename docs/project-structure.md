# Sumika Shell Project Structure

This document describes the repository as it exists today. It is not the
future Core/Service/Plugin design; that target and its migration sequence are
defined in
[`architecture/sumika-core-plugin-migration-plan.md`](architecture/sumika-core-plugin-migration-plan.md).

## Repository Root

| Path | Current responsibility |
| --- | --- |
| `apps/` | Independently launched Quickshell process roots (`omd-bar`, `omd-overview`, settings, clipboard, notification, screenshot, and polkit) |
| `quickshell/` | Shared QML modules, services, assets, scripts, translations, and the transitional built-in registry |
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

Each directory under `apps/` is a Quickshell process boundary. Small entry
files import shared implementation from `quickshell/`:

```text
apps/
├── omd-bar/
├── omd-overview/
├── omd-applauncher/
├── omd-clipboard/
├── omd-notification/
├── omd-screenshot/
├── omd-settings/
└── omd-polkit/
```

This is a transitional multi-application layout. The existence of an
`apps/omd-*` directory does not mean that feature has already become a plugin.
Do not describe the current tree as the completed Sumika plugin architecture.

## Shared Quickshell Tree

```text
quickshell/
├── modules/
│   ├── bar/
│   ├── overview/
│   ├── settings/
│   ├── notificationPopup/
│   ├── onScreenDisplay/
│   ├── polkit/
│   ├── regionSelector/
│   ├── schedulePopup/
│   └── common/
├── services/
├── registry/
│   └── builtin/bar.json
├── assets/
├── scripts/
└── translations/
```

`quickshell/modules/common/` is shared implementation, not a public plugin API.
New cross-feature contracts should be placed deliberately under its
`widgets/`, `models/`, `panels/`, `functions/`, or `utils/` subdirectory until
the migration introduces stable `core/api` ownership.

The bar currently reads contributions through the transitional module
registry. Registry participation alone does not provide process isolation or
a stable third-party ABI.

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
| Shared visual token | `quickshell/modules/common/TuiStyle.qml` or the relevant shared settings token file |
| Shared QML service | `quickshell/services/` |
| Process entry point | `apps/omd-*/` |
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
