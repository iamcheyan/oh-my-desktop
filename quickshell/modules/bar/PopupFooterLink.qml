// Popup adapter for the shared settings navigation row.
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    signal clicked()

    implicitHeight: navigationRow.implicitHeight + 1
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    // Top divider to separate from content
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: SettingsTokens.line
        opacity: TuiStyle.dividerOpacity
    }

    SettingsNavigationRow {
        id: navigationRow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: 1
        }
        label: root.label
        onClicked: root.clicked()
    }
}
