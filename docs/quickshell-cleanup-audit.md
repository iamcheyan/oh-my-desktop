# Quickshell Cleanup Audit

This document records the current cleanup analysis for the split Quickshell
runtime. It is an audit note, not a deletion request. Do not remove code from
this list until the owning runtime path and replacement behavior are confirmed.

## Active Runtime

The active desktop is launched through split app roots:

```text
apps/omd-bar/shell.qml
apps/omd-overview/shell.qml
apps/omd-switcher/shell.qml
apps/omd-applauncher/shell.qml
apps/omd-corners/shell.qml
apps/omd-clipboard/shell.qml
```

`~/.config/omd/bin/omd-restart` starts these processes. This means
`quickshell/shell.qml` and `quickshell/panelFamilies/` are no longer the normal
runtime path. They are currently legacy monolith/fallback code.

## Likely Legacy Monolith Code

These files exist for the original single-process shell and are not part of the
normal split runtime:

```text
quickshell/shell.qml
quickshell/panelFamilies/
```

They should only be deleted after deciding that the monolithic fallback is no
longer needed.

## Low-Risk Cleanup Candidates

The top bar now uses the unified `BarStatusPopup.qml` for status popups. These
old per-module info popups are likely removable after checking that no active
button or IPC path still instantiates them:

```text
quickshell/modules/bar/WifiInfoPopup.qml
quickshell/modules/bar/BluetoothInfoPopup.qml
quickshell/modules/bar/AudioInfoPopup.qml
quickshell/modules/bar/DisplayInfoPopup.qml
quickshell/modules/bar/BatteryInfoPopup.qml
quickshell/modules/bar/ClipboardInfoPopup.qml
quickshell/modules/bar/ResourcesPopup.qml
```

Current expected replacement:

```text
quickshell/modules/bar/BarStatusPopup.qml
```

## Schedule Popup

`SchedulePopup.qml` is the old standalone time popup shell. The current top-bar
time popup is hosted by `BarStatusPopup.qml` and embeds:

```text
quickshell/modules/schedulePopup/BottomWidgetGroup.qml
```

Potential cleanup:

```text
quickshell/modules/schedulePopup/SchedulePopup.qml
```

Do not delete the rest of `modules/schedulePopup/` while the unified time popup
still uses `BottomWidgetGroup`, calendar, todo, and pomodoro components.

## Settings

`quickshell/settings.qml` and `quickshell/modules/settings/` are not persistent
runtime processes, but they are still reachable from the control center:

```text
quickshell/modules/controlCenter/ControlCenterContent.qml
```

The settings button currently launches `settings.qml` with `qs`. Therefore:

- If the settings button stays, keep `quickshell/settings.qml` and
  `quickshell/modules/settings/`.
- If the old settings UI is retired, first remove or replace the control-center
  settings button, then remove these settings files.

## Session Screen

The control center currently sets:

```qml
GlobalStates.sessionOpen = true
```

But the split `omd-bar` runtime does not currently instantiate
`SessionScreen {}`. This leaves session UI in an ambiguous state:

```text
quickshell/modules/sessionScreen/
```

Choose one path before cleanup:

- Wire `SessionScreen {}` into `apps/omd-bar/shell.qml`; or
- Remove the control-center session button and delete `modules/sessionScreen/`.

## Split Modules Not Currently Loaded

These modules are loaded by the old monolithic panel family, not by the current
split app roots:

```text
quickshell/modules/background/
quickshell/modules/cheatsheet/
quickshell/modules/lock/
quickshell/modules/mediaControls/
```

They are not automatically safe to delete. Some still define IPC handlers or
global shortcuts in their own module files, but those handlers only exist if
the module is instantiated. Decide whether each feature should be migrated to a
split app or retired.

Suggested decisions:

```text
background     retire if wallpaper/background layer is no longer used
cheatsheet     retire or replace with external/docs workflow
lock           keep only if Quickshell lock screen is still intended
mediaControls  retire if audio popup/control center fully replaces it
```

## Clipboard Notes

Do not change clipboard behavior during cleanup unless explicitly requested.
Current clipboard runtime is split:

```text
apps/omd-clipboard/shell.qml
bin/omd-clipboard
bin/omd-clipboard-store
quickshell/services/Cliphist.qml
quickshell/modules/bar/ClipboardDialog.qml
quickshell/modules/bar/ClipboardItem.qml
```

Clipboard also has existing in-progress local changes. Treat them as user work
unless explicitly told to edit them.

## Recommended Cleanup Order

1. Remove old `*InfoPopup.qml` files after a final `rg` confirms no active
   loaders reference them.
2. Remove `SchedulePopup.qml` only, keeping `BottomWidgetGroup` and children.
3. Decide settings fate; remove the control-center settings button before
   deleting `settings.qml`.
4. Decide session fate; either wire `SessionScreen` into `omd-bar` or remove
   the dead button and module.
5. Decide whether to migrate or retire background, cheatsheet, lock, and media
   controls.
6. Delete `quickshell/shell.qml` and `quickshell/panelFamilies/` only after the
   monolithic fallback is intentionally retired.

## Verification Before Deleting

Before removing any candidate, run targeted searches:

```sh
rg -n "ComponentName|IpcTarget|GlobalShortcutName" quickshell apps omarchy bin
```

Then restart and inspect logs:

```sh
python -m json.tool quickshell/config.json >/tmp/omd-config-check.json
sh -n quickshell/scripts/quickshell
~/.config/omd/bin/omd-restart
```
