import Quickshell
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
    property bool isFirstClick: true

    function openDisplayPopup() {
        // Pin popup + brightness to the monitor this bar sits on.
        const scr = displayButton.QsWindow?.window?.screen;
        GlobalStates.barPopupAnchorScreen = scr?.name ?? "";
        GlobalStates.barPopupType = "display";
    }

    Timer {
        id: doubleClickTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.isFirstClick = true;
            root.openDisplayPopup();
        }
    }

    CircleUtilButton {
        id: displayButton
        anchors.centerIn: parent
        toggled: GlobalStates.barPopupType === "display"

        onClicked: {
            if (root.isFirstClick) {
                root.isFirstClick = false;
                doubleClickTimer.start();
            } else {
                doubleClickTimer.stop();
                root.isFirstClick = true;
                Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-screenshot`, "screenshot"]);
            }
        }

        altAction: () => screenshotMenu.open()

        content: BarNerdIcon {
            text: NerdIconMap.desktop
            color: Appearance.colors.colBarText
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            // Scroll on the icon adjusts THIS bar's monitor only (not all outputs).
            const currentScreen = displayButton.QsWindow?.window?.screen
            if (currentScreen) {
                GlobalStates.osdBrightnessScreen = currentScreen.name
                for (let i = 0; i < Math.abs(r.steps); i++) {
                    Brightness.adjustBrightnessForScreen(currentScreen, r.steps > 0)
                }
            }
            wheel.accepted = true;
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
                window: displayButton.QsWindow.window
                item: displayButton
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
