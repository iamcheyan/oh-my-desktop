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
    implicitWidth: trayRow.implicitWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    property alias trayModel: trayRepeater.model
    readonly property var trayItems: TrayService.trayItems ?? []

    Binding on visible {
        value: root.trayItems.length > 0
        when: !Config.options.tray.showOnlyWhenVisible
    }

    RowLayout {
        id: trayRow
        spacing: (Config.options.bar.trayIconSpacing !== undefined && Config.options.bar.trayIconSpacing !== null && Config.options.bar.trayIconSpacing > 0)
            ? Config.options.bar.trayIconSpacing
            : Config.options.bar.rightModuleSpacing


        Repeater {
            id: trayRepeater
            model: root.trayItems
            delegate: SysTrayItem {
                required property var modelData
                item: modelData
            }
        }
    }
}
