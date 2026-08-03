pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import qs
import Quickshell
import Quickshell.Hyprland

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars
 */ 
Singleton {
    id: root

    signal dismissed()

    // Keep these as value properties and replace their contents on mutation.
    // In-place push/splice on a QML list does not reliably notify bindings in
    // every Quickshell reload path. Both HyprlandFocusGrab and the full-screen
    // outside-click layer depend on those notifications.
    property var persistent: []
    property var dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized");
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent = root.persistent.concat([window]);
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent = root.persistent.filter(candidate => candidate !== window);
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable = root.dismissable.concat([window]);
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable = root.dismissable.filter(candidate => candidate !== window);
        }
    }

    // Returns true if any descendant of the window's contentItem currently
    // holds active focus. QML's activeFocus property already propagates from
    // descendants, so contentItem.activeFocus is equivalent to recursively
    // scanning children — without the O(depth) traversal per binding eval.
    function hasActive(contentItem) {
        return contentItem?.activeFocus ?? false;
    }

    HyprlandFocusGrab {
        id: grab
        windows: root.dismissable.length > 0 ? [...root.dismissable, ...root.persistent] : []
        active: root.dismissable.length > 0
        onCleared: () => {
            // During screenshot capture the screenshot process steals focus,
            // which would normally dismiss bar popups/menus. Suppress this so
            // grim can capture them. `screenshotActive` is set synchronously
            // via the `screenshot.begin` IPC handler before the screenshot
            // process creates its layer-shell surfaces.
            console.log("[FOCUSGRAB] onCleared fired, screenshotActive=" + GlobalStates.screenshotActive + " dismissable=" + root.dismissable.length);
            if (GlobalStates.screenshotActive)
                return;
            root.dismiss();
        }
    }

}
