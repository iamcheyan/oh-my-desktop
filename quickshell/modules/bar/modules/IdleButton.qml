import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

CircleUtilButton {
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    onClicked: Idle.toggleInhibit()
    Item {
        implicitWidth: 20
        implicitHeight: 20
        property bool hovered: parent.hovered
        CosmicIcon {
            anchors.centerIn: parent
            name: Idle.inhibit ? "actions/document-properties-symbolic" : "actions/image-red-eye-symbolic"
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }

    }
}
