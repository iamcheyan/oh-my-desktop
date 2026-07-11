import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope

    property string lockedScreenName: ""
    property string overviewFilterQuery: ""
    property var focusedScreen: Quickshell.screens.find(s => s.name === (overviewScope.lockedScreenName || Hyprland.focusedMonitor?.name))
        ?? Quickshell.screens[0]
        ?? null

    signal requestOverviewFocus()

    function overviewModel() {
        return WorkspaceNavigation.overviewModel();
    }

    function overviewGridColumnsForModel(model) {
        return WorkspaceNavigation.gridColumnsForModel(model);
    }

    function overviewIndexForWorkspace(model, wsId) {
        return WorkspaceNavigation.indexForWorkspace(model, wsId);
    }

    function overviewFocusedWorkspaceId() {
        return WorkspaceNavigation.focusedWorkspaceId();
    }

    function dispatchFocusWorkspace(wsId) {
        WorkspaceNavigation.dispatchFocusWorkspace(wsId);
    }

    function selectOverviewWorkspace(wsId) {
        WorkspaceNavigation.selectWorkspace(wsId);
    }

    function navigateOverviewByIndex(delta) {
        WorkspaceNavigation.navigateByIndex(delta);
    }

    function focusedEntryIsTrailingEmpty() {
        return WorkspaceNavigation.focusedEntryIsTrailingEmpty();
    }

    function navigateOverviewGrid(deltaRow, deltaCol) {
        WorkspaceNavigation.navigateGrid(deltaRow, deltaCol);
    }

    function cycleOverviewWorkspace(dir) {
        overviewScope.navigateOverviewByIndex(dir);
    }

    function queueGrabbedCycle(dir) {
        OverviewSwitchingController.queueCycle(dir);
    }

    function queueOverviewFocus() {
        OverviewSwitchingController.queueFocus();
    }

    function openGrabbedMode(dir) {
        OverviewSwitchingController.openGrabbedMode(dir);
    }

    function commitGrabbedMode() {
        OverviewSwitchingController.commitGrabbedMode();
    }

    function overviewNavigationActive() {
        return OverviewSwitchingController.navigationOpen();
    }

    function handleOverviewNavigationKey(event) {
        if (!overviewScope.overviewNavigationActive())
            return;

        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            overviewScope.navigateOverviewGrid(0, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            overviewScope.navigateOverviewGrid(0, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            overviewScope.navigateOverviewGrid(-1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            overviewScope.navigateOverviewGrid(1, 0);
            event.accepted = true;
        }
    }

    function isFocusedScreen(screen) {
        return screen?.name === overviewScope.focusedScreen?.name;
    }

    function currentWorkspaceId() {
        return WorkspaceNavigation.currentWorkspaceId();
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (GlobalStates.overviewOpen)
                return;
            overviewScope.queueOverviewFocus();
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                const anchor = Hyprland.focusedMonitor?.name ?? "";
                overviewScope.lockedScreenName = anchor;
                GlobalStates.overviewAnchorMonitorName = anchor;
            } else {
                overviewScope.lockedScreenName = "";
                GlobalStates.overviewAnchorMonitorName = "";
                GlobalStates.overviewPendingWorkspaceMonitorById = ({});
                GlobalStates.overviewPendingOccupiedWorkspaces = [];
            }
        }
    }

    // Keep MRU in sync when the user switches workspaces outside of overview
    // (e.g. via Hyprland keybindings). While overview is open the MRU is frozen.
    // Empty workspaces (incl. the trailing "New workspace" slot) are never
    // promoted — only workspaces with windows participate in MRU ordering.
    Connections {
        target: HyprlandData
        function onActiveWorkspaceChanged() {
            if (GlobalStates.overviewOpen)
                return;
            const wsId = HyprlandData.activeWorkspace?.id ?? 0;
            if (wsId > 0 && HyprlandData.workspaceHasVisibleWindows(wsId))
                GlobalStates.promoteWorkspaceMru(wsId);
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: overviewPanelLoader
            required property ShellScreen modelData
            active: true

            component: PanelWindow {
            id: panelWindow
            screen: overviewPanelLoader.modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            readonly property bool isFocusedOverviewWindow: overviewScope.isFocusedScreen(panelWindow.screen)
            visible: GlobalStates.overviewOpen
                && (!OverviewSwitchingController.grabbed || panelWindow.isFocusedOverviewWindow)

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: panelWindow.isFocusedOverviewWindow
                ? (GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)
                : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (!GlobalStates.overviewOpen) {
                        const settled = GlobalStates.overviewFocusedWorkspaceId > 0
                            ? GlobalStates.overviewFocusedWorkspaceId
                            : overviewScope.currentWorkspaceId();
                        if (settled > 0 && HyprlandData.workspaceHasVisibleWindows(settled))
                            GlobalStates.promoteWorkspaceMru(settled);
                        OverviewSwitchingController.reset();
                        GlobalStates.overviewFocusedWorkspaceId = -1;
                        WorkspaceNavigation.resetOverviewDragState();
                        GlobalFocusGrab.dismiss();
                    } else {
                        GlobalStates.overviewFocusedWorkspaceId = overviewScope.currentWorkspaceId();
                        if (GlobalStates.overviewWorkspaceMru.length === 0)
                            GlobalStates.promoteWorkspaceMru(overviewScope.currentWorkspaceId());
                        if (!OverviewSwitchingController.grabbed || panelWindow.isFocusedOverviewWindow)
                            GlobalFocusGrab.addDismissable(panelWindow);
                        overviewScope.queueOverviewFocus();
                    }
                }
            }

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    if (!OverviewSwitchingController.grabbed)
                        GlobalStates.overviewOpen = false;
                }
            }

            implicitWidth: panelWindow.width
            implicitHeight: panelWindow.height

            // ── Overview (工作区概览): full-screen scrim + large grid ──
            Rectangle {
                id: scrim
                anchors.fill: parent
                color: ColorUtils.transparentize("#0f0f14", 0.25)
                visible: GlobalStates.overviewOpen

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // Click scrim to close
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (GlobalStates.overviewSearchMode) {
                            GlobalStates.overviewSearchMode = false;
                            overviewScope.overviewFilterQuery = "";
                        } else {
                            GlobalStates.overviewOpen = false;
                        }
                    }
                }
            }

            Item {
                id: overviewKeyHandler
                anchors.fill: parent
                z: 999
                focus: panelWindow.isFocusedOverviewWindow

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (GlobalStates.overviewSearchMode) {
                            GlobalStates.overviewSearchMode = false;
                            overviewScope.overviewFilterQuery = "";
                            event.accepted = true;
                            return;
                        }
                        GlobalStates.overviewOpen = false;
                        event.accepted = true;
                        return;
                    }
                    if (OverviewSwitchingController.grabbed && event.key === Qt.Key_Tab) {
                        const backward = (event.modifiers & Qt.ShiftModifier) !== 0;
                        overviewScope.queueGrabbedCycle(backward ? -1 : 1);
                        event.accepted = true;
                        return;
                    }
                    if (OverviewSwitchingController.grabbed) {
                        overviewScope.handleOverviewNavigationKey(event);
                        return;
                    }
                    if (GlobalStates.overviewSearchMode) {
                        if (event.key === Qt.Key_Backspace) {
                            overviewScope.overviewFilterQuery = overviewScope.overviewFilterQuery.slice(0, -1);
                            if (overviewScope.overviewFilterQuery.length === 0)
                                GlobalStates.overviewSearchMode = false;
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Delete) {
                            overviewScope.overviewFilterQuery = "";
                            GlobalStates.overviewSearchMode = false;
                            event.accepted = true;
                            return;
                        }
                        if (event.text.length > 0
                            && !(event.modifiers & Qt.ControlModifier)
                            && !(event.modifiers & Qt.AltModifier)
                            && !(event.modifiers & Qt.MetaModifier)
                            && event.key !== Qt.Key_Tab
                            && event.key !== Qt.Key_Space) {
                            overviewScope.overviewFilterQuery += event.text;
                            event.accepted = true;
                            return;
                        }
                        overviewScope.handleOverviewNavigationKey(event);
                        return;
                    }
                    // In workspace mode, any printable character enters search mode
                    if (!GlobalStates.overviewSearchMode
                        && event.text.length > 0
                        && !(event.modifiers & Qt.ControlModifier)
                        && !(event.modifiers & Qt.AltModifier)
                        && !(event.modifiers & Qt.MetaModifier)
                        && event.key !== Qt.Key_Backspace
                        && event.key !== Qt.Key_Delete
                        && event.key !== Qt.Key_Tab
                        && event.key !== Qt.Key_Space) {
                        overviewScope.overviewFilterQuery = event.text;
                        GlobalStates.overviewSearchMode = true;
                        event.accepted = true;
                        return;
                    }
                    // Arrow keys navigate workspaces in workspace mode
                    if (!GlobalStates.overviewSearchMode) {
                        overviewScope.handleOverviewNavigationKey(event);
                    }
                }

                Keys.onReleased: event => {
                    if (OverviewSwitchingController.grabbed &&
                        (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta)) {
                        overviewScope.commitGrabbedMode();
                        event.accepted = true;
                    }
                }

                Connections {
                    target: GlobalStates
                    function onOverviewOpenChanged() {
                        if (!GlobalStates.overviewOpen) {
                            GlobalStates.overviewSearchMode = false;
                            overviewScope.overviewFilterQuery = "";
                        }
                        if (GlobalStates.overviewOpen
                            && panelWindow.isFocusedOverviewWindow
                            && !OverviewSwitchingController.grabbed
                            && !GlobalStates.overviewSearchMode)
                            overviewKeyHandler.forceActiveFocus();
                    }
                    function onOverviewSearchModeChanged() {
                        if (!GlobalStates.overviewSearchMode)
                            overviewScope.overviewFilterQuery = "";
                        if (!GlobalStates.overviewSearchMode
                            && panelWindow.isFocusedOverviewWindow
                            && GlobalStates.overviewOpen
                            && !OverviewSwitchingController.grabbed)
                            Qt.callLater(() => { overviewKeyHandler.forceActiveFocus(); });
                    }
                    function onSuperDownChanged() {
                        if (OverviewSwitchingController.grabbed && !GlobalStates.superDown)
                            overviewScope.commitGrabbedMode();
                    }
                }

                Connections {
                    target: overviewScope
                    function onRequestOverviewFocus() {
                        if (panelWindow.isFocusedOverviewWindow && OverviewSwitchingController.grabbed)
                            overviewKeyHandler.forceActiveFocus();
                    }
                }

                Connections {
                    target: OverviewSwitchingController
                    function onRequestFocus() {
                        overviewScope.requestOverviewFocus();
                    }
                    function onGrabbedChanged() {
                        if (panelWindow.isFocusedOverviewWindow && OverviewSwitchingController.grabbed)
                            overviewKeyHandler.forceActiveFocus();
                    }
                }
            }

            // ── Overview (工作区概览): large workspace grid filling the screen ──
            Item {
                id: overviewContainer
                anchors.fill: parent
                visible: GlobalStates.overviewOpen

                Loader {
                    id: overviewLoader
                    anchors.fill: parent
                    // Keep the Loader always active so ScreencopyViews stay
                    // instantiated and hold the latest captured frame. This
                    // eliminates the "black box → thumbnail" pop that happens
                    // when the Loader is gated on overviewOpen: the
                    // ScreencopyView only starts capturing on open, so the
                    // first frame isn't ready until a frame or two later.
                    // With live:false (performance mode) the cost of keeping
                    // the views around is negligible (one snapshot each).
                    active: Config?.options.overview.enable ?? true
                    sourceComponent: OverviewWidget {
                        screen: panelWindow.screen
                        searchQuery: overviewScope.overviewFilterQuery
                        visible: GlobalStates.overviewOpen
                    }
                }


            }

        }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function superDown() {
            GlobalStates.superDown = true;
            GlobalStates.superReleaseMightTrigger = true;
        }
        function superUp() {
            GlobalStates.superDown = false;
            if (GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = false;
                if (!GlobalStates.overviewOpen)
                    GlobalStates.overviewOpen = true;
                else if (GlobalStates.overviewSearchMode) {
                    GlobalStates.overviewSearchMode = false;
                    overviewScope.overviewFilterQuery = "";
                } else if (!OverviewSwitchingController.grabbed)
                    GlobalStates.overviewOpen = false;
            }
        }
        function overviewNext() {
            GlobalStates.superReleaseMightTrigger = false;
            overviewScope.openGrabbedMode(1);
        }
        function overviewPrev() {
            GlobalStates.superReleaseMightTrigger = false;
            overviewScope.openGrabbedMode(-1);
        }
        function overviewCommit() {
            GlobalStates.superReleaseMightTrigger = false;
            overviewScope.commitGrabbedMode();
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    property real lastWheelShortcut: 0

    GlobalShortcut {
        name: "overviewNext"
        description: "Workspace overview: cycle next (Win+Tab)"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            const now = Date.now();
            if (now - overviewScope.lastWheelShortcut < 150) return;
            overviewScope.lastWheelShortcut = now;
            overviewScope.openGrabbedMode(1);
        }
    }
    GlobalShortcut {
        name: "overviewPrev"
        description: "Workspace overview: cycle prev (Win+Shift+Tab)"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            const now = Date.now();
            if (now - overviewScope.lastWheelShortcut < 150) return;
            overviewScope.lastWheelShortcut = now;
            overviewScope.openGrabbedMode(-1);
        }
    }
    GlobalShortcut {
        name: "overviewCommit"
        description: "Workspace overview: commit on Win release"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            overviewScope.commitGrabbedMode()
        }
    }
}
