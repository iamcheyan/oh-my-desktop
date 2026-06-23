import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool appLauncherOpen: false
    property bool barOpen: true
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool overviewOpen: false
    property int overviewFocusedWorkspaceId: -1
    property var overviewWorkspaceMru: []
    property int overviewDraggingFromWorkspace: -1
    property int overviewDraggingTargetWorkspace: -1
    property bool overviewDraggingTargetIsTrailing: false
    property bool regionSelectorOpen: false
    property bool scheduleOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool workspaceShowNumbers: false
    property bool barDialogOpen: false
    property string barDialogType: ""

    onOverviewOpenChanged: {
        if (GlobalStates.overviewOpen) {
            GlobalStates.appLauncherOpen = false;
        }
    }

    // MRU (Most Recently Used) workspace list, mirroring Win11 Alt+Tab Z-order.
    // Promote `wsId` to the front of the list (Win11: switched window → top of Z-order).
    function promoteWorkspaceMru(wsId) {
        if (wsId < 1)
            return;
        const next = GlobalStates.overviewWorkspaceMru.filter(id => id !== wsId);
        next.unshift(wsId);
        GlobalStates.overviewWorkspaceMru = next;
    }

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}
