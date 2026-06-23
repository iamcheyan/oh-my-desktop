import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    required property var icon
    required property var label
    height: 24
    implicitWidth: row.implicitWidth + 10 * 2
    color: Appearance.tiling.bgTitlebar
    radius: 0

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        CosmicIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.tiling.textBright
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font {
                weight: Font.Bold
                pixelSize: Appearance.font.pixelSize.small
            }
            color: Appearance.tiling.textBright
        }
    }
}