import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth
    property real wheelAccum: 0

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            for (let i = 0; i < Math.abs(r.steps); i++) {
                if (r.steps > 0)
                    Brightness.increaseBrightness();
                else if (r.steps < 0)
                    Brightness.decreaseBrightness();
            }
            wheel.accepted = true;
            GlobalStates.barPopupType = "display";
        }
    }

    CircleUtilButton {
        id: nightLightButton
        anchors.centerIn: parent

        onClicked: {
            GlobalStates.barPopupType = GlobalStates.barPopupType === "display" ? "" : "display";
        }

        content: Item {
            implicitWidth: 20
            implicitHeight: 20

            CosmicIcon {
                anchors.centerIn: parent
                name: Hyprsunset.temperatureActive ? "status/weather-clear-night-symbolic" : "status/display-brightness-off-symbolic"
                iconSize: Config.options.bar.rightIconSize
                color: Appearance.colors.colBarText
            }
        }
    }

}
