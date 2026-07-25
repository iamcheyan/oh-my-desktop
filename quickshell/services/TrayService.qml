pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    /// Stable reference to the SystemTray model (pointer never changes)
    readonly property var trayModel: SystemTray.items

    /// Refresh trigger — toggled by mutation signals to force re-evaluation
    /// of bindings that depend on trayModel.values (which has no notify signal).
    property bool _refreshTrigger: false

    Component.onCompleted: {
        if (trayModel && typeof trayModel.objectAdded === "object" && typeof trayModel.objectAdded.connect === "function") {
            trayModel.objectAdded.connect(() => _refreshTrigger = !_refreshTrigger);
            trayModel.objectRemoved.connect(() => _refreshTrigger = !_refreshTrigger);
        }
        if (typeof SystemTray.itemRegistered === "object" && typeof SystemTray.itemRegistered.connect === "function") {
            SystemTray.itemRegistered.connect(() => _refreshTrigger = !_refreshTrigger);
            SystemTray.itemUnregistered.connect(() => _refreshTrigger = !_refreshTrigger);
        }
    }


    /// Polling fallback — ensures reactivity even if signal connections fail
    Timer {
        id: _pollTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: _refreshTrigger = !_refreshTrigger
    }

    /// All current tray items, reactively re-read on model mutations
    readonly property var allItems: {
        _refreshTrigger;
        return trayModel.values ?? [];
    }

    property bool smartTray: Config.options.tray.filterPassive
    property list<var> itemsInUserList: root.allItems.filter(i => (Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))
    property list<var> itemsNotInUserList: root.allItems.filter(i => (!Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))

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
