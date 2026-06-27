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
            GlobalStates.barPopupType = GlobalStates.barPopupType === "clipboard" ? "" : "clipboard";
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

}
