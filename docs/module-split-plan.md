# OMD Module Split Plan

This document records the intended direction for splitting oh-my-desktop into
smaller Quickshell modules that can be developed, packaged, restarted, and
debugged independently.

## Goals

- Keep the current desktop usable while refactoring.
- Avoid one broken module taking down the whole desktop shell.
- Make each feature easier to package and release later.
- Keep shared styling, helpers, services, assets, and translations in one place.
- Keep Omarchy and Quickshell under one project root: `~/development/OMD`.

Cleanup audit for old monolithic Quickshell code:
`docs/quickshell-cleanup-audit.md`.

## Current Runtime

Current active paths:

```text
~/.config/quickshell -> ~/development/OMD/quickshell
~/.config/omarchy    -> ~/development/OMD/omarchy
~/.config/omd        -> ~/development/OMD
```

Current Quickshell runtime is split into independent processes:

```sh
quickshell -p ~/.config/omd/apps/omd-bar
quickshell -p ~/.config/omd/apps/omd-desktop
quickshell -p ~/.config/omd/apps/omd-overview
quickshell -p ~/.config/omd/apps/omd-switcher
quickshell -p ~/.config/omd/apps/omd-applauncher
quickshell -p ~/.config/omd/apps/omd-corners
```

Current Omarchy autostart entry:

```lua
o.exec_on_start("$HOME/.config/omd/bin/omd-restart")
```

## Target Layout

Long-term target:

```text
~/development/OMD/
├── common/
│   ├── modules/common/
│   ├── services/
│   ├── assets/
│   └── translations/
├── apps/
│   ├── omd-bar/
│   ├── omd-desktop/
│   ├── omd-overview/
│   ├── omd-switcher/
│   ├── omd-session/
│   ├── omd-screenshot/
│   └── omd-settings/
├── bin/
│   ├── omd-bar
│   ├── omd-overview
│   ├── omd-switcher
│   └── omd-restart
├── config/
│   └── config.json
├── omarchy/
└── docs/
```

Each runnable module should have its own Quickshell process:

```sh
quickshell -p ~/.config/omd/apps/omd-bar
quickshell -p ~/.config/omd/apps/omd-desktop
quickshell -p ~/.config/omd/apps/omd-overview
quickshell -p ~/.config/omd/apps/omd-switcher
```

This process boundary is what gives crash isolation. Source-only separation is
not enough.

Use `quickshell/scripts/quickshell <app-config-dir>` or thin wrappers around it
for module launchers. The launcher exports:

```text
QS_CONFIG_DIR      current app config directory
OMD_APP_DIR        current app config directory
OMD_REPO_ROOT      repository root during source-tree development
OMD_QUICKSHELL_DIR current monolith quickshell directory during migration
```

## Proposed Modules

### `omd-bar`

Owns the persistent top bar and most always-on services.

Initial contents:

- Top bar
- Right module registry
- Weather
- Systray
- Clipboard button/dialog
- Screenshot menu
- Wi-Fi and Bluetooth dialogs
- Audio, mic, battery, power/sidebar indicators

### `omd-desktop`

Owns the desktop surface behind windows.

Initial contents:

- Wallpaper/background layer
- Blank desktop pointer interactions
- Double-click blank desktop to toggle the application launcher

Future contents:

- Desktop icons
- Desktop right-click menu
- Drag/drop behavior on the desktop surface

Reason to split: desktop interactions should stay independent from the bar and
overview. If future icon or right-click menu code breaks, the status bar and
overview should keep running.

Likely services:

- Audio
- Battery
- BluetoothStatus
- Network
- Notifications
- TrayService
- Weather
- GlobalFocusGrab
- PolkitService, if we keep a Quickshell polkit agent

### `omd-overview`

Owns workspace and window overview (工作区概览).

Initial contents:

- `modules/ii/overview/*`
- Only the Hyprland workspace/window data it actually needs
- IPC handlers for overview toggle, next, previous, commit

Reason to split early: overview has the highest risk of compositor/screencopy
edge cases and should not take down the bar.

### `omd-switcher`

Owns a lightweight window switcher (快速切换), separate from overview.

This should be designed as a smaller module instead of overloading overview.
Use the spelling `switcher`, not `swither`.

Current migration state:

- `SUPER+TAB`, `SUPER+SHIFT+TAB`, and Super release now use logical
  `switcherNext`, `switcherPrev`, and `switcherCommit` shortcut names.
- `omd-switcher` is a separate Quickshell process and currently relays to
  `omd-overview` for the visual surface.
- Shared rules live under `quickshell/modules/common/functions/`, currently
  `WorkspaceNavigation.qml` and `WorkspaceSwitcherController.qml`.

Expected behavior:

- Fast open/close
- Keyboard navigation
- No heavy background widgets
- Minimal services

### `omd-session`

Owns logout, poweroff, reboot, lock, and session UI.

This can be split after bar and overview, because it is less urgent and touches
security/session behavior.

### `omd-screenshot`

Owns region selector, delayed screenshot, color picker, and recording UI.

This may remain in `omd-bar` at first because the top bar exposes the menu.
Split when screenshot/recording behavior becomes large enough to justify a
separate process.

### `omd-settings`

Owns settings UI.

This should not run persistently. Start on demand.

## Service Ownership Rules

Do not blindly import every singleton service into every app. Some services
register DBus listeners or own external resources and should only run once.

Initial ownership:

```text
omd-bar:
  Audio, Battery, BluetoothStatus, Network, Notifications, TrayService,
  Weather, PolkitService, GlobalFocusGrab

omd-desktop:
  Hyprland workspace/fullscreen visibility data and background helpers only

omd-overview:
  HyprlandData, HyprlandKeybinds only if required

omd-switcher:
  HyprlandData only

omd-session:
  SessionWarnings and session helpers only
```

If a shared service is needed by multiple processes, prefer one of these:

- Move pure helper logic into `common`.
- Query Hyprland directly from the small app.
- Add a small IPC bridge later, only when needed.

## IPC Naming

Use stable names per process:

```text
omd-bar
omd-desktop
omd-overview
omd-switcher
omd-session
omd-screenshot
```

Example Hyprland bindings:

```lua
o.bind("SUPER + TAB", "Overview", hl.dsp.global("omd-overview:toggle"))
o.bind("SUPER + SPACE", "Switcher", hl.dsp.global("omd-switcher:toggle"))
```

Example Quickshell handler:

```qml
IpcHandler {
    target: "omd-overview"

    function toggle() {
        // Toggle overview.
    }
}
```

## Migration Order

1. Keep current `quickshell/` monolith working.
2. Extract common code into `common/` without changing runtime behavior.
3. Create `apps/omd-bar` and make it reproduce the current bar.
4. Change autostart to launch `bin/omd-bar`.
5. Extract `apps/omd-overview` and move Win+Tab bindings to it.
6. Extract `apps/omd-switcher`.
7. Extract session and screenshot modules if still useful.
8. Remove the old monolith only after the module set is stable.

## Compatibility Notes

- Keep `~/.config/quickshell` working until the new `~/.config/omd` runtime path
  is ready.
- Do not remove old launch paths in the same change that introduces new modules.
- Prefer one migration step per commit.
- After each split, verify:

```sh
hyprctl reload
pkill -f 'quickshell.* -p .*/omd-bar($| )' || true
bin/omd-bar
```

Then test the affected keybind or UI manually.
