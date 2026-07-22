# Overview Workspaces

Overview is a Core surface for inspecting and manipulating Hyprland workspaces.
The old standalone `omd-switcher` implementation no longer defines a separate
UI: Win+Tab uses Overview in switching mode.

## Modes

| Mode | Entry | Workspace model | Commit |
|---|---|---|---|
| Overview | Super release, bar, IPC | Groups for every monitor | Click, Enter, or explicit close |
| Switching | Win+Tab / Shift+Win+Tab | Trigger monitor only | Releasing the modifier |

`WorkspaceNavigation.overviewModel()` selects the model. While
`OverviewSwitchingController.grabbed` is true it returns the trigger monitor's
entries; otherwise it returns monitor groups from `HyprlandData`.

## Hyprland Model

Hyprland workspace IDs are global. A workspace belongs to a monitor through its
current `monitor` property; monitors do not own independent ID namespaces.
Never infer monitor ownership from an ID range.

For each monitor, `HyprlandData.overviewWorkspaceEntriesForMonitor()` builds:

1. Existing regular workspaces assigned to that monitor.
2. Pending drag state needed while Hyprland IPC catches up.
3. Exactly one trailing empty entry marked `isTrailingEmpty`.

The trailing entry is a creation target, is excluded from MRU ordering, and
must remain last. Moving a window to it occupies that workspace and causes a
new trailing entry to be calculated. Empty source workspaces are suppressed
while the asynchronous move settles.

## Ordering And Selection

- Normal Overview keeps entries grouped by monitor.
- Switching mode uses only the monitor captured in
  `GlobalStates.overviewAnchorMonitorName`.
- Existing workspaces follow the maintained MRU/order model; trailing entries
  are always appended after them.
- `GlobalStates.overviewFocusedWorkspaceId` is navigation state, not proof of
  monitor ownership.
- Each monitor group resolves its own active workspace and selected-window
  information.

`OverviewSwitchingController.openGrabbedMode()` opens the shared Overview,
queues one navigation step, and keeps subsequent key presses in the frozen
switching interaction. `commitGrabbedMode()` commits the selected workspace
and closes Overview.

## Window Drag Contract

All drag operations go through `WorkspaceNavigation`:

1. `beginWindowDrag()` records the source workspace.
2. `setDragTarget()` records the target and whether it is trailing.
3. `commitWindowDrag()` moves the window without following it, preserves the
   target monitor, updates pending occupancy, and schedules several refreshes.

Do not dispatch an independent move from a tile or group component. Duplicate
dispatch paths produce stale thumbnails, wrong-monitor placement, and extra
empty workspaces.

## Presentation Contract

- Monitor groups use the current theme accent only for active/focused borders.
- Empty entries render the current wallpaper from `Wallpaper` and never a
  bundled fallback image.
- Selection information is displayed below each monitor group; old per-tile
  hover title overlays are not part of the current UI.
- Grid columns are computed from available geometry and model size. Do not add
  a fixed five-column cap outside the configured maximum.

## Key Files

- `quickshell/modules/overview/Overview.qml`
- `quickshell/modules/overview/OverviewWidget.qml`
- `quickshell/modules/overview/OverviewSearch.qml`
- `quickshell/modules/common/functions/WorkspaceNavigation.qml`
- `quickshell/modules/common/functions/OverviewSwitchingController.qml`
- `quickshell/services/HyprlandData.qml`
- `quickshell/modules/common/GlobalStates.qml`

## Verification

Test both directions of every cross-monitor operation:

1. Open Overview on each monitor and verify each group marks its own active
   workspace.
2. Move a window between existing workspaces on the same monitor.
3. Move a window to the trailing entry on both monitors.
4. Move windows in both cross-monitor directions without closing Overview.
5. Confirm each group has exactly one trailing empty entry after updates settle.
6. Use Win+Tab and Shift+Win+Tab, then release the modifier and verify the
   selected workspace is committed on the trigger monitor.
