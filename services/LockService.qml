pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

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