pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: button
    property string label: ""
    property string iconName: ""
    property bool active: false
    property bool enabledState: true
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: SettingsTokens.controlHeight
    Layout.minimumHeight: SettingsTokens.controlHeight
    Layout.maximumHeight: SettingsTokens.controlHeight
    radius: SettingsTokens.radius
    color: active ? SettingsTokens.buttonActive : buttonMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
    border.width: 1
    border.color: active ? SettingsTokens.accent : SettingsTokens.buttonBorder
    opacity: enabledState ? 1 : 0.45

    RowLayout {
        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            visible: button.iconName.length > 0
            text: button.iconName
            iconSize: 18
            color: button.active ? SettingsTokens.accent : SettingsTokens.fg
        }

        StyledText {
            text: button.label
            color: button.active ? SettingsTokens.accent : SettingsTokens.fg
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        enabled: button.enabledState
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
