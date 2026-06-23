pragma Singleton

import qs
import qs.services
import qs.modules.common.functions
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property string appLauncherApp: `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-applauncher`

    function openAppLauncher() {
        Quickshell.execDetached([
            "qs", "-p", root.appLauncherApp, "ipc", "call", "appLauncher", "open"
        ]);
    }

    function overviewModel() {
        return HyprlandData.overviewWorkspaceEntriesGlobal();
    }

    function gridColumnsForModel(model) {
        return Math.min(Math.max(model.length, 1), Config.options.overview.columns);
    }

    function indexForWorkspace(model, wsId) {
        const idx = model.findIndex(entry => entry.id === wsId);
        return idx >= 0 ? idx : 0;
    }

    function currentWorkspaceId() {
        const monitor = Hyprland.focusedMonitor ?? Hyprland.monitors[0];
        if (!monitor)
            return HyprlandData.activeWorkspace?.id ?? 1;
        return HyprlandData.monitorActiveWorkspaceId(monitor) || HyprlandData.activeWorkspace?.id || 1;
    }

    function focusedWorkspaceId() {
        if (GlobalStates.overviewFocusedWorkspaceId > 0)
            return GlobalStates.overviewFocusedWorkspaceId;
        return root.currentWorkspaceId();
    }

    function selectWorkspace(wsId) {
        if (wsId < 1)
            return;
        GlobalStates.overviewFocusedWorkspaceId = wsId;
    }

    function dispatchFocusWorkspace(wsId) {
        if (wsId < 1)
            return;
        const ws = HyprlandData.workspaceDataForId(wsId);
        if (ws?.monitor)
            Hyprland.dispatch(`hl.dsp.focus({monitor="${ws.monitor}"})`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`);
    }

    function navigateByIndex(delta, includeTrailing) {
        const allowTrailing = includeTrailing ?? true;
        const model = allowTrailing
            ? root.overviewModel()
            : root.overviewModel().filter(entry => !entry.isTrailingEmpty);
        if (model.length === 0)
            return;

        const ws = root.focusedWorkspaceId();
        let idx = root.indexForWorkspace(model, ws);
        idx = (idx + delta + model.length) % model.length;
        root.selectWorkspace(model[idx].id);
    }

    function navigateGrid(deltaRow, deltaCol) {
        const model = root.overviewModel();
        const n = model.length;
        if (n === 0)
            return;

        const cols = root.gridColumnsForModel(model);
        if (deltaCol !== 0)
            root.navigateByIndex(deltaCol);
        else if (deltaRow !== 0)
            root.navigateByIndex(deltaRow * cols);
    }

    function focusedEntryIsTrailingEmpty() {
        const wsId = root.focusedWorkspaceId();
        if (wsId < 1)
            return false;
        const model = root.overviewModel();
        for (let i = 0; i < model.length; i++) {
            if (model[i].id === wsId)
                return !!model[i].isTrailingEmpty;
        }
        return false;
    }

    function commitSelectedWorkspace(openLauncherOnTrailing) {
        const openLauncher = openLauncherOnTrailing ?? true;
        if (root.focusedEntryIsTrailingEmpty()) {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "empty" })`);
            if (openLauncher)
                root.openAppLauncher();
            return;
        }

        if (GlobalStates.overviewFocusedWorkspaceId > 0)
            root.dispatchFocusWorkspace(GlobalStates.overviewFocusedWorkspaceId);
    }

    function resetOverviewDragState() {
        GlobalStates.overviewDraggingFromWorkspace = -1;
        GlobalStates.overviewDraggingTargetWorkspace = -1;
        GlobalStates.overviewDraggingTargetIsTrailing = false;
    }

    function beginWindowDrag(fromWorkspaceId) {
        GlobalStates.overviewDraggingFromWorkspace = fromWorkspaceId ?? -1;
    }

    function setDragTarget(workspaceId, isTrailing) {
        GlobalStates.overviewDraggingTargetWorkspace = workspaceId;
        GlobalStates.overviewDraggingTargetIsTrailing = isTrailing;
    }

    function clearDragTarget(workspaceId) {
        if (GlobalStates.overviewDraggingTargetWorkspace === workspaceId) {
            GlobalStates.overviewDraggingTargetWorkspace = -1;
            GlobalStates.overviewDraggingTargetIsTrailing = false;
        }
    }

    function commitWindowDrag(windowAddress, currentWorkspaceId, targetWorkspace, targetIsTrailing) {
        root.resetOverviewDragState();
        if (!windowAddress || targetWorkspace === -1 || targetWorkspace === currentWorkspaceId)
            return false;

        if (targetIsTrailing) {
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "empty", follow = false, window = "address:${windowAddress}" })`);
        } else {
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWorkspace}, follow = false, window = "address:${windowAddress}" })`);
        }
        return true;
    }

    function focusWindow(windowData) {
        if (!windowData?.address)
            return;
        if (windowData?.workspace?.id > 0)
            GlobalStates.promoteWorkspaceMru(windowData.workspace.id);
        Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowData.address}"})`);
    }
}
