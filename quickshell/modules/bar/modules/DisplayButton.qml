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
    property bool isFirstClick: true

    Timer {
        id: doubleClickTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.isFirstClick = true;
            GlobalStates.barPopupType = "display";
        }
    }

    CircleUtilButton {
        id: displayButton
        anchors.centerIn: parent

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
            const currentScreen = displayButton.QsWindow.window.screen
            for (let i = 0; i < Math.abs(r.steps); i++) {
                Brightness.adjustBrightnessForScreen(currentScreen, r.steps > 0)
            }
            wheel.accepted = true;
            GlobalStates.barPopupType = "display";
        }
    }
}
