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

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
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
        WorkspaceSwitcherController.queueCycle(dir);
    }

    function queueOverviewFocus() {
        WorkspaceSwitcherController.queueFocus();
    }

    function openGrabbedMode(dir) {
        WorkspaceSwitcherController.openGrabbedMode(dir);
    }

    function commitGrabbedMode() {
        WorkspaceSwitcherController.commitGrabbedMode();
    }

    function overviewNavigationActive() {
        return WorkspaceSwitcherController.navigationOpen();
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
                overviewScope.queueOverviewFocus();
        }
    }

    // Keep MRU in sync when the user switches workspaces outside of overview
    // (e.g. via Hyprland keybindings). While overview is open the MRU is frozen.
    Connections {
        target: HyprlandData
        function onActiveWorkspaceChanged() {
            if (GlobalStates.overviewOpen)
                return;
            const wsId = HyprlandData.activeWorkspace?.id ?? 0;
            if (wsId > 0)
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

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                        if (settled > 0)
                            GlobalStates.promoteWorkspaceMru(settled);
                        WorkspaceSwitcherController.reset();
                        GlobalStates.overviewFocusedWorkspaceId = -1;
                        WorkspaceNavigation.resetOverviewDragState();
                        GlobalFocusGrab.dismiss();
                    } else {
                        GlobalStates.overviewFocusedWorkspaceId = overviewScope.currentWorkspaceId();
                        if (GlobalStates.overviewWorkspaceMru.length === 0)
                            GlobalStates.promoteWorkspaceMru(overviewScope.currentWorkspaceId());
                        if (panelWindow.isFocusedOverviewWindow && !WorkspaceSwitcherController.grabbed)
                            GlobalFocusGrab.addDismissable(panelWindow);
                        overviewScope.queueOverviewFocus();
                    }
                }
            }

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    if (!WorkspaceSwitcherController.grabbed)
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
                visible: GlobalStates.overviewOpen && !WorkspaceSwitcherController.grabbed

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // Click scrim to close
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (GlobalStates.overviewSearchMode)
                            GlobalStates.overviewSearchMode = false;
                        else
                            GlobalStates.overviewOpen = false;
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
                            event.accepted = true;
                            return;
                        }
                        GlobalStates.overviewOpen = false;
                        event.accepted = true;
                        return;
                    }
                    if (WorkspaceSwitcherController.grabbed && event.key === Qt.Key_Tab) {
                        const backward = (event.modifiers & Qt.ShiftModifier) !== 0;
                        overviewScope.queueGrabbedCycle(backward ? -1 : 1);
                        event.accepted = true;
                        return;
                    }
                    if (WorkspaceSwitcherController.grabbed) {
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
                        overviewSearch.seedText = event.text;
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
                    if (WorkspaceSwitcherController.grabbed &&
                        (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta)) {
                        overviewScope.commitGrabbedMode();
                        event.accepted = true;
                    }
                }

                Connections {
                    target: GlobalStates
                    function onOverviewOpenChanged() {
                        if (GlobalStates.overviewOpen
                            && panelWindow.isFocusedOverviewWindow
                            && !WorkspaceSwitcherController.grabbed
                            && !GlobalStates.overviewSearchMode)
                            overviewKeyHandler.forceActiveFocus();
                    }
                    function onOverviewSearchModeChanged() {
                        if (!GlobalStates.overviewSearchMode
                            && panelWindow.isFocusedOverviewWindow
                            && GlobalStates.overviewOpen
                            && !WorkspaceSwitcherController.grabbed)
                            Qt.callLater(() => { overviewKeyHandler.forceActiveFocus(); });
                    }
                    function onSuperDownChanged() {
                        if (WorkspaceSwitcherController.grabbed && !GlobalStates.superDown)
                            overviewScope.commitGrabbedMode();
                    }
                }

                Connections {
                    target: overviewScope
                    function onRequestOverviewFocus() {
                        if (panelWindow.isFocusedOverviewWindow && WorkspaceSwitcherController.grabbed)
                            overviewKeyHandler.forceActiveFocus();
                    }
                }

                Connections {
                    target: WorkspaceSwitcherController
                    function onRequestFocus() {
                        overviewScope.requestOverviewFocus();
                    }
                    function onGrabbedChanged() {
                        if (panelWindow.isFocusedOverviewWindow && WorkspaceSwitcherController.grabbed)
                            overviewKeyHandler.forceActiveFocus();
                    }
                }
            }

            // ── Overview (工作区概览): large workspace grid filling the screen ──
            Item {
                id: overviewContainer
                anchors.fill: parent
                visible: GlobalStates.overviewOpen && !WorkspaceSwitcherController.grabbed

                Loader {
                    id: overviewLoader
                    anchors.fill: parent
                    active: GlobalStates.overviewOpen && !WorkspaceSwitcherController.grabbed && (Config?.options.overview.enable ?? true)
                    sourceComponent: OverviewWidget {
                        screen: panelWindow.screen
                        visible: GlobalStates.overviewOpen
                    }
                    opacity: GlobalStates.overviewSearchMode ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                OverviewSearch {
                    id: overviewSearch
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 24
                    }
                    z: 1000
                    active: GlobalStates.overviewOpen
                        && !WorkspaceSwitcherController.grabbed
                }

                // Subtle "Type to search" hint in workspace mode
                Item {
                    anchors {
                        top: parent.top
                        horizontalCenter: parent.horizontalCenter
                        topMargin: 28
                    }
                    z: 1000
                    visible: !GlobalStates.overviewSearchMode
                    opacity: !GlobalStates.overviewSearchMode ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Row {
                        spacing: 7

                        MaterialSymbol {
                            text: "search"
                            iconSize: 14
                            color: "#8f98a8"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: Translation.tr("Type to search")
                            color: "#8f98a8"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── Switcher (快速切换): compact centered preview ──
            Loader {
                id: switcherLoader
                anchors.centerIn: parent
                active: GlobalStates.overviewOpen && WorkspaceSwitcherController.grabbed
                sourceComponent: Item {
                    width: switcherWidget.implicitWidth
                    height: switcherWidget.implicitHeight
                    OverviewWidget {
                        id: switcherWidget
                        screen: panelWindow.screen
                        visible: true
                        compactMode: true
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
        function overviewNext() {
            overviewScope.openGrabbedMode(1);
        }
        function overviewPrev() {
            overviewScope.openGrabbedMode(-1);
        }
        function overviewCommit() {
            overviewScope.commitGrabbedMode();
        }
    }

    IpcHandler {
        target: "switcher"

        function next() {
            WorkspaceSwitcherController.openGrabbedMode(1);
        }
        function prev() {
            WorkspaceSwitcherController.openGrabbedMode(-1);
        }
        function commit() {
            WorkspaceSwitcherController.commitGrabbedMode();
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
