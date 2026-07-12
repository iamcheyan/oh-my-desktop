import Quickshell
import qs.modules.bar
import qs
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
    property bool isFirstClick: true

    Timer {
        id: doubleClickTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.isFirstClick = true;
            GlobalStates.barPopupType = "clipboard";
        }
    }

    CircleUtilButton {
        id: clipboardButton
        anchors.centerIn: parent

        onClicked: {
            if (root.isFirstClick) {
                root.isFirstClick = false;
                doubleClickTimer.start();
            } else {
                doubleClickTimer.stop();
                root.isFirstClick = true;
                Quickshell.execDetached([
                    `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-clipboard-paste-latest`
                ]);
            }
        }

        content: BarNerdIcon {
            text: NerdIconMap.contentPaste
            color: Appearance.colors.colBarText
        }
    }
}
