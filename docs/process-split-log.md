# Process Split Work Log

This document records the work completed during the first real Quickshell
process split.

## Commits

```text
9174fed Prepare workspace switcher split
c3b2aab Split quickshell into OMD app processes
db0e9a3 Fix split process IPC startup
490fe62 Split applauncher into separate omd-applauncher process
ec06d74 Fix switcher not closing on Super release
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

### Switcher (Win+Tab) bindings

The switcher bindings went through two iterations during the split.

**Phase 1 — IPC relay (broken).** The initial split replaced the monolith's
direct Quickshell `GlobalShortcut` bindings with IPC calls that relay through
`omd-switcher`:

```lua
o.bind("SUPER + TAB", "Quickshell switcher next",
  "qs -p $HOME/.config/omd/apps/omd-switcher ipc call switcher next")

o.bind("SUPER + SUPER_L", "Quickshell switcher commit",
  "qs -p $HOME/.config/omd/apps/omd-switcher ipc call switcher commit",
  { release = true })
```

This also dropped the monolith's `SUPER_L`/`SUPER_R` bare-key bindings that
fed the `quickshell:workspaceNumber` GlobalShortcut (which drives
`GlobalStates.superDown`). Without those bindings, `superDown` never changed
and the `onSuperDownChanged` commit path inside `omd-overview` was dead code.

**Phase 2 — direct GlobalShortcut (current).** The IPC relay introduced
process-spawn latency that caused the Super-release commit to sometimes not
fire or arrive too late, leaving the switcher panel visible after focus had
already switched. The fix restores direct GlobalShortcut bindings so the
overview process receives key events with zero IPC latency:

```lua
hl.bind("SUPER + TAB", hl.dsp.global("quickshell:overviewNext"))
hl.bind("SUPER + SHIFT + TAB", hl.dsp.global("quickshell:overviewPrev"))
hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:overviewCommit"), { release = true })
hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:overviewCommit"), { release = true })

-- Track Super key state directly so onSuperDownChanged fires in-process.
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER_R", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })
```

Because `GlobalShortcut` is registered per-process, both `omd-bar` and
`omd-overview` receive the `workspaceNumber` event and update their local
`GlobalStates.superDown`. The `omd-overview` instance is the one that matters
— its `onSuperDownChanged` connection calls `commitGrabbedMode()`.

`ignore_mods = true, transparent = true` is required so the bare `SUPER_L`
binding fires even while Super is held as a modifier (e.g. during
`SUPER+TAB`).

## Switcher Commit Architecture

The workspace switcher (Win+Tab) has three independent commit paths that
fire when Super is released. Understanding all three is essential for
debugging "switcher doesn't close" regressions.

### Key components

| File | Role |
|------|------|
| `GlobalStates.qml` | Owns `superDown` (driven by `workspaceNumber` GlobalShortcut) and `overviewOpen` |
| `WorkspaceSwitcherController.qml` | Owns `grabbed` state and `commitGrabbedMode()` |
| `WorkspaceNavigation.qml` | Owns workspace model, cycling, and `commitSelectedWorkspace()` |
| `Overview.qml` | Visual panel + keyboard handlers + GlobalShortcut registrations |

### The three commit paths

1. **`Keys.onReleased` (Overview.qml:224)** — when the overview panel has
   exclusive keyboard focus (`grabbed == true` → `WlrKeyboardFocus.Exclusive`),
   it receives the Super key-release event directly and calls
   `commitGrabbedMode()`. This is instant but only works if the panel
   already has keyboard focus by the time Super is released.

2. **`onSuperDownChanged` (Overview.qml:232)** — `GlobalStates.superDown`
   is driven by the `workspaceNumber` GlobalShortcut. When Super is released,
   `superDown` flips to `false`, triggering this connection which calls
   `commitGrabbedMode()`. This is the most reliable path because it doesn't
   depend on keyboard focus — it works as long as the Hyprland
   `SUPER_L`/`SUPER_R` bare-key bindings are present (see
   [Hyprland Bindings](#hyprland-bindings)).

3. **`overviewCommit` GlobalShortcut (Overview.qml:378)** — bound to
   `SUPER + SUPER_L` / `SUPER + SUPER_R` release in Hyprland. Calls
   `commitGrabbedMode()` directly. This is a redundant backup for path 2.

### What `commitGrabbedMode()` does

```js
function commitGrabbedMode() {
    if (!root.grabbed)          // guard: prevent double commits
        return;
    root.grabbed = false;       // release exclusive keyboard focus
    WorkspaceNavigation.commitSelectedWorkspace(true);  // focus workspace
    GlobalStates.overviewOpen = false;  // hide panel
}
```

The `grabbed` guard was added in `ec06d74` to make `commitGrabbedMode()`
idempotent. Without it, two paths firing in sequence (e.g.
`onSuperDownChanged` then the delayed `overviewCommit` GlobalShortcut)
would call `commitSelectedWorkspace` twice, causing the workspace to
toggle back and forth.

### Why the IPC relay broke

The Phase 1 split replaced all three direct paths with a single
double-hop IPC relay:

```
Hyprland SUPER release
  → qs -p .../omd-switcher ipc call switcher commit   (spawn process #1)
    → omd-switcher relay()
      → qs -p .../omd-overview ipc call switcher commit  (spawn process #2)
        → omd-overview WorkspaceSwitcherController.commitGrabbedMode()
```

Two `execDetached` process spawns introduced ~50-200 ms of latency.
Meanwhile `superDown` never changed (the `workspaceNumber` binding was
dropped), so path 2 was dead. Path 1 only worked if the panel had focus
in time. The result: focus switched (commit eventually arrived) but the
panel sometimes stayed visible because the commit was too late or the
focus was already gone.

### Monolith reference bindings

The original monolith (`~/.config/quickshell.backup-*/hypr/hyprland/keybinds.lua`)
used direct GlobalShortcut bindings throughout:

```lua
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true })
hl.bind("SUPER_L", hl.dsp.global("quickshell:workspaceNumber"), { ignore_mods = true, transparent = true, release = true })
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:overviewNext"))
hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:overviewCommit"), { release = true })
```

The current split restores these bindings verbatim. The only difference is
that `omd-switcher` still exists as a process (for future independent UI)
but is no longer in the critical path — the Hyprland bindings target the
overview process's GlobalShortcuts directly.

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

- `omd-switcher` is not yet visually independent and is no longer in the
  Win+Tab critical path (Hyprland bindings target `omd-overview`'s
  GlobalShortcuts directly). It can be removed or repurposed later.
- The old monolith had many other GlobalShortcut bindings that have not been
  migrated (sidebar toggles, clipboard, cheatsheet, region screenshot, etc.).
  These are currently dead and need to be restored or replaced with IPC.
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
