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
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
        }

        content: BarNerdIcon {
            text: NerdIconMap.brightness6
            color: Appearance.colors.colBarText
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                screenshotMenu.open();
            }
        }
    }

    Loader {
        id: screenshotMenu
        function open() {
            if (screenshotMenu.item) {
                screenshotMenu.item.open();
            } else {
                screenshotMenu.active = true;
            }
        }
        active: false
        sourceComponent: ScreenshotContextMenu {
            Component.onCompleted: this.open();
            anchor {
                window: nightLightButton.QsWindow.window
                item: nightLightButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                screenshotMenu.active = false;
            }
        }
    }
}
