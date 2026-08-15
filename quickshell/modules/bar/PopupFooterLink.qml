// Popup adapter for the footer navigation row (Add new Wi-Fi... / Add new Bluetooth...).
pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    signal clicked()

    implicitHeight: 44
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true
    Layout.leftMargin: 6
    Layout.rightMargin: 6
    Layout.topMargin: 2
    Layout.bottomMargin: 6

    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 6
        color: navMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            MaterialSymbol {
                Layout.preferredWidth: 16
                text: "chevron_right"
                iconSize: 16
                color: SettingsTokens.muted
            }
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }
    }
}
