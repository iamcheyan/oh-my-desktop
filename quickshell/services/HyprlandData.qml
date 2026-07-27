pragma Singleton
pragma ComponentBehavior: Bound

import qs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    // activeWorkspace: derived from the native Quickshell.Hyprland model so it
    // updates the instant Hyprland reports a focus change — no hyprctl poll.
    // Only `.id` is consumed, which the native HyprlandWorkspace provides.
    readonly property var activeWorkspace: Hyprland.focusedWorkspace ?? null
    property var activeWindow: null
    property var monitors: []
    property int dataSerial: 0
    // Cached overview model recomputed only when the data dirty-flag
    // (dataSerial) or the overview refresh serial changes. Consumers bind to
    // this property instead of calling overviewWorkspaceEntriesGroupedByMonitor()
    // inside a binding (which QML cannot track as a dependency).
    property var overviewWorkspaceEntries: {
        // Re-evaluate when the data dirty-flag or an explicit overview
        // refresh request changes. Reading both properties here registers
        // them as binding dependencies.
        const _serial = root.dataSerial;
        const _refresh = GlobalStates.overviewRefreshSerial;
        void _serial; void _refresh;
        return root.overviewWorkspaceEntriesGroupedByMonitor() ?? [];
    }

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function workspaceHasVisibleWindows(workspaceId) {
        if (workspaceId < 1)
            return false;
        return root.hyprlandClientsForWorkspace(workspaceId).some(
            win => win.mapped && !win.hidden
        );
    }

    function workspaceGroupBase(workspaceId, groupSize) {
        const size = groupSize > 0 ? groupSize : 10;
        return Math.floor((Math.max(workspaceId, 1) - 1) / size) * size;
    }

    function isRegularWorkspace(ws) {
        if (!ws?.name)
            return true;
        return !ws.name.startsWith("special:");
    }

    function suppressedEmptyWorkspaceIds() {
        return GlobalStates.overviewSuppressedEmptyWorkspaceIds ?? [];
    }

    function pendingWorkspaceMonitorName(workspaceId) {
        const pending = GlobalStates.overviewPendingWorkspaceMonitorById ?? {};
        return pending[workspaceId] ?? "";
    }

    function workspaceMonitorName(ws) {
        if (!ws)
            return "";
        const pendingMonitor = root.pendingWorkspaceMonitorName(ws.id);
        return pendingMonitor.length > 0 ? pendingMonitor : (ws.monitor ?? "");
    }

    function pendingWorkspaceSettled(entry) {
        const wsId = entry?.id ?? -1;
        const targetMonitor = entry?.monitorName ?? "";
        if (wsId < 1 || targetMonitor.length === 0)
            return false;
        const ws = root.workspaceById[wsId];
        if (!ws || (ws.monitor ?? "") !== targetMonitor)
            return false;
        return root.windowList.some(win => win.workspace?.id === wsId && win.mapped && !win.hidden);
    }

    // Overview (工作区概览) / Overview switching (Win+Tab): only workspaces WITH windows
    // are shown, ordered by MRU (Win11 Alt+Tab Z-order). Empty workspaces are
    // never displayed — not even the active one if it has no windows. A single
    // trailing "New workspace" slot (id = highest occupied id + 1) is always
    // appended last and never participates in ordering, like GNOME/macOS.
    // This guarantees there is exactly ONE empty cell in the grid, always at
    // the very end with the highest ID, so dragging a window to it always
    // places it as the last workspace.
    function overviewWorkspaceEntriesForMonitor(monitorName, appendTrailing, reservedWorkspaceIds) {
        const includeTrailing = appendTrailing ?? true;
        const targetMonitor = monitorName ?? "";
        const reservedIds = reservedWorkspaceIds ?? {};
        const monitorData = targetMonitor
            ? root.monitors.find(mon => (mon.name ?? "") === targetMonitor)
            : null;
        const activeId = Math.max(1, Math.min(100,
            monitorData?.activeWorkspace?.id
                ?? root.activeWorkspace?.id
                ?? 1
        ));

        // Only workspaces with visible windows participate in the grid.
        // Hyprland may keep real empty workspaces around after cross-monitor
        // moves; those are handled as the single trailing slot below.
        const suppressed = root.suppressedEmptyWorkspaceIds();
        const regularWorkspaces = root.workspaces
            .filter(ws => root.isRegularWorkspace(ws))
            .filter(ws => ws.id >= 1 && ws.id <= 100)
            .filter(ws => !targetMonitor || root.workspaceMonitorName(ws) === targetMonitor)
            .filter(ws => !suppressed.includes(ws.id))
            .filter(ws => root.workspaceHasVisibleWindows(ws.id))
            .sort((a, b) => a.id - b.id);

        const seen = {};
        const withWindows = [];
        regularWorkspaces.forEach(ws => {
            if (seen[ws.id])
                return;
            seen[ws.id] = true;
            const monName = root.workspaceMonitorName(ws);
            withWindows.push({
                id: ws.id,
                monitorName: monName,
                monitorIndex: 0,
                monitorLabel: monName,
                isTrailingEmpty: false
            });
        });

        // Fallback: workspaces that have windows (per windowList) but aren't in
        // root.workspaces yet — race when getClients finishes before getWorkspaces.
        // Only add if the workspace is NOT in root.workspaces (avoid duplicates).
        // Use the window's monitor to determine which monitor group it belongs to.
        root.windowList.forEach(win => {
            if (!win?.mapped || win?.hidden) return;
            const wsId = win?.workspace?.id;
            if (wsId < 1 || wsId > 100 || seen[wsId]) return;
            if (root.workspaces.some(w => w.id === wsId)) return;
            if (!root.workspaceHasVisibleWindows(wsId)) return;
            const mon = root.monitors.find(m => m.id === win.monitor);
            const pendingMonitor = root.pendingWorkspaceMonitorName(wsId);
            const monName = pendingMonitor.length > 0 ? pendingMonitor : (mon?.name ?? "");
            if (targetMonitor && monName !== targetMonitor) return;
            seen[wsId] = true;
            withWindows.push({
                id: wsId,
                monitorName: monName,
                monitorIndex: 0,
                monitorLabel: monName,
                isTrailingEmpty: false
            });
        });

        const pendingOccupied = GlobalStates.overviewPendingOccupiedWorkspaces ?? [];
        pendingOccupied.forEach(entry => {
            const wsId = entry?.id ?? -1;
            if (wsId < 1 || wsId > 100 || seen[wsId])
                return;
            const monName = entry?.monitorName ?? root.pendingWorkspaceMonitorName(wsId);
            if (targetMonitor && monName !== targetMonitor)
                return;
            seen[wsId] = true;
            withWindows.push({
                id: wsId,
                monitorName: monName,
                monitorIndex: 0,
                monitorLabel: monName,
                isPendingOccupied: true,
                isTrailingEmpty: false
            });
        });

        // Order workspaces with windows by MRU.
        const mru = GlobalStates.overviewWorkspaceMru;
        let orderedWindows;
        if (mru && mru.length > 0) {
            const byId = {};
            withWindows.forEach(e => { byId[e.id] = e; });
            orderedWindows = [];
            const consumed = {};
            for (const id of mru) {
                if (byId[id] && !consumed[id]) {
                    orderedWindows.push(byId[id]);
                    consumed[id] = true;
                }
            }
            withWindows.forEach(e => {
                if (!consumed[e.id]) {
                    orderedWindows.push(e);
                    consumed[e.id] = true;
                }
            });
        } else {
            orderedWindows = withWindows.slice();
        }

        const ordered = orderedWindows.slice();

        // Trailing "New workspace" slot: show exactly one empty workspace at
        // the visual end of each monitor group, always with the highest ID.
        // Using maxId + 1 ensures dragging a window to the new workspace
        // always places it as the last (highest-numbered) workspace.
        let maxId = activeId - 1;
        for (const entry of orderedWindows)
            maxId = Math.max(maxId, entry.id);
        const globalSeen = {};
        root.workspaces.forEach(ws => {
            if (ws.id >= 1 && ws.id <= 100)
                globalSeen[ws.id] = true;
        });
        withWindows.forEach(e => {
            globalSeen[e.id] = true;
        });

        let trailingId = maxId + 1;
        while (trailingId <= 100 && (globalSeen[trailingId] || reservedIds[trailingId] || seen[trailingId]))
            trailingId += 1;

        if (includeTrailing && trailingId >= 1 && trailingId <= 100 && !seen[trailingId]) {
            ordered.push({
                id: trailingId,
                monitorName: targetMonitor,
                monitorIndex: 0,
                monitorLabel: targetMonitor,
                existingWorkspace: globalSeen[trailingId] ?? false,
                isTrailingEmpty: true
            });
        }

        return ordered;
    }

    function overviewWorkspaceEntriesGlobal() {
        return root.overviewWorkspaceEntriesForMonitor("", true);
    }

    function sortedOverviewMonitors() {
        return root.monitors.slice().sort((a, b) => {
            // Temporarily disabled while validating cross-monitor drag behavior:
            // keep monitor group order identical on every screen.
            // const anchorName = GlobalStates.overviewOpen
            //     ? (GlobalStates.overviewAnchorMonitorName || Hyprland.focusedMonitor?.name || "")
            //     : (Hyprland.focusedMonitor?.name ?? "");
            // const aAnchor = (a.name ?? "") === anchorName;
            // const bAnchor = (b.name ?? "") === anchorName;
            // if (aAnchor !== bAnchor)
            //     return aAnchor ? -1 : 1;
            if ((a.y ?? 0) !== (b.y ?? 0))
                return (a.y ?? 0) - (b.y ?? 0);
            return (a.x ?? 0) - (b.x ?? 0);
        });
    }

    function overviewWorkspaceEntriesGroupedByMonitor() {
        const monitors = root.sortedOverviewMonitors();
        const all = [];
        const reservedIds = {};
        for (let i = 0; i < monitors.length; ++i) {
            const mon = monitors[i];
            const entries = root.overviewWorkspaceEntriesForMonitor(mon.name, true, reservedIds);
            for (let j = 0; j < entries.length; ++j) {
                entries[j].monitorIndex = i;
                entries[j].monitorLabel = mon.description || mon.name || `Monitor ${i + 1}`;
                entries[j].monitorName = mon.name || entries[j].monitorName || "";
                entries[j].groupStart = j === 0;
                entries[j].groupEnd = j === entries.length - 1;
                all.push(entries[j]);
            }
            const trailing = entries.find(e => e.isTrailingEmpty);
            if (trailing)
                reservedIds[trailing.id] = true;
        }
        if (all.length === 0)
            return root.overviewWorkspaceEntriesGlobal();
        return all;
    }

    function workspaceDataForId(workspaceId) {
        return root.workspaceById[workspaceId] ?? null;
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    function monitorActiveWorkspaceId(monitor) {
        if (!monitor)
            return 0;
        const monitorData = root.monitors.find(m => m.id === monitor.id);
        return monitorData?.activeWorkspace?.id ?? monitor.activeWorkspace?.id ?? 0;
    }

    function focusedClientForWorkspace(workspaceId) {
        if (workspaceId < 1)
            return null;

        const active = root.activeWindow;
        if (active?.address && active.workspace?.id == workspaceId && active.mapped && !active.hidden)
            return active;

        const clients = root.hyprlandClientsForWorkspace(workspaceId)
            .filter(win => win.mapped && !win.hidden);
        if (clients.length === 0)
            return null;

        return clients.reduce((best, win) => {
            if (!best)
                return win;
            return win.focusHistoryID < best.focusHistoryID ? win : best;
        }, null);
    }

    // Internals

    function updateWindowList() {
        getClients.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
    }

    function updateActiveWindow() {
        getActiveWindow.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateWorkspaces();
        updateActiveWindow();
    }

    // Debounce the heavy re-fetch. Hyprland fires many raw events in a burst
    // (e.g. when the overview layer appears: activewindow, focusedmon,
    // movewindow, …). Without coalescing, each event spawned 6 hyprctl
    // children that raced the overview's own render + ScreencopyView capture.
    // Restarting this timer collapses a burst into a single updateAll().
    Timer {
        id: dataRefreshTimer
        interval: 60
        repeat: false
        onTriggered: root.updateAll()
    }

    function scheduleRefresh() {
        dataRefreshTimer.restart()
    }

    function markDataChanged() {
        root.dataSerial += 1;
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Layer/screencast events don't change clients/workspaces/monitors.
            if (["openlayer", "closelayer", "screencast"].includes(event.name)) return;
            // activeWindow is cheap (tiny JSON) and feeds focusedClientForWorkspace,
            // so refresh it immediately for responsiveness; coalesce the rest.
            if (["activewindow", "activewindowv2", "windowtitlev2", "focusedmon", "focusedmonv2"].includes(event.name)) {
                updateActiveWindow();
            }
            root.scheduleRefresh()
        }

        // activeWorkspace is now derived from the native focusedWorkspace model
        // (no hyprctl poll). Bump the dirty flag so the overview model
        // re-evaluates when focus moves.
        function onFocusedWorkspaceChanged() {
            root.markDataChanged()
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
                const suppressed = root.suppressedEmptyWorkspaceIds();
                if (suppressed.length > 0) {
                    GlobalStates.overviewSuppressedEmptyWorkspaceIds = suppressed.filter(wsId =>
                        !root.windowList.some(win => win.workspace?.id === wsId && win.mapped && !win.hidden)
                    );
                }
                const pendingOccupied = GlobalStates.overviewPendingOccupiedWorkspaces ?? [];
                if (pendingOccupied.length > 0) {
                    GlobalStates.overviewPendingOccupiedWorkspaces = pendingOccupied.filter(entry =>
                        !root.pendingWorkspaceSettled(entry)
                    );
                }
                root.markDataChanged();
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
                root.markDataChanged();
            }
        }
    }


    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
                const pending = GlobalStates.overviewPendingWorkspaceMonitorById ?? {};
                const nextPending = {};
                for (const wsId in pending) {
                    const ws = tempWorkspaceById[wsId];
                    if (!ws || (ws.monitor ?? "") !== pending[wsId])
                        nextPending[wsId] = pending[wsId];
                }
                GlobalStates.overviewPendingWorkspaceMonitorById = nextPending;
                const pendingOccupied = GlobalStates.overviewPendingOccupiedWorkspaces ?? [];
                if (pendingOccupied.length > 0) {
                    GlobalStates.overviewPendingOccupiedWorkspaces = pendingOccupied.filter(entry =>
                        !root.pendingWorkspaceSettled(entry)
                    );
                }
                root.markDataChanged();
            }
        }
    }

    Process {
        id: getActiveWindow
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: activeWindowCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(activeWindowCollector.text.trim());
                    root.activeWindow = data?.address ? data : null;
                } catch (e) {
                    root.activeWindow = null;
                }
                root.markDataChanged();
            }
        }
    }
}
