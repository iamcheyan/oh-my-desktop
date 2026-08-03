pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // The dismiss layer is shared by status popups and PopupWindow-based
    // context menus. Context menus don't set barPopupType, so basing this
    // solely on that state made click-outside silently stop working for them.
    readonly property bool dismissLayerActive: !GlobalStates.screenLocked
        && (GlobalStates.barPopupType !== "" || GlobalFocusGrab.dismissable.length > 0)
    property bool screenshotActive: GlobalStates.screenshotActive
}
