# Overview Cross-Monitor Drag Debug Session Log

This document records iterative debugging changes made to the overview cross-monitor
drag bug (see `overview-cross-monitor-drag-bug.md`). Changes here are **temporary
debugging adjustments** — not permanent fixes — unless explicitly noted.

---

## Session: 2026-07-05

### Change 1 — Remove "current monitor first" sort priority

**File:** `quickshell/services/HyprlandData.qml` — `sortedOverviewMonitors()`

**What changed:** Removed the anchor/focused-monitor-first sorting logic that
put `GlobalStates.overviewAnchorMonitorName` (or `Hyprland.focusedMonitor`) at
the top of the monitor list. Now only stable physical position sort (y, then x)
is used.

```diff
 function sortedOverviewMonitors() {
-    const anchorName = GlobalStates.overviewOpen
-        ? (GlobalStates.overviewAnchorMonitorName || Hyprland.focusedMonitor?.name || "")
-        : (Hyprland.focusedMonitor?.name ?? "");
     return root.monitors.slice().sort((a, b) => {
-        const aAnchor = (a.name ?? "") === anchorName;
-        const bAnchor = (b.name ?? "") === anchorName;
-        if (aAnchor !== bAnchor)
-            return aAnchor ? -1 : 1;
         if ((a.y ?? 0) !== (b.y ?? 0))
             return (a.y ?? 0) - (b.y ?? 0);
         return (a.x ?? 0) - (b.x ?? 0);
     });
 }
```

**Why:** The focused-monitor-first sorting caused monitor group order in the
overview to change depending on which monitor the overview was opened from.
This made it harder to isolate whether cross-monitor drag bugs were caused by
monitor ordering instability or by the actual drag/commit logic. By fixing the
monitor order to a stable physical layout, we can eliminate one variable during
debugging.

**Status:** Temporary debugging change. Restore the anchor-first sorting once the
drag bug is fully understood and fixed, unless stable ordering turns out to be
preferable in the end.

---

### Active Debug Logging

During this session, `[GRP]` and `[WINREP]` console.log statements are active in:

- `quickshell/services/HyprlandData.qml` — `overviewWorkspaceEntriesGroupedByMonitor()`
  logs each monitor group's workspace entries and trailing IDs.
- `quickshell/modules/overview/OverviewWidget.qml` — window Repeater delegate logs
  why each window is included or filtered out.

These will be removed once the root cause is confirmed.
