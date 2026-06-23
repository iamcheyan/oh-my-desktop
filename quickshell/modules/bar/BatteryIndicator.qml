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
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property color colIcon: Appearance.colors.colBarText

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    cursorShape: Qt.PointingHandCursor
    onClicked: {
        if (GlobalStates.barDialogOpen && GlobalStates.barDialogType === "battery") {
            GlobalStates.barDialogOpen = false;
            GlobalStates.barDialogType = "";
        } else {
            GlobalStates.barDialogType = "battery";
            GlobalStates.barDialogOpen = true;
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing

        CosmicIcon {
            Layout.alignment: Qt.AlignVCenter
            name: isCharging ? "status/plugged-into-power-symbolic" : "devices/battery-symbolic"
            iconSize: Appearance.font.pixelSize.larger + 1
            color: root.colIcon
        }
    }

    BatteryHoverPopup {
        id: batteryHoverPopup
        hoverTarget: root
    }
}
