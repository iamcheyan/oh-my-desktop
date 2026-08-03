pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common.widgets

ManagedPopupWindow {
    id: root

    // Keep the keyboard grab local to the open menu so its mnemonic keys work
    // even when the bar itself does not own compositor focus. Outside clicks
    // are handled independently by BarDismissLayer.
    grabFocus: root.visible

    signal menuClosed()

    property real menuPadding: 4
    // Menus use single-letter mnemonics while open. An item may provide an
    // explicit shortcutKey; otherwise the first unused alphabetic character
    // in labelText is assigned automatically.
    property var _shortcutItems: []
    property var _registeredItems: []

    function registerMenuItem(item) {
        if (!item || root._registeredItems.includes(item))
            return;
        root._registeredItems = root._registeredItems.concat([item]);
        if (root.visible)
            Qt.callLater(root.refreshShortcuts);
    }

    function collectShortcutItems(object, result) {
        if (!object)
            return;
        // ContextMenuItem exposes both labelText and shortcutKey. Looking for
        // those properties keeps separators, layout containers and shadows
        // out of the activation table without coupling this base widget to a
        // concrete QML type name.
        if (object.labelText !== undefined && object.shortcutKey !== undefined)
            result.push(object);
        for (const child of object.children ?? [])
            root.collectShortcutItems(child, result);
        // Items supplied through a default property such as
        // `ColumnLayout.data` may be present in data without appearing in the
        // visual children list. Extension menus commonly use this path.
        for (const datum of object.data ?? []) {
            if (datum !== object)
                root.collectShortcutItems(datum, result);
        }
    }

    function refreshShortcuts() {
        const items = root._registeredItems.slice();
        root.collectShortcutItems(root, items);
        const uniqueItems = [];
        for (const item of items) {
            if (item && !uniqueItems.includes(item))
                uniqueItems.push(item);
        }
        const explicitItems = [];
        const owners = ({ });
        const automatic = [];
        for (const item of uniqueItems) {
            if (!item.visible || !item.enabled)
                continue;
            let key = String(item.shortcutKey ?? "").trim().toUpperCase();
            if (key.length > 1)
                key = key.slice(0, 1);
            if (/^[A-Z]$/.test(key) && !owners[key]) {
                owners[key] = item;
                explicitItems.push(item);
            } else {
                automatic.push(item);
            }
        }

        const candidates = item => {
            const result = [];
            const seen = ({ });
            for (const candidate of String(item.labelText ?? "").toUpperCase()) {
                if (/^[A-Z]$/.test(candidate) && !seen[candidate]) {
                    seen[candidate] = true;
                    result.push(candidate);
                }
            }
            return result;
        };
        const candidateByItem = item => candidates(item);
        // Bipartite matching lets a later row claim its first letter by
        // moving an earlier automatic row to that row's next available
        // letter. Explicit reservations are never displaced.
        const assign = (item, visited) => {
            for (const key of candidateByItem(item)) {
                if (visited[key])
                    continue;
                visited[key] = true;
                const current = owners[key];
                if (!current || (!explicitItems.includes(current) && assign(current, visited))) {
                    owners[key] = item;
                    return true;
                }
            }
            return false;
        };
        for (const item of automatic)
            assign(item, ({ }));

        const assigned = [];
        for (const key of Object.keys(owners)) {
            const item = owners[key];
            item.assignedShortcutKey = key;
            assigned.push(item);
        }
        for (const item of automatic) {
            if (!assigned.includes(item))
                item.assignedShortcutKey = "";
        }
        root._shortcutItems = assigned;
    }

    function activateShortcut(key) {
        const normalized = String(key ?? "").toUpperCase();
        for (const item of root._shortcutItems ?? []) {
            if (item.visible && item.enabled && item.effectiveShortcutKey === normalized) {
                item.clicked();
                return true;
            }
        }
        return false;
    }

    function keyText(event) {
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return String.fromCharCode("A".charCodeAt(0) + event.key - Qt.Key_A);
        return event.text ?? "";
    }

    // ContextMenuTracker integration — overrides ManagedPopupWindow.open/close
    function open() {
        if (ContextMenuTracker.activeMenu && ContextMenuTracker.activeMenu !== root)
            ContextMenuTracker.activeMenu.close();
        ContextMenuTracker.activeMenu = root;
        root.visible = true;
        Qt.callLater(() => {
            root.refreshShortcuts();
            root.forceActiveFocus();
        });
    }

    function close() {
        if (ContextMenuTracker.activeMenu === root)
            ContextMenuTracker.activeMenu = null;
        root.visible = false;
        root.menuClosed();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
            return;
        }
        if (event.modifiers !== Qt.NoModifier)
            return;
        if (root.activateShortcut(root.keyText(event)))
            event.accepted = true;
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.refreshShortcuts);
    }

    Component.onDestruction: {
        if (ContextMenuTracker.activeMenu === root)
            ContextMenuTracker.activeMenu = null;
    }

}
