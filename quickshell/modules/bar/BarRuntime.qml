pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common.widgets
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

    // Close live bar chrome when a screenshot session starts so PopupWindow
    // menus cannot float above the selection mask (xdg_popups stack above
    // Overlay layer surfaces on Hyprland). The snapshot is already captured
    // by this point (grim runs before freeze), so menu content is frozen into
    // the image — only the live surface must go away.
    //
    // Read GlobalStates.screenshotActive directly: root.screenshotActive is a
    // binding that may still hold the previous value when this handler runs.
    function dismissForScreenshot() {
        if (ContextMenuTracker.activeMenu)
            ContextMenuTracker.activeMenu.close();
        if (GlobalStates.barPopupType !== "")
            GlobalStates.barPopupType = "";
    }

    Connections {
        target: GlobalStates
        function onScreenshotActiveChanged() {
            if (GlobalStates.screenshotActive)
                root.dismissForScreenshot();
        }
    }
}
