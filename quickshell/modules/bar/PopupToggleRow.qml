// Compact popup adapter for the shared settings toggle row.
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool showDivider: true
    property bool enabled: true
    property bool showSettingsButton: false
    signal toggled(bool checked)
    signal settingsClicked()

    implicitHeight: settingsToggle.implicitHeight
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    SettingsToggleRow {
        id: settingsToggle
        anchors {
            fill: parent
            leftMargin: 6
            rightMargin: 6
        }
        label: root.label
        checked: root.checked
        enabled: root.enabled
        opacity: root.enabled ? 1 : 0.45
        showSettingsButton: root.showSettingsButton
        onToggled: root.toggled(!root.checked)
        onSettingsClicked: root.settingsClicked()
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
