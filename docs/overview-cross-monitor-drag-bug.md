# Overview Cross-Monitor Drag Bug

## Problem

The workspace overview can show monitor groups vertically even when Hyprland
arranges the physical monitors horizontally. In the current laptop + external
monitor setup, Hyprland reports:

- `eDP-1`: internal display
- `HDMI-A-1`: external display
- Both monitors share `y=0`, so the real compositor layout is horizontal.

The overview deliberately renders these monitor groups vertically. This means
window coordinates, monitor coordinates, and overview-card coordinates are three
different coordinate systems.

The long-standing bug appears when dragging a window from the upper overview
group to the lower group's trailing `New workspace` slot while the overview is
shown on the external monitor:

1. The drag is committed successfully in Hyprland.
2. Closing and reopening overview shows the window on the expected workspace.
3. During the still-open overview session, the target group may continue to show
   only the old workspace and a blank `New workspace` card.

The reverse drag direction can work because the target group is often the current
anchor/focused monitor group, so Hyprland and the overview model settle in the
same direction sooner.

## Root Cause

The trailing `New workspace` card is a Quickshell model entry, not necessarily a
real Hyprland workspace yet.

When a window is dropped on that card, Hyprland creates or moves the target
workspace asynchronously. The overview model is rebuilt from:

- `hyprctl workspaces`
- `hyprctl clients`
- Quickshell `ToplevelManager`
- the overview's monitor grouping rules

Those sources do not update atomically. During the short inconsistent window, the
overview may not treat the target workspace as occupied, so it keeps rendering
the same trailing empty card instead of:

```text
[old occupied workspace] [new occupied workspace] [new trailing empty workspace]
```

Previous attempted fixes incorrectly pushed pending state into the window
thumbnail path. That is unsafe because thumbnails depend on the real
`ToplevelManager` and `HyprlandData.windowByAddress` state. If a pending
workspace id does not match the real window state in that frame, all thumbnails
can be filtered out.

## Design Rule

Do not fake window thumbnails.

Window thumbnails must continue to render only from real Hyprland window data.
The temporary state belongs only in the workspace model:

- It may add a pending occupied workspace card.
- It may force the next trailing empty workspace to advance.
- It must not override `windowData.workspace.id`.
- It must not change `ToplevelManager` filtering.

## Fix Strategy

When a drag is committed to a trailing empty workspace:

1. Record a pending occupied workspace:
   - workspace id
   - target monitor name
2. Rebuild the overview model with that pending workspace included as a normal
   non-empty entry.
3. Append exactly one trailing empty workspace after it.
4. Dispatch the real Hyprland move:
   - move window to workspace
   - move workspace to target monitor
5. Refresh Hyprland data a few times.
6. Clear the pending entry once real Hyprland clients show that workspace has a
   visible window, or when overview closes.

This gives immediate model feedback without corrupting thumbnail rendering.

## Why Closing/Reopening Appears to Fix It

Closing overview and opening it again performs a full rebuild:

- the overview process recomputes monitor groups;
- `HyprlandData.updateAll()` samples clients, workspaces, monitors, and active
  state again;
- QML repeaters are recreated from the current `ToplevelManager` and
  `windowByAddress` data.

The drag has already succeeded in Hyprland by that point, so the rebuilt model
looks correct. The broken case is only the live, still-open overview session.

The fix therefore includes an explicit overview refresh serial:

- `HyprlandData.dataSerial` increments whenever a Hyprland sample completes;
- `GlobalStates.overviewRefreshSerial` increments when overview needs a forced
  model rebuild, especially after a drag commit;
- `OverviewWidget` binds both workspace entries and window repeaters to those
  serials.

This makes the open overview behave like a lightweight rebuild without closing
the UI.
