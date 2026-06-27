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
            if (!nightLightPopupLoader.active)
                nightLightPopupLoader.open();
            nightLightPopupTimer.restart();
        }
    }

    CircleUtilButton {
        id: nightLightButton
        anchors.centerIn: parent

        onClicked: {
            GlobalStates.barDialogType = "nightlight";
            GlobalStates.barDialogOpen = true;
        }

        onHoveredChanged: {
            if (nightLightButton.hovered)
                nightLightPopupLoader.open();
            else
                nightLightPopupLoader.close();
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

    Loader {
        id: nightLightPopupLoader
        active: false

        function open() {
            nightLightPopupTimer.stop();
            nightLightPopupLoader.active = true;
        }

        function close() {
            nightLightPopupTimer.restart();
        }

        Timer {
            id: nightLightPopupTimer
            interval: 300
            repeat: false
            onTriggered: nightLightPopupLoader.active = false
        }

        sourceComponent: DisplayInfoPopup {
            Component.onCompleted: this.visible = true
            anchor {
                window: root.QsWindow.window
                item: root.parent?.parent ?? root
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            onMenuClosed: {
                nightLightPopupLoader.active = false;
            }
        }
    }
}