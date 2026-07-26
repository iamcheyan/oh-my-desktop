pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common.widgets

ManagedPopupWindow {
    id: root

    signal menuClosed()

    property real menuPadding: 4

    // ContextMenuTracker integration — overrides ManagedPopupWindow.open/close
    function open() {
        if (ContextMenuTracker.activeMenu && ContextMenuTracker.activeMenu !== root)
            ContextMenuTracker.activeMenu.close();
        ContextMenuTracker.activeMenu = root;
        root.visible = true;
    }

    function close() {
        if (ContextMenuTracker.activeMenu === root)
            ContextMenuTracker.activeMenu = null;
        root.visible = false;
        root.menuClosed();
    }

    Component.onDestruction: {
        if (ContextMenuTracker.activeMenu === root)
            ContextMenuTracker.activeMenu = null;
    }

}
