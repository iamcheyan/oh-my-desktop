# Core Allowlist — What Belongs in OMD

After the module-split refactor, only the following paths are allowed to contain
business logic in the OMD repository. Everything else must delegate to
`$SUMIKA_MODULES_HOME` external modules.

## Core Application Entry Points

| Path | Purpose |
|---|---|
| `apps/omd-bar/` | Main Sumika Shell UI host process (hardcoded bridge) |
| `apps/omd-settings/` | Settings dialog window host (on-demand, loads SettingsDialog from sumika-modules/settings/) |
| `apps/omd-polkit/` | PolicyKit authentication agent |

## Core Runtime Framework

| Path | Purpose |
|------|---------|
| `quickshell/core/runtime/` | ActionManager, ModuleLoader, ProcessSupervisor, ServiceManager |
| `quickshell/core/api/` | ActionApi, ServiceApi, schema definitions |
| `quickshell/core/ui/` | TopBar host, Overview host (`qs.core.ui`) |
| `quickshell/core/diagnostics/` | DiagnosticReporter (`qs.core.diagnostics`) |
| `quickshell/core/GlobalStates.qml` | Session-wide global state |

## Core Shared QML Import Modules

| Path | Types Provided |
|------|---------------|
| `quickshell/modules/bar/` | Bar UI components and TopBar host |
| `quickshell/modules/common/` | Widgets, TuiStyle, Config, PanelWindow, functions |
| `quickshell/modules/polkit/` | PolicyKit UI components |

## Services (Transitional — Being Consumed Into Core)

| Path | Purpose |
|------|---------|
| `quickshell/services/*.qml` | Singleton services (Audio, Network, Battery, Brightness, etc.) |
| `quickshell/services/qmldir` | Module declaration for `qs.services` |

These services are in a transitional state. They may be consumed into Core
(`quickshell/core/`) over time, but should NOT be moved to external modules.

## Shell Infrastructure

| Path | Purpose |
|------|---------|
| `bin/omd-restart` | Quickshell lifecycle management (start/stop apps, module enable/disable) |
| `bin/omd-action` | Route Hyprland bindings through ActionManager IPC |
| `bin/omd-doctor` | Runtime dependency and configuration diagnostic |
| `bin/omd-modules` | Module lifecycle management (list, info, install, update, remove) |
| `bin/omd-module-validate` | Module manifest validation (Python, schema-driven) |
| `bin/omd-wallpaper` | Wallpaper renderer/rotation (manages swaybg lifecycle) |
| `bin/omd-settings` | Thin shim → delegates to `$SUMIKA_MODULES_HOME/settings/bin/omd-settings` |
| `bin/omd-settings-tui` | TUI settings page router (dispatches to sumika-modules TUI pages) |
| `bin/omd-theme-bg-set` | Theme background setter |
| `bin/omd_tui_shared.py` | Shared Python TUI utilities |
| `bin/omd-kitty-smart-paste` | Terminal paste helper |
| `bin/omd-detach` | Process detachment utility |

## Thin Shim Scripts (Delegate to `share/bin/omarchy-*`)

| Path | Delegates To |
|------|-------------|
| `bin/omd-launch-or-focus` | `share/bin/omarchy-launch-or-focus` |
| `bin/omd-launch-or-focus-tui` | `share/bin/omarchy-launch-or-focus-tui` |
| `bin/omd-launch-or-focus-webapp` | `share/bin/omarchy-launch-or-focus-webapp` |
| `bin/omd-launch-tui` | `share/bin/omarchy-launch-tui` |
| `bin/omd-launch-webapp` | `share/bin/omarchy-launch-webapp` |
| `bin/omd-hyprland-*` (10 scripts) | `share/bin/omarchy-hyprland-*` |
| `bin/omd-hw-external-monitors` | `share/bin/omarchy-hw-external-monitors` |
| `bin/omd-toggle-touchpad` | `share/bin/omarchy-toggle-touchpad` |
| `bin/omd-wake` | `share/bin/omarchy-system-wake` |
| `bin/omd-lock` | `share/bin/omarchy-system-lock` |
| `bin/omd-logout` | `share/bin/omarchy-system-logout` |

## Thin Shim Scripts (Delegate to Module Bins)

| Path | Delegates To |
|------|-------------|
| `bin/omd-applauncher` | `$SUMIKA_MODULES_HOME/launcher/bin/omd-applauncher` |
| `bin/omd-applauncher-cache` | `$SUMIKA_MODULES_HOME/launcher/bin/omd-applauncher-cache` |
| `bin/omd-paste-at-cursor` | `$SUMIKA_MODULES_HOME/voice/bin/omarchy-paste-at-cursor` |
| `bin/omd-powerprofiles-init` | `$SUMIKA_MODULES_HOME/battery-power/bin/omarchy-powerprofiles-init` |
| `bin/omd-bar` | `quickshell/scripts/quickshell apps/omd-bar` |
| `bin/omd-polkit` | `quickshell/scripts/quickshell apps/omd-polkit` |

## Hyprland Configuration

| Path | Purpose |
|------|---------|
| `hypr/*.lua` | Hyprland configuration, bindings, rules, autostart |
| `hypr/hypridle.conf` | Idle management (lock, sleep, wake) |

## What Is NOT Allowed in OMD

The following types of business logic have been moved to `$SUMIKA_MODULES_HOME`
and must NOT be re-introduced into OMD:

- Product-floor module implementations (launcher, clock, notification-popup,
  workspaces, overview, systray, wifi, audio, power-indicator, display)
- Optional module implementations (17 additional modules)
- Module-private bin scripts (belong in the module's own `bin/` directory)
- Settings pages for non-Core functionality (network, bluetooth, sound,
  display, power, voice, keyremap, windows-vm)
- QML types for business features (OSD, overview, notification popup)
