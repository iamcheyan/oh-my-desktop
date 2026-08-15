// PopupDeviceRow — GNOME Quick Settings current-device row.
// Icon (plain white, no badge) + name + detail, status right-aligned white.
pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string name: ""
    property string detail: ""
    property string status: ""
    // status color kept for future use but status text is always white (fg)
    property color statusColor: TuiStyle.accent
    property bool showDivider: true

    implicitHeight: 72
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: divider.top
            leftMargin: 20
            rightMargin: 20
        }
        spacing: 14

        // Plain icon — no background block
        NerdIcon {
            Layout.alignment: Qt.AlignVCenter
            iconSize: 26
            text: root.icon
            color: TuiStyle.fg
            visible: root.icon.length > 0
        }

        // Name + detail
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.name
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal + 1   // ~17px
                font.weight: Font.Medium
                color: TuiStyle.fg
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.detail
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small         // ~13px
                font.weight: Font.Normal
                color: TuiStyle.dim
                elide: Text.ElideRight
                visible: root.detail.length > 0
            }
        }

        // Status text — ALWAYS white (fg), not accent
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.status
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal           // ~15px
            font.weight: Font.Normal
            color: TuiStyle.fg
            horizontalAlignment: Text.AlignRight
            visible: root.status.length > 0
        }
    }

    Rectangle {
        id: divider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: TuiStyle.line
        opacity: TuiStyle.dividerOpacity
        visible: root.showDivider
    }
}
