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

    CircleUtilButton {
        id: clipboardButton
        anchors.centerIn: parent

        onClicked: {
            GlobalStates.toggleBarPopup("clipboard");
        }

        content: Item {
            implicitWidth: 20
            implicitHeight: 20

            CosmicIcon {
                anchors.centerIn: parent
                name: "actions/edit-paste-symbolic"
                iconSize: Config.options.bar.rightIconSize
                color: Appearance.colors.colBarText
            }
        }
    }

    Loader {
        id: clipboardPopupLoader
        active: GlobalStates.barPopupType === "clipboard"

        function open() {
            GlobalStates.openBarPopup("clipboard");
        }

        function close() {
            GlobalStates.closeBarPopup("clipboard");
        }

        sourceComponent: ClipboardInfoPopup {
            Component.onCompleted: this.visible = true
            anchor {
                window: root.QsWindow.window
                item: root.parent?.parent ?? root
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            onMenuClosed: {
                GlobalStates.closeBarPopup("clipboard");
            }
            onManageRequested: {
                Quickshell.execDetached([
                    "qs", "-p", FileUtils.trimFileProtocol(Directories.config) + "/omd/apps/omd-clipboard",
                    "ipc", "call", "clipboard", "toggle"
                ]);
            }
        }
    }
}
