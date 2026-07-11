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

### Legacy Monolithic Shell

- `quickshell/shell.qml`
- `quickshell/panelFamilies/`

Reason: current runtime starts split apps from `apps/omd-*`. Keeping the
monolithic shell preserves an old path that can silently reintroduce duplicate
modules.

Suggested action: delete after confirming no scripts, docs, or manual workflows
still call plain `qs` without `-p apps/omd-*`.

### Corners / Hot Corners

- `apps/omd-corners/`
- `quickshell/modules/screenCorners/`
- `bin/omd-corners`

Reason: `bin/omd-restart` explicitly keeps `omd-corners` disabled, and
`ScreenCorners.qml` has `hotCornersEnabled: false`.

Suggested action: delete if hot corners and screen-corner overlays are no
longer part of OMD's design.

### Zero-Reference Services

Static search found no references outside the service files themselves:

- `quickshell/services/HyprlandKeybinds.qml`
- `quickshell/services/SessionWarnings.qml`

Suggested action: inspect old cheatsheet/session modules before deleting. They
look like upstream leftovers in the current split session.

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

