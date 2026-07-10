import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: iconButton
    property string iconName: ""
    signal clicked()

    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    radius: SettingsTokens.radius
    color: iconMouse.containsMouse ? SettingsTokens.panelAlt : "transparent"

    MaterialSymbol {
        anchors.centerIn: parent
        text: iconButton.iconName
        iconSize: 18
        color: SettingsTokens.accent
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconButton.clicked()
    }
}