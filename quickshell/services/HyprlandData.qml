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
    property var activeWorkspace: null
    property var activeWindow: null
    property var monitors: []
    property var layers: ({})

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

    // Global overview: workspaces with windows, ordered by MRU (most-recently-used)
    // like Win11 Alt+Tab Z-order, plus one trailing empty slot.
    function overviewWorkspaceEntriesGlobal() {
        const regularWorkspaces = root.workspaces
            .filter(ws => root.isRegularWorkspace(ws) && ws.windows > 0)
            .sort((a, b) => a.id - b.id);

        const seen = {};
        let model = regularWorkspaces.reduce((entries, ws) => {
            if (ws.id < 1 || ws.id > 100 || seen[ws.id])
                return entries;
            seen[ws.id] = true;
            entries.push({
                id: ws.id,
                monitorName: ws.monitor ?? "",
                isTrailingEmpty: false
            });
            return entries;
        }, []);

        if (model.length === 0) {
            const activeId = root.activeWorkspace?.id ?? 1;
            model.push({
                id: Math.max(1, Math.min(100, activeId)),
                monitorName: root.activeWorkspace?.monitor ?? "",
                isTrailingEmpty: false
            });
        }

        let maxId = 0;
        for (const entry of model)
            maxId = Math.max(maxId, entry.id);

        const trailingId = maxId + 1;
        if (trailingId <= 100 && !seen[trailingId]) {
            model.push({
                id: trailingId,
                monitorName: "",
                isTrailingEmpty: true
            });
        }

        // Reorder by MRU: workspaces in GlobalStates.overviewWorkspaceMru come first
        // (in MRU order), remaining workspaces keep id-ascending order. The trailing
        // empty slot always stays at the end.
        const mru = GlobalStates.overviewWorkspaceMru;
        if (mru && mru.length > 0) {
            const trailing = model.filter(e => e.isTrailingEmpty);
            const nonTrailing = model.filter(e => !e.isTrailingEmpty);
            const byId = {};
            nonTrailing.forEach(e => { byId[e.id] = e; });

            const ordered = [];
            const consumed = {};
            for (const id of mru) {
                if (byId[id] && !consumed[id]) {
                    ordered.push(byId[id]);
                    consumed[id] = true;
                }
            }
            // Append any workspaces not in MRU (e.g. newly created) in id order
            nonTrailing.forEach(e => {
                if (!consumed[e.id]) {
                    ordered.push(e);
                    consumed[e.id] = true;
                }
            });
            model = ordered.concat(trailing);
        }

        return model;
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

    function updateLayers() {
        getLayers.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateActiveWindow() {
        getActiveWindow.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
        updateActiveWindow();
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
            // console.log("Hyprland raw event:", event.name);
            if (["openlayer", "closelayer", "screencast"].includes(event.name)) return;
            if (["activewindow", "activewindowv2", "windowtitlev2", "focusedmon", "focusedmonv2"].includes(event.name)) {
                updateActiveWindow();
            }
            updateAll()
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
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
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
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
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
            }
        }
    }
}
