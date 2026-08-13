import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// System tray: shows all SNI items directly in the bar, no overflow split.
Item {
    id: root

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    // The tray is a core product-floor widget. Keep its slot mounted even
    // while the SNI model is empty or still connecting to D-Bus.
    visible: true
    width: trayRow.implicitWidth
    implicitWidth: trayRow.implicitWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    property alias trayModel: trayRepeater.model
    readonly property var trayItems: TrayService.trayItems ?? []
    readonly property var visibleTrayItems: {
        var items = root.trayItems;
        var hidden = Config.options.tray.hiddenAppIds;
        if (!hidden || hidden.length === 0) return items;
        var result = [];
        for (var i = 0; i < items.length; i++) {
            var skip = false;
            for (var h = 0; h < hidden.length; h++) {
                if (hidden[h] === items[i].id) {
                    skip = true;
                    break;
                }
            }
            if (!skip) result.push(items[i]);
        }
        return result;
    }

    RowLayout {
        id: trayRow
        spacing: {
            // Schema defines tray.trayIconSpacing (not bar.*) — the old read
            // was always undefined and fell back to rightModuleSpacing.
            const s = Config.options.tray?.trayIconSpacing;
            return (s !== undefined && s !== null && s > 0) ? s : Config.options.bar.rightModuleSpacing;
        }


        Repeater {
            id: trayRepeater
            model: root.visibleTrayItems
            delegate: SysTrayItem {
                required property var modelData
                item: modelData
            }
        }
    }
}
