pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool grabbed: false
    property bool focusQueued: false
    property bool cycleQueued: false
    property int cycleDelta: 0

    signal requestFocus()

    function navigationOpen() {
        return GlobalStates.overviewOpen;
    }

    function queueCycle(dir) {
        root.cycleDelta += dir;
        if (root.cycleQueued)
            return;

        root.cycleQueued = true;
        Qt.callLater(() => {
            const delta = root.cycleDelta;
            root.cycleDelta = 0;
            root.cycleQueued = false;

            if (!GlobalStates.overviewOpen || !root.grabbed || delta === 0)
                return;

            WorkspaceNavigation.navigateByIndex(delta);
        });
    }

    function queueFocus() {
        if (root.focusQueued)
            return;

        root.focusQueued = true;
        Qt.callLater(() => {
            root.focusQueued = false;
            if (GlobalStates.overviewOpen)
                root.requestFocus();
        });
    }

    function openGrabbedMode(dir) {
        if (GlobalStates.overviewOpen && root.grabbed) {
            root.queueCycle(dir);
        } else {
            root.grabbed = true;
            GlobalStates.overviewOpen = true;
            root.queueCycle(dir);
            root.queueFocus();
        }
    }

    function commitGrabbedMode() {
        WorkspaceNavigation.commitSelectedWorkspace(true);
        root.grabbed = false;
        GlobalStates.overviewOpen = false;
    }

    function reset() {
        root.grabbed = false;
        root.focusQueued = false;
        root.cycleQueued = false;
        root.cycleDelta = 0;
    }
}
