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

    property bool isFirstClick: true

    Timer {
        id: doubleClickTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.isFirstClick = true;
            // Single click: open the main clipboard dialog
            Quickshell.execDetached([
                "qs", "-p", `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-clipboard`,
                "ipc", "call", "clipboard", "toggle"
            ]);
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
                // Double click: paste the most recent item
                if (Cliphist.entries.length > 0) {
                    Cliphist.paste(Cliphist.entries[0]);
                }
            }
        }

        content: NerdIcon {
            text: NerdIconMap.contentPaste
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }
    }

    // Transparent MouseArea for hover detection (non-blocking for clicks)
    MouseArea {
        id: hoverArea
        anchors.fill: clipboardButton
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ClipboardHoverPopup {
        id: clipboardHoverPopup
        hoverTarget: hoverArea
    }
}
