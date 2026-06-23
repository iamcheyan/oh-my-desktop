# Process Split Work Log

This document records the work completed during the first real Quickshell
process split.

## Commits

```text
9174fed Prepare workspace switcher split
c3b2aab Split quickshell into OMD app processes
db0e9a3 Fix split process IPC startup
```

## What Changed

The active runtime is now split into four Quickshell processes:

```text
quickshell -p ~/.config/omd/apps/omd-bar
quickshell -p ~/.config/omd/apps/omd-overview
quickshell -p ~/.config/omd/apps/omd-switcher
quickshell -p ~/.config/omd/apps/omd-applauncher
```

The compatibility monolith still exists at:

```text
~/.config/quickshell -> ~/development/OMD/quickshell
```

The split runtime root is:

```text
~/.config/omd -> ~/development/OMD
```

## App Responsibilities

### `omd-bar`

Owns the persistent shell UI:

- top bar
- bar dialog overlay
- right sidebar
- schedule popup
- notification popup
- OSD
- screen corner chrome and hot corners
- polkit UI

The Workspaces button and top-left hot corner now call `omd-overview` over IPC.
The "Applications" button and top-right hot corner now call `omd-applauncher`
over IPC instead of toggling `GlobalStates.appLauncherOpen` in-process.

### `omd-overview`

Owns the current overview visual surface:

- workspace overview windows
- current Win+Tab visual surface
- overview IPC target
- switcher IPC target used by `omd-switcher`

### `omd-switcher`

Owns the `SUPER+TAB` shortcut process.

For now it is a lightweight relay:

```sh
qs -p ~/.config/omd/apps/omd-overview ipc call switcher next
qs -p ~/.config/omd/apps/omd-overview ipc call switcher prev
qs -p ~/.config/omd/apps/omd-overview ipc call switcher commit
```

Later it can render its own UI while continuing to use the shared workspace
rules.

### `omd-applauncher`

Owns the app launcher panel (searchable application grid with pinned apps and
running indicators). It is a standalone process with its own `IpcHandler`
exposing `appLauncher toggle/open/close`.

Callers that previously toggled `GlobalStates.appLauncherOpen` in-process now
relay over IPC:

- `quickshell/modules/ii/bar/BarContent.qml` — "Applications" button
- `quickshell/modules/ii/screenCorners/ScreenCorners.qml` — top-right hot corner
- `quickshell/modules/common/functions/WorkspaceNavigation.qml` — opens the
  launcher when committing to a trailing empty workspace

The launcher no longer reads `GlobalStates.appLauncherOpen`; visibility is
driven by a local `open` property set through the IPC handler.

## Shared Workspace Rules

Shared logic was extracted into:

```text
quickshell/modules/common/functions/WorkspaceNavigation.qml
quickshell/modules/common/functions/WorkspaceSwitcherController.qml
```

These own the common behavior used by overview and switcher:

- current workspace detection
- overview workspace model
- MRU workspace ordering
- keyboard cycling
- commit selected workspace
- trailing empty workspace behavior
- window focus
- drag target state
- move window to workspace

## Runtime Launch

Omarchy autostart now launches:

```lua
o.exec_on_start("$HOME/.config/omd/bin/omd-restart")
```

`omd-restart` starts the four apps as user systemd transient services when
available:

```text
omd-bar.service
omd-overview.service
omd-switcher.service
omd-applauncher.service
```

This matters because plain background shell jobs were cleaned up after
Hyprland reload/autostart, causing the apps to disappear.

Fallback behavior still uses `setsid` if user systemd is unavailable.

## Hyprland Bindings

The `SUPER+TAB` bindings no longer use Quickshell global shortcut names.
They now call IPC directly:

```lua
o.bind("SUPER + TAB", "Quickshell switcher next",
  "qs -p $HOME/.config/omd/apps/omd-switcher ipc call switcher next")

o.bind("SUPER + SHIFT + TAB", "Quickshell switcher previous",
  "qs -p $HOME/.config/omd/apps/omd-switcher ipc call switcher prev")
```

Super release commits through the same process:

```lua
o.bind("SUPER + SUPER_L", "Quickshell switcher commit",
  "qs -p $HOME/.config/omd/apps/omd-switcher ipc call switcher commit",
  { release = true })
```

This avoided namespace issues after splitting Quickshell into separate app
roots.

## IPC Fixes

Cross-process QML calls now trim `file://` from XDG config paths before passing
them to `qs -p`.

Affected callers:

- `quickshell/modules/ii/bar/Workspaces.qml`
- `quickshell/modules/ii/screenCorners/ScreenCorners.qml`
- `apps/omd-switcher/shell.qml`

## Verification Performed

Static checks:

```sh
sh -n quickshell/scripts/quickshell
sh -n bin/omd-bar
sh -n bin/omd-overview
sh -n bin/omd-switcher
sh -n bin/omd-restart
python -m json.tool quickshell/config.json >/tmp/omd-config-check.json
luac -p omarchy/hypr/autostart.lua
luac -p omarchy/hypr/bindings.lua
```

Runtime checks:

```sh
~/.config/omd/bin/omd-restart
hyprctl reload
pgrep -af '/usr/bin/quickshell -p .*/omd/apps/omd-(bar|overview|switcher)'
```

IPC checks:

```sh
qs -p ~/.config/omd/apps/omd-switcher ipc call switcher next
qs -p ~/.config/omd/apps/omd-switcher ipc call switcher commit
qs -p ~/.config/omd/apps/omd-overview ipc call overview toggle
qs -p ~/.config/omd/apps/omd-overview ipc call overview close
```

Crash isolation check:

```sh
kill "$(pgrep -f '/usr/bin/quickshell -p .*/omd/apps/omd-overview' | head -n1)"
pgrep -af '/usr/bin/quickshell -p .*/omd/apps/omd-(bar|overview|switcher)'
~/.config/omd/bin/omd-overview
```

Result: killing `omd-overview` left `omd-bar` and `omd-switcher` running.

## Current Known Limitations

- `omd-switcher` is not yet visually independent; it relays to
  `omd-overview`.
- App roots currently symlink shared source directories from `quickshell/`.
  This gives process isolation now, but source packaging still needs a cleaner
  `common/` layout later.
- Some singleton services are still imported broadly through shared QML imports.
  Further pruning is needed so each app only loads the services it owns.
- `omd-bar` currently owns several adjacent surfaces, including sidebar,
  notification popup, OSD, screen corners, and polkit. These can be split
  later if needed.

## Next Steps

1. Give `omd-switcher` its own lightweight UI instead of reusing the overview
   visual surface.
2. Redesign `omd-overview` on top of `WorkspaceNavigation`.
3. Move symlinked shared code into a real `common/` tree.
4. Reduce service imports per app.
5. Add package/build scripts once the process boundaries are stable.
