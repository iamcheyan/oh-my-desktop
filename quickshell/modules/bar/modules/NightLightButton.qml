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

    CircleUtilButton {
        id: nightLightButton
        anchors.centerIn: parent

        onClicked: {
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-screenshot`, "screenshot"]);
        }

        content: BarNerdIcon {
            text: NerdIconMap.desktop
            color: Appearance.colors.colBarText
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                screenshotMenu.open();
            }
        }
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            const currentScreen = nightLightButton.QsWindow.window.screen
            for (let i = 0; i < Math.abs(r.steps); i++) {
                Brightness.adjustBrightnessForScreen(currentScreen, r.steps > 0)
            }
            wheel.accepted = true;
            GlobalStates.barPopupType = "display";
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
