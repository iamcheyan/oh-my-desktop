pragma Singleton
pragma ComponentBehavior: Bound

import qs
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool dismissLayerActive: !GlobalStates.screenLocked
        && GlobalStates.barPopupType !== ""
    property bool screenshotActive: GlobalStates.screenshotActive
}
