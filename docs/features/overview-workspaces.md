# Overview Workspaces

Overview is a Core surface for inspecting and manipulating Hyprland workspaces.
The old standalone `sumika-switcher` implementation no longer defines a separate
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
- Within each monitor group, normal Overview follows the persisted visual
  order maintained by `WorkspaceOrder`. Hyprland IDs are not sort keys.
- `Super+number` addresses the corresponding global visual slot, not the raw
  Hyprland workspace ID. Slot numbering follows the complete monitor-grouped
  Overview model, continuing across monitors in their visual order. Focusing
  a slot also focuses the monitor that owns it. Real IDs are global and may
  contain gaps after empty workspaces disappear.
- Switching mode uses only the monitor captured in
  `GlobalStates.overviewAnchorMonitorName` and orders existing workspaces by
  MRU for Win+Tab cycling.
- Trailing entries are always appended after existing workspaces in both modes.
- `GlobalStates.overviewFocusedWorkspaceId` is navigation state, not proof of
  monitor ownership.
- Each monitor group resolves its own active workspace and selected-window
  information.

`OverviewSwitchingController.openGrabbedMode()` opens the shared Overview,
queues one navigation step, and keeps subsequent key presses in the frozen
switching interaction. `commitGrabbedMode()` commits the selected workspace
and closes Overview.

## Workspace Identity And Recyclable IDs

### User identity and compositor identity are separate

Overview exposes a visual **Slot** while Hyprland exposes a numeric workspace
**ID**. They must not be treated as the same namespace:

```text
Slot 1 -> Hyprland ID 12
Slot 2 -> Hyprland ID 5
Slot 3 -> Hyprland ID 18
Slot 4 -> Hyprland ID 7
```

`Super+number` addresses the Slot. Move/focus dispatches resolve that Slot to
its current Hyprland ID immediately before sending the command. The raw ID is
diagnostic data and must not determine presentation order.

This separation is required because Hyprland destroys most empty workspaces.
Allocating every new trailing workspace as `maxId + 1` causes a ratchet: moving
the last window from 19 to 20 destroys 19, but the next candidate becomes 21.
The old implementation also limited IDs to 1-100, so repeated use could
eventually remove the New Workspace entry entirely.

### Shared state

`WorkspaceOrder` stores generated runtime state at:

```text
${SUMIKA_SHELL_STATE_HOME:-$XDG_STATE_HOME/sumika-shell}/workspace-order.json
```

The file is runtime state, not user configuration, and must not be committed.
Schema version 1:

```json
{
  "schemaVersion": 1,
  "hyprlandInstanceSignature": "instance signature",
  "monitorOrders": {
    "eDP-1": [12, 5, 18, 7],
    "HDMI-A-1": [9, 3]
  },
  "releasedIds": [4, 6, 11]
}
```

The Overview Quickshell process is the only writer. Other shell processes may
load and watch the file, but must not persist their independently sampled
Hyprland state. This prevents the bar process and the on-demand Overview
process from racing each other.

The Hyprland instance signature scopes the state to one compositor session.
A Quickshell reload in the same session preserves order. A new compositor
session discards stale ordering and reconstructs it from live workspaces; this
prevents a newly-created workspace from inheriting the position of an unrelated
workspace that happened to reuse the same ID in another session.

### Reconciliation

After a Hyprland data refresh, reconcile the saved state with the complete live
snapshot:

1. Build occupied regular IDs for every monitor from mapped, visible clients.
2. Include pending drag targets before Hyprland IPC settles.
3. For each monitor, keep surviving IDs in their previous visual order.
4. Append live IDs not present in state in numeric order. Numeric order is only
   a deterministic recovery rule for unknown entries, not ongoing UI order.
5. If a workspace changes monitor, remove it from the old monitor order and
   append it to the destination monitor order.
6. Remove vanished monitor keys.
7. IDs that disappeared from every occupied/pending set enter `releasedIds`.
8. A released ID may remain queued while Hyprland still exposes an empty
   workspace with that ID; the allocator treats every live, pending, and
   already-reserved candidate as unavailable until it is actually reusable.

