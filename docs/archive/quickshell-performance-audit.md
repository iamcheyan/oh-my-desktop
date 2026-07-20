# Quickshell Performance & Bug Audit

This document records the audit of the `quickshell/` tree (services, bar
modules, common widgets, shell entry points, panel families, overview, and
app launcher) for performance problems, bugs, and optimization opportunities.

Each entry lists the file and line, the problem, why it matters, and the
planned fix. Fixes are applied one by one, each in its own commit, and
checked off here as they land.

---

## Critical Performance Issues

### [x] 1. ResourceUsage: 1ms startup timer + spread/shift history buffers
**File:** `quickshell/services/ResourceUsage.qml:62-98`, `:38-55`

A `Timer` with `interval: 1, running: true, repeat: true` does file I/O on
`/proc/meminfo` and `/proc/stat`, runs 4 regexes, and only at the end of
`onTriggered` sets `interval = Config.options?.resources?.updateInterval ?? 3000`.

The history buffers use `memoryUsageHistory = [...memoryUsageHistory, val]`
followed by `shift()`, doing two O(n) array reallocations per sample, three
times per sample (memory, swap, cpu). Each triggers a binding invalidation
that re-renders bound graphs.

**Why it matters:**
- Startup CPU spike (1ms timer doing file I/O + regex + 3 array copies).
- If `onTriggered` throws before the interval reassignment, the timer is
  trapped at 1ms forever — effectively a busy loop.
- Per-sample O(n) churn feeds `Graph.qml` rendering.

**Fix:**
- Use `triggeredOnStart: true` with the real interval (3000ms). Remove the
  interval self-mutation.
- Wrap the body in try/finally so a parse error cannot trap the timer.
- Replace spread/shift with a fixed-size ring buffer (push + shift via index,
  or `splice(0,1)` after manual signal emission).

### [x] 2. DateTime: 10ms uptime timer reads /proc/uptime
**File:** `quickshell/services/DateTime.qml:28-53`

Same 1ms/10ms self-mutating interval pattern. Uptime has minute-level
resolution but is read every 10ms at startup.

**Fix:** `triggeredOnStart: true`, real interval (uptime needs ~30s, not 3s).
Remove interval self-mutation.

### [x] 3. TimerService: 10ms stopwatch timer drives a property binding
**File:** `quickshell/services/TimerService.qml:105-111`

`interval: 10` re-evaluates `stopwatchTime` 100 times/second; any UI bound to
it re-renders at 100Hz. If the display only shows seconds, this is 100x
over-sampling.

**Fix:** Drive the timer at display precision: 250ms for seconds, 10ms only
if centiseconds are shown — and ensure only the centisecond label binds to it.

### [x] 4. OverviewWidget: comma-operator `modelRevision` hack
**File:** `quickshell/modules/overview/OverviewWidget.qml:20-27,725`

`overviewEntries` is bound as `(root.modelRevision, fn())` where
`modelRevision = HyprlandData.dataSerial + GlobalStates.overviewRefreshSerial
+ ToplevelManager.toplevels.values?.length`. `dataSerial` increments on *any*
Hyprland event, so every event re-runs `overviewWorkspaceEntriesGroupedByMonitor()`
+ the toplevel filter + monitorGroups + overviewEntryIds — a cascade of
O(workspaces × windows) recomputations.

**Fix:** Have `HyprlandData` expose proper grouped models (or a dedicated
`overviewEntriesChanged` signal). Remove the comma-operator dependency
injection; bind directly so only structural changes trigger re-evaluation.

### [x] 5. SessionButton: 5s polling spawns `hyprctl -j clients | jq`
**File:** `quickshell/modules/bar/modules/SessionButton.qml:33-81`

A 5000ms repeat timer always running spawns two processes, including
`hyprctl -j clients | jq` which parses the full client list. The data is
already tracked by `HyprlandData`, and the UI only needs it when the session
menu is open.

**Fix:** Drive `canvasEmpty` from `HyprlandData` client tracking; only poll
while the menu is open.

---

## Moderate Performance / Correctness Issues

### [x] 6. Network: nmcli monitor cascade + AP createObject churn
**File:** `quickshell/services/Network.qml:321-490`

`nmcli monitor` restarts `debounceUpdateTimer` (1500ms) on every line; each
fire spawns 5 processes. `getNetworks` diffs APs and calls
`apComp.createObject`/`destroy()`. `friendlyWifiNetworks` re-sorts the full
list on every mutation.

**Fix:** Coalesce to ~3000ms. Cache the sort in `friendlyWifiNetworks` and
only re-sort on membership/strength/active changes.

### [x] 7. Notifications: per-notification createObject + full-list JSON.stringify
**File:** `quickshell/services/Notifications.qml:162-186,192-205`

Each notification calls `createObject` twice and `JSON.stringify`s the whole
list to file. `discardNotification` uses `list = list.slice(0)` to force the
change signal (QML anti-pattern). `popupList`/`groupsByAppName` re-filter/
re-group the entire list on every change.

**Fix:** Adopt a real list model (QAbstractListModel / Quickshell's
ListModel) for granular signals. Debounce file writes (~500ms).

### [x] 8. Notifications: `onListChanged` rebuilds `latestTimeForApp` from scratch
**File:** `quickshell/services/Notifications.qml:96-109`

