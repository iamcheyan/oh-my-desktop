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
    property bool appLauncherOpen: false
    property bool barOpen: true
    property bool controlCenterOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool overviewOpen: false
    property bool overviewSearchMode: false
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
    property bool superReleaseMightTrigger: false
    property bool workspaceShowNumbers: false
    property bool barDialogOpen: false
    property string barDialogType: ""
    property bool barAudioIsSink: true

    onOverviewOpenChanged: {
        if (GlobalStates.overviewOpen) {
            GlobalStates.appLauncherOpen = false;
            GlobalStates.overviewSearchMode = false;
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

    onControlCenterOpenChanged: {
        if (GlobalStates.controlCenterOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
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
            if (root.superReleaseMightTrigger) {
                root.superReleaseMightTrigger = false
                if (!GlobalStates.overviewOpen)
                    GlobalStates.overviewOpen = true
                else if (GlobalStates.overviewSearchMode)
                    GlobalStates.overviewSearchMode = false
                else if (!WorkspaceSwitcherController.grabbed)
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
