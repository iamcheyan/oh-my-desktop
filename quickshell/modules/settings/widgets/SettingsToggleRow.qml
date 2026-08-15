pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick

SettingsRow {
    id: toggleRow
    property bool checked: false
    property bool showSettingsButton: false
    signal toggled()
    signal settingsClicked()

    clickable: false
    value: ""
    rightInset: (showSettingsButton && checked) ? 106 : 70

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

    Rectangle {
        id: gearButton
        visible: toggleRow.showSettingsButton && toggleRow.checked
        anchors.right: switchBorder.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: SettingsTokens.radius
        color: gearMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

        MaterialSymbol {
            anchors.centerIn: parent
            text: "settings"
            iconSize: 16
            color: SettingsTokens.muted
        }

        MouseArea {
            id: gearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRow.settingsClicked()
        }
    }
}