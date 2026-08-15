pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    /// Stable reference to the SystemTray model (pointer never changes)
    readonly property var trayModel: SystemTray.items

    /// Snapshot of the ObjectModel contents. ObjectModel.values is not a
    /// reliable QML binding source across Quickshell releases, so keep a
    /// normal JS array that is replaced on every refresh.
    property var allItems: []

    /// Polling keeps the derived list in sync across Quickshell versions.
    /// SystemTray.items is an ObjectModel whose mutation signal names have
    /// changed between releases, so binding to guessed signals is brittle.
    /// The tray is tiny and this avoids losing newly registered SNI items.
    Timer {
        id: _pollTimer
        interval: 500
        running: true
        repeat: true
        onTriggered: root.refreshItems()
    }

    function refreshItems() {
        const values = root.trayModel ? root.trayModel.values : [];
        const next = [];
        if (values) {
            for (let i = 0; i < values.length; i++) {
                if (values[i]) next.push(values[i]);
            }
        }
        // Assign only when the snapshot actually changed. Replacing allItems
        // with a fresh array re-evaluates every derived list and repaints
        // the bar's tray region twice a second even when nothing moved.
        const cur = root.allItems;
        if (cur.length === next.length && next.every((v, i) => v === cur[i]))
            return;
        root.allItems = next;
    }

    Component.onCompleted: {
        // The watcher may finish connecting after the singleton is created.
        // The timer continues to pick up late registrations.
        root.refreshItems();
    }

    function isPassiveItem(item) {
        if (!item) return false;
        return item.status === "Passive" || item.status === 0 || item.status === SystemTrayItem.Passive;
    }

    property bool smartTray: Config.options.tray.filterPassive ?? false
    property list<var> itemsInUserList: root.allItems.filter(i => (Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || !root.isPassiveItem(i))))
    property list<var> itemsNotInUserList: root.allItems.filter(i => (!Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || !root.isPassiveItem(i))))

    property bool invertPins: Config.options.tray.invertPinnedItems
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    /// Combined list of all tray items (pinned + unpinned), as expected by SysTray.qml
    property list<var> trayItems: pinnedItems.concat(unpinnedItems)

    function getTooltipForItem(item) {
        var result = item.tooltipTitle.length > 0 ? item.tooltipTitle
                : (item.title.length > 0 ? item.title : item.id);
        if (item.tooltipDescription.length > 0) result += " • " + item.tooltipDescription;
        if (Config.options.tray.showItemId) result += "\n[" + item.id + "]";
        return result;
    }

    // Pinning
    function pin(itemId) {
        var pins = Config.options.tray.pinnedItems;
        if (pins.includes(itemId)) return;
        Config.options.tray.pinnedItems.push(itemId);
    }
    function unpin(itemId) {
        Config.options.tray.pinnedItems = Config.options.tray.pinnedItems.filter(id => id !== itemId);
    }
    function isPinned(itemId) {
        for (var i = 0; i < root.pinnedItems.length; i++) {
            if (root.pinnedItems[i].id === itemId)
                return true;
        }
        return false;
    }

    function togglePin(itemId) {
        var pins = Config.options.tray.pinnedItems;
        if (pins.includes(itemId)) {
            unpin(itemId)
        } else {
            pin(itemId)
        }
    }

}
