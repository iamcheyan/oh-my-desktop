import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string title: ""
    property bool expanded: false
    default property alias content: contentColumn.children

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: SettingsTokens.radius
        color: headerMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            MaterialSymbol {
                Layout.preferredWidth: 20
                Layout.fillHeight: true
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: 18
                color: SettingsTokens.muted
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    ColumnLayout {
        id: contentColumn
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 2
        visible: root.expanded
    }
}
