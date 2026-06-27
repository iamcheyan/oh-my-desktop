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
        GlobalStates.toggleBarPopup("battery");
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Config.options.bar.rightModuleSpacing

        CosmicIcon {
            Layout.alignment: Qt.AlignVCenter
            name: isCharging ? "status/plugged-into-power-symbolic" : "devices/battery-symbolic"
            iconSize: Config.options.bar.rightIconSize
            color: root.colIcon
        }
    }

    Loader {
        id: batteryPopupLoader
        active: GlobalStates.barPopupType === "battery"

        function open() {
            GlobalStates.openBarPopup("battery");
        }

        function close() {
            GlobalStates.closeBarPopup("battery");
        }

        sourceComponent: BatteryInfoPopup {
            Component.onCompleted: {
                this.visible = true;
                this.anchor {
                    window: root.QsWindow.window
                    item: root
                    gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                    edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                }
            }
            onMenuClosed: {
                GlobalStates.closeBarPopup("battery");
            }
            onManageRequested: {
                GlobalStates.controlCenterOpen = true;
            }
        }
    }
}
