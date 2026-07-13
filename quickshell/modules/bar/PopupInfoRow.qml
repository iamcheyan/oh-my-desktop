// Popup adapter for the shared settings value row.
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property color valueColor: SettingsTokens.muted
    property bool showDivider: false   // default OFF — continuous info rows have no separator

    implicitHeight: settingsRow.implicitHeight
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    SettingsRow {
        id: settingsRow
        anchors.fill: parent
        label: root.label
        value: root.value
        valueColor: root.valueColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: SettingsTokens.line
        opacity: TuiStyle.dividerOpacity
        visible: root.showDivider
    }
}
