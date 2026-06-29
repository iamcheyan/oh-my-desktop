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
    readonly property bool isCharging: Battery.isCharging
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property color colIcon: Appearance.colors.colBarText

    implicitWidth: Config.options.bar.rightIconSlotWidth
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

        BarNerdIcon {
            Layout.alignment: Qt.AlignVCenter
            text: {
                const pct = root.percentage;
                if (root.isCharging) {
                    if (pct > 0.9) return NerdIconMap.batteryChargingFull;
                    if (pct > 0.8) return NerdIconMap.batteryCharging90;
                    if (pct > 0.7) return NerdIconMap.batteryCharging80;
                    if (pct > 0.6) return NerdIconMap.batteryCharging70;
                    if (pct > 0.5) return NerdIconMap.batteryCharging60;
                    if (pct > 0.4) return NerdIconMap.batteryCharging50;
                    if (pct > 0.3) return NerdIconMap.batteryCharging40;
                    if (pct > 0.2) return NerdIconMap.batteryCharging30;
                    if (pct > 0.1) return NerdIconMap.batteryCharging20;
                    return NerdIconMap.batteryCharging10;
                } else {
                    if (pct > 0.9) return NerdIconMap.battery90;
                    if (pct > 0.8) return NerdIconMap.battery80;
                    if (pct > 0.7) return NerdIconMap.battery70;
                    if (pct > 0.6) return NerdIconMap.battery60;
                    if (pct > 0.5) return NerdIconMap.battery50;
                    if (pct > 0.4) return NerdIconMap.battery40;
                    if (pct > 0.3) return NerdIconMap.battery30;
                    if (pct > 0.2) return NerdIconMap.battery20;
                    if (pct > 0.1) return NerdIconMap.battery10;
                    return NerdIconMap.batteryAlert;
                }
            }
            color: root.colIcon
        }
    }

    BatteryHoverPopup {
        id: batteryHoverPopup
        hoverTarget: root
    }
}
