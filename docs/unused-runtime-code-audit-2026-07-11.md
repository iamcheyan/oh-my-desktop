# Unused Runtime Code Audit - 2026-07-11

Scope: current split Quickshell session. Runtime evidence came from `qs list --all`,
`bin/omd-restart`, Hyprland bindings, and static imports.

## Current Runtime Entry Points

Currently running / launched by OMD:

- `apps/omd-bar/shell.qml`
- `apps/omd-desktop/shell.qml`
- `apps/omd-overview/shell.qml`
- `apps/omd-applauncher/shell.qml` on demand via `bin/omd-applauncher`
- `apps/omd-clipboard/shell.qml` on demand via `bin/omd-clipboard`
- `bin/omd-clipboard-store`

Currently not started by `bin/omd-restart`:

- `apps/omd-corners/shell.qml`

Legacy/default entry point:

- `quickshell/shell.qml` loads the old monolithic `panelFamilies/IllogicalImpulseFamily.qml`.
  The current session does not run this path.

## Removed In This Pass

- `quickshell/modules/appLauncher/`
  - Duplicate of the current app launcher implementation.
  - Current runtime uses `apps/omd-applauncher/modules/appLauncher/`.
  - Old monolithic panel family no longer embeds `AppLauncher`.
- `GlobalStates.appLauncherOpen`
  - No remaining consumers.
  - The current launcher is controlled by `bin/omd-applauncher` and IPC.
- `quickshell/shell.qml`
  - Legacy monolithic shell entry point.
  - Current runtime starts split apps from `apps/omd-*`.
- `quickshell/panelFamilies/`
  - Only used by the deleted monolithic `quickshell/shell.qml`.
- Legacy monolith kill rules in `scripts/omd-quickshell-stop.sh`
  - Removed `pkill` rules for `.../quickshell` and `~/.config/quickshell`
    monolith instances.
- `quickshell/services/HyprlandKeybinds.qml`
  - Static search found no references outside the service file.
  - The old cheatsheet/keybind consumer is no longer part of the current split
    runtime.
- `quickshell/services/SessionWarnings.qml`
  - Static search found no references outside the service file.
  - No current shell imports or calls it.

## Confirmed Already Removed Or In Progress

- Desktop/background clock widget code.
- Desktop/background weather widget code.
- Weather service and weather icon maps.
- Calendar UI under the old schedule popup.
- Top-bar clock calendar/schedule click behavior.

The notification list remains intentionally kept. It is now the only remaining
consumer under `quickshell/modules/schedulePopup/notifications/`.

## Strong Cleanup Candidates

These appear unused in the current split session and should be reviewed for
deletion in the next cleanup pass.

### Corners / Hot Corners

- `apps/omd-corners/`
- `quickshell/modules/screenCorners/`
- `bin/omd-corners`

Reason: `bin/omd-restart` explicitly keeps `omd-corners` disabled, and
`ScreenCorners.qml` has `hotCornersEnabled: false`.

Suggested action: delete if hot corners and screen-corner overlays are no
longer part of OMD's design.

## Documentation / Translation Debris

The following are not runtime code, but still contain stale weather/calendar or
old launcher references:

- `quickshell/docs/config-guide.md`
- `quickshell/docs/slimming-guide.md`
- `docs/quickshell-cleanup-audit.md`
- `docs/bar-right-modules.md`
- `docs/module-split-plan.md`
- `docs/process-split-log.md`
- `quickshell/translations/*.json`

Suggested action: clean docs/translations after runtime cleanup, otherwise they
will keep pointing future work back to deleted features.
