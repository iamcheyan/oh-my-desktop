import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    readonly property bool isCharging: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property color colIcon: Appearance.colors.colBarText
    visible: Battery.available

    implicitWidth: visible ? Config.options.bar.rightIconSlotWidth : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
        GlobalStates.barPopupType = GlobalStates.barPopupType === "battery" ? "" : "battery";
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing

        BarBatteryIcon {
            Layout.alignment: Qt.AlignVCenter
            percentage: root.percentage
            charging: root.isCharging
            color: root.colIcon
        }
    }

    BatteryHoverPopup {
        id: batteryHoverPopup
        hoverTarget: root
    }
}
