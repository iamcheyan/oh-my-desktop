import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property bool clipboardOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property real osdBrightnessValue: -1
    property bool overviewOpen: false
    property string overviewAnchorMonitorName: ""
    property bool overviewSearchMode: false
    property int overviewFocusedWorkspaceId: -1
    property var overviewWorkspaceMru: []
    property int overviewDraggingFromWorkspace: -1
    property int overviewDraggingTargetWorkspace: -1
    property bool overviewDraggingTargetIsTrailing: false
    property var overviewSuppressedEmptyWorkspaceIds: []
    property var overviewPendingWorkspaceMonitorById: ({})
    property var overviewPendingOccupiedWorkspaces: []
    property int overviewRefreshSerial: 0
    property bool regionSelectorOpen: false
    property bool screenshotActive: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool superDown: false
    property bool superReleaseMightTrigger: false
    property string barPopupType: ""
    // Ephemeral popups (e.g. volume OSD) auto-close; pinned ones stay until dismissed.
    property bool barPopupEphemeral: false
    property real barPopupDismissedAt: 0
    property bool sessionConfirmOpen: false
    property string sessionConfirmAction: ""
    property string sessionConfirmLabel: ""

    function requestSessionConfirm(action, label) {
        GlobalStates.barPopupType = "";
        GlobalStates.sessionConfirmAction = action;
        GlobalStates.sessionConfirmLabel = label;
        GlobalStates.sessionConfirmOpen = true;
    }

    function closeSessionConfirm() {
        GlobalStates.sessionConfirmOpen = false;
        GlobalStates.sessionConfirmAction = "";
        GlobalStates.sessionConfirmLabel = "";
    }

    onOverviewOpenChanged: {
        if (GlobalStates.overviewOpen) {
            GlobalStates.clipboardOpen = false;
            GlobalStates.overviewSearchMode = false;
        }
    }

    // MRU (Most Recently Used) workspace list, mirroring Win11 Alt+Tab Z-order.
    // Promote `wsId` to the front of the list (Win11: switched window → top of Z-order).
    // The trailing "New workspace" slot never enters MRU — it is always last.
    function promoteWorkspaceMru(wsId) {
        if (wsId < 1)
            return;
        const next = GlobalStates.overviewWorkspaceMru.filter(id => id !== wsId);
        next.unshift(wsId);
        GlobalStates.overviewWorkspaceMru = next;
    }

    function refreshOverviewModel() {
        GlobalStates.overviewRefreshSerial += 1;
    }

    function suppressEmptyWorkspace(wsId) {
        if (wsId < 1)
            return;
        const current = GlobalStates.overviewSuppressedEmptyWorkspaceIds ?? [];
        if (current.includes(wsId))
            return;
        const next = current.slice();
        next.push(wsId);
        GlobalStates.overviewSuppressedEmptyWorkspaceIds = next;
    }

    function unsuppressWorkspace(wsId) {
        if (wsId < 1)
            return;
        GlobalStates.overviewSuppressedEmptyWorkspaceIds =
            (GlobalStates.overviewSuppressedEmptyWorkspaceIds ?? []).filter(id => id !== wsId);
    }

    onBarPopupTypeChanged: {
        if (!GlobalStates.barPopupType)
            GlobalStates.barPopupEphemeral = false;
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
            root.superReleaseMightTrigger = true
        }
        onReleased: {
            root.superDown = false
            if (OverviewSwitchingController.grabbed) {
                root.superReleaseMightTrigger = false
                OverviewSwitchingController.commitGrabbedMode()
                return
            }
            if (root.superReleaseMightTrigger) {
                root.superReleaseMightTrigger = false
                if (!GlobalStates.overviewOpen)
                    GlobalStates.overviewOpen = true
                else if (GlobalStates.overviewSearchMode)
                    GlobalStates.overviewSearchMode = false
                else if (!OverviewSwitchingController.grabbed)
                    GlobalStates.overviewOpen = false
            }
        }
    }

    GlobalShortcut {
        name: "superInterrupt"
        description: "Interrupt Super-alone overview toggle"

        onPressed: {
            root.superReleaseMightTrigger = false
        }
    }
}