O(n + apps) on every list mutation; redundant with `groupsForList`.

**Fix:** Maintain `latestTimeForApp` incrementally on add/discard, or fold
into `groupsForList`.

### [x] 9. GlobalFocusGrab: `hasActive` recursively walks the UI tree
**File:** `quickshell/services/GlobalFocusGrab.qml:55-67`

The `windows` binding re-evaluates by recursively walking `children` of every
dismissable window reading `activeFocus`. Re-runs on every focus change
among those windows.

**Fix:** Track active focus per-window via `FocusHandler` and bind to flat
per-window properties.

### [x] 10. Hyprsunset: spawns processes on every gamma/temp change
**File:** `quickshell/services/Hyprsunset.qml:86-126`

`setGamma`/`enableTemperature`/`disableTemperature` each spawn `pidof` +
`hyprsunset` + `hyprctl`. Dragging the gamma slider spawns many processes.

**Fix:** Debounce `setGamma`/`enableTemperature` (150-300ms). Only ensure
hyprsunset is running once at load and on `enableTemperature`, not on every
`setGamma`.

---

## Minor / Style / Correctness Issues

### [x] 11. MaterialSymbol: `Behavior on fill` leak + string-typed axis
**File:** `quickshell/modules/common/widgets/MaterialSymbol.qml:23,8`

Author comment "Leaky leaky, no good". `truncatedFill = fill.toFixed(1)`
returns a string but is assigned to `variableAxes: { "FILL": truncatedFill }`
(a numeric field), rebuilding the object every frame of the 200ms animation.

**Fix:** Investigate the leak. Use `Math.round(fill * 10) / 10` to keep a
number; cache `variableAxes` unless the truncated value actually changes.

### [x] 12. OverviewSearch: opacity animation defeated by `visible`
**File:** `quickshell/modules/overview/OverviewSearch.qml:214-215`

`visible: root.searchMode` + `opacity: root.searchMode ? 1 : 0` + `Behavior
on opacity`. The fade-out never plays because `visible` flips false first.

**Fix:** Drive `visible` from the opacity Behavior's completion, or drop the
opacity binding if no fade-out is wanted.

### [x] 13. SystemInfo: `interval:1, repeat:false` used as "run once"
**File:** `quickshell/services/SystemInfo.qml:26-31`

**Fix:** Move the body into `Component.onCompleted`.

### [x] 14. ConflictKiller: `echo "$(pidof ...)"` shell anti-pattern
**File:** `quickshell/services/ConflictKiller.qml:25-47`

**Fix:** Use `pgrep` directly.

### [x] 15. Network: `running=false; running=true` restart race
**File:** `quickshell/services/Network.qml:273-276`

**Fix:** Use a dedicated exec call or wait for the previous `onExited`.

### [x] 16. Notifications: `actions` binding null-unsafe inside map
**File:** `quickshell/services/Notifications.qml:23-26`

`notification?.actions.map(...)` throws if `notification.actions` is
undefined.

**Fix:** `notification?.actions?.map(...) ?? []`.

### [x] 17. CircularProgress: `Loader` for a toggleable Rectangle
**File:** `quickshell/modules/common/widgets/CircularProgress.qml:41-49`

**Fix:** Use `visible: root.fill` on a static `Rectangle`.

---

## Highest-impact fix order

1. ResourceUsage / DateTime 1ms/10ms self-mutating timers (issues 1, 2).
2. ResourceUsage history buffers → ring buffer (issue 1).
3. OverviewWidget comma-operator hack (issue 4).
4. Notifications list O(n) churn (issues 7, 8).
5. SessionButton 5s `hyprctl | jq` poll (issue 5).

---

## Progress

Commits are added one fix at a time on the current branch
(`omd-omarchy-cleanup`). Each commit message follows the existing
`type(scope): summary` style.

All 17 issues fixed:

| # | Commit | Issue |
|---|--------|-------|
| 1 | c2c5993 | ResourceUsage 1ms timer + spread/shift history buffers |
| 2 | 0e8302b | DateTime 10ms uptime timer |
| 3 | 5f55608 | TimerService 10ms stopwatch string reflow |
| 4 | 209141f | OverviewWidget comma-operator modelRevision hack |
| 5 | 9610ba4 | SessionButton 5s hyprctl\|jq poll |
| 6 | 53ecf5b | Network wifi sort + nmcli debounce |
| 7 | 32a31ce | Notifications file persistence + latestTimeForApp (partial) |
| 8 | 32a31ce | Notifications onListChanged rebuild (folded into #7) |
| 9 | 240c173 | GlobalFocusGrab recursive hasActive walk |
| 10 | 9bb9861 | Hyprsunset process spawning per gamma change |
| 11 | 1d22742 | MaterialSymbol string-typed axis + variableAxes rebuild |
| 12 | 78b75b8 | OverviewSearch opacity animation defeated by visible |
| 13 | 8a7b16d | SystemInfo interval:1 run-once timer |
| 14 | c57367a | ConflictKiller echo $(...) subshell |
| 15 | b6446ec | Network connectProc restart race |
| 16 | 32a31ce | Notifications actions null-unsafe map (folded into #7) |
| 17 | 2a16089 | CircularProgress Loader for toggleable Rectangle |