State writes are debounced and occur only when normalized state actually
changes. A partial `hyprctl` refresh must not erase all order: reconciliation
waits until monitors, workspaces, and clients have each loaded at least once.

### Global ID allocator

Each monitor receives exactly one trailing candidate. Candidate IDs are
allocated globally and deterministically in stable monitor order.

For every candidate:

1. Treat all regular Hyprland workspaces, visible client workspace IDs,
   pending drag targets, and candidates already assigned to earlier monitors
   as unavailable.
2. Use the first valid ID from `releasedIds`.
3. If none is available, use the smallest free positive ID in the 1-100 pool.
4. If the pool is exhausted, omit only the candidate and emit a warning; never
   collide with or renumber a live workspace.

When a trailing candidate becomes occupied, reconciliation appends it to that
monitor's visual order even if the recycled ID is numerically smaller than all
existing IDs. For example, ID 7 remains the last Slot after IDs 12, 13, and 18.

The allocator never renumbers a live workspace. Compaction by moving every
window to new IDs would cause focus jumps, stale drag targets, cross-monitor
movement, and broken references in external Hyprland clients.

### Consumers and invariants

Normal Overview consumes persisted order. Win+Tab starts from the same ordered
entries but applies its separate MRU ordering to occupied entries; the trailing
candidate remains last. Global numeric shortcuts consume the complete grouped
visual model, so `Super+4` resolves Slot 4 regardless of its raw ID.

The implementation must preserve these invariants:

- raw IDs are unique globally across all monitor groups and candidates;
- every monitor has at most one trailing candidate;
- trailing candidates are always visually last;
- occupied entries never reorder merely because an ID was recycled;
- reload in one Hyprland session preserves visual order;
- a new Hyprland session cannot inherit stale ID identity;
- pending drag targets cannot be handed out as candidates;
- no allocator path moves or renumbers a live workspace;
- an invalid/corrupt state file falls back to deterministic live ordering.

### Required allocator tests

Before changing allocation or reconciliation, cover at least:

1. repeated create/remove cycles reuse IDs instead of increasing forever;
2. a recycled low ID remains the last visual Slot;
3. two monitors receive different candidates;
4. pending drag IDs are unavailable to the allocator;
5. a workspace moved between monitors is appended only to its destination;
6. a Quickshell reload with the same signature restores exact order;
7. a different signature resets stale state;
8. malformed JSON recovers without losing the live workspace model;
9. pool exhaustion produces no duplicate ID;
10. MRU switching does not modify persisted normal Overview order.

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
- Workspace selection and window hover are represented by the outer workspace
  border. Window previews keep a neutral separator and must not add a second
  accent border.
- Empty entries render the current wallpaper from `Wallpaper` and never a
  bundled fallback image.
- Selection information is displayed below each monitor group; old per-tile
  hover title overlays are not part of the current UI.
- The selection information bar has one live selection resolver. Its priority
  is hovered window, hovered workspace background, keyboard-selected workspace,
  then the first entry in the local monitor group. Tab, arrows, H/J/K/L,
  Win+Tab, wheel navigation, and pointer movement must all feed this resolver.
- A keyboard selection change clears stale pointer state. Hovered windows are
  resolved again through the current `windowByAddress` map so title changes and
  closed windows cannot leave stale information behind. If model refresh
  removes the selected workspace, selection falls back to a valid local entry.
- Grid columns are computed from available geometry and model size. Do not add
  a fixed five-column cap outside the configured maximum.

## Geometry And HiDPI Coordinates

Overview reconstructs every client inside a scaled workspace card from
`hyprctl -j monitors` and `hyprctl -j clients`. These fields do not all use the
same unit:

- monitor `width` and `height` are physical pixel dimensions;
- monitor `scale` converts physical pixels to logical display coordinates;
- monitor `x`, `y`, and `reserved` margins are layout/logical coordinates;
- client `at` and `size` are compositor geometry in logical coordinates.

Always convert the physical monitor dimension before subtracting the reserved
area:

```text
usableLogicalWidth = physicalWidth / scale - reservedLeft - reservedRight
usableLogicalHeight = physicalHeight / scale - reservedTop - reservedBottom
```

Do not use this superficially similar formula:

