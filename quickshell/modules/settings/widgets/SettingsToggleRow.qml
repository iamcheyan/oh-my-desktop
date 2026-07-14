import qs.modules.settings
import QtQuick

SettingsRow {
    id: toggleRow
    property bool checked: false
    signal toggled()

    clickable: false
    value: ""
    rightInset: 70

    Rectangle {
        id: switchBorder
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 26
        radius: height / 2
        color: toggleRow.checked ? SettingsTokens.accent : SettingsTokens.line

        Rectangle {
            width: 20
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: toggleRow.checked ? parent.width - width - 3 : 3
            color: toggleRow.checked ? SettingsTokens.bg : SettingsTokens.fg
            Behavior on x { NumberAnimation { duration: 110 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRow.toggled()
        }
    }
}