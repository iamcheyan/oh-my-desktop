import qs.modules.settings
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: meter
    property real value: 0

    Layout.fillWidth: true
    Layout.preferredHeight: 8
    radius: height / 2
    color: SettingsTokens.line

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(parent.height, parent.width * SettingsTokens.clamp(meter.value, 0, 100) / 100)
        radius: height / 2
        color: SettingsTokens.accent
    }
}