```text
(physicalHeight - reservedTop - reservedBottom) / scale
```

The latter divides the already-logical reserved area by the monitor scale a
second time. On a HiDPI display it makes the workspace card taller than the
actual usable area. Client Y is still calculated with the full logical top
reservation and clamps correctly to the top, so the surplus height appears
only below the window: the preview looks top-aligned with a wallpaper strip at
the bottom.

The coordinate contract is implemented centrally by
`OverviewWidget.usableLogicalWidth()` and `usableLogicalHeight()`. Workspace
aspect ratio, per-monitor `scaleX`/`scaleY`, and fallback geometry must all use
those helpers. `OverviewWindow` uses the same conversion for its stale-geometry
fallback.

Hyprland `gaps_out` remains intentional. A single tiled window may therefore
show a small, symmetric wallpaper margin after this correction. The bug is an
asymmetric bottom-only surplus that grows with monitor scale and the reserved
top-bar height.

When changing this code, verify at minimum:

1. scale 1 with and without a reserved top bar;
2. scale 2 with a reserved top bar;
3. a rotated monitor (`transform & 1` swaps physical axes);
4. different scale factors in a multi-monitor Overview;
5. one tiled window shows symmetric outer gaps rather than a bottom strip;
6. floating and cross-monitor windows retain their relative position.

## Key Files

- `quickshell/services/WorkspaceOrder.qml`
- `quickshell/services/HyprlandData.qml`
- `quickshell/modules/common/functions/WorkspaceNavigation.qml`
- `quickshell/modules/overview/Overview.qml`
- `quickshell/modules/overview/OverviewWidget.qml`
- `quickshell/modules/overview/OverviewSearch.qml`
- `quickshell/modules/common/functions/WorkspaceNavigation.qml`
- `quickshell/modules/common/functions/OverviewSwitchingController.qml`
- `quickshell/services/HyprlandData.qml`
- `quickshell/modules/common/GlobalStates.qml`

## Performance And Startup Latency

Overview must feel instant on both entry paths — the Super-alone release
(`workspaceNumber` GlobalShortcut) and the bar Workspaces button (`overview.open`
action → `sumika-overview` → Quickshell IPC). Three rules hold the latency down:

### 1. Coalesce Hyprland event bursts (HyprlandData.qml)

`HyprlandData` re-fetches `clients`, `monitors`, `workspaces`, and
`activewindow` from `hyprctl -j`. The `Connections` on `Hyprland.onRawEvent`
restarts a ~60 ms debounce timer instead of calling `updateAll()` directly.
Hyprland emits many events in a burst when the overview layer appears
(`activewindow`, `focusedmon`, `movewindow`, …); without coalescing each event
spawned 4+ `hyprctl` children that raced the overview's own render and
`ScreencopyView` capture. `activeWindow` is still refreshed immediately for
`focusedClientForWorkspace` responsiveness — only the heavy re-fetch is
debounced.

`getLayers` was removed (its `layers` property was never read). `activeWorkspace`
is derived from the native `Hyprland.focusedWorkspace` model (only `.id` is
consumed), so `getActiveWorkspace` polling was removed too.

Do **not** add `updateAll()` calls from event handlers without the debounce
timer, and do not re-introduce `getLayers`/`getActiveWorkspace` polling.

### 2. Asynchronous, keep-alive widget tree (Overview.qml)

The `OverviewWidget` `Loader` uses `asynchronous: true` so the scrim paints on
the first frame while the Repeater/ScreencopyView tree incubates, instead of
blocking the render thread. After the first open it stays `active` (gated by a
`wasOpened` flag); repeat opens only flip the component's `visible` and are
instant. Qt does not render invisible items, and `ScreencopyView` with
live:true only captures while visible, so holding the tree costs nothing while
closed.

### 3. The `sumika-overview` launcher must detect the live process

`bin/sumika-overview` decides between an IPC toggle and a cold `launch_direct`.
`is_running` resolves the module directory with `pwd -P` so the `pgrep` pattern
matches the running process's cmdline even when it was launched through the
`$SUMIKA_SHELL_ROOT` symlink. A mismatch makes every click-path `open` fall through
to `launch_direct` and stall for seconds.

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
