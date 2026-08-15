pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    property var lockHandler: null

    function register(handler) {
        root.lockHandler = handler;
    }

    function lock() {
        if (root.lockHandler)
            root.lockHandler();
        else
            GlobalStates.screenLocked = true;
    }
}