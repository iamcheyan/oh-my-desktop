// Compact popup adapter for the shared settings toggle row.
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool showDivider: true
    property bool enabled: true
    signal toggled(bool checked)

    implicitHeight: settingsToggle.implicitHeight
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    SettingsToggleRow {
        id: settingsToggle
        anchors.fill: parent
        label: root.label
        checked: root.checked
        enabled: root.enabled
        opacity: root.enabled ? 1 : 0.45
        onToggled: root.toggled(!root.checked)
    }

    // Bottom divider — very subtle
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
