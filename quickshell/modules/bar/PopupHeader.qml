// PopupHeader — GNOME Quick Settings style header row.
// Icon (no background badge) + title + subtitle, optional trailing action.
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    default property alias content: row.data

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color tone: TuiStyle.accent
    property bool showDivider: true
    // Optional trailing action (e.g. settings gear on Volume header).
    property string actionIcon: ""
    property string actionTooltip: ""

    signal actionClicked()

    implicitHeight: 72
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    RowLayout {
        id: row
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: divider.top
            leftMargin: 20
            rightMargin: 16
        }
        spacing: 14

        // Icon — plain, no background block
        NerdIcon {
            Layout.alignment: Qt.AlignVCenter
            iconSize: 26
            text: root.icon
            color: TuiStyle.fg
            visible: root.icon.length > 0
        }

        // Text stack
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal + 1   // ~17px
                font.weight: Font.Medium
                color: TuiStyle.fg
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.subtitle
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small         // ~13px
                font.weight: Font.Normal
                color: TuiStyle.dim
                elide: Text.ElideRight
                visible: root.subtitle.length > 0
            }
        }

        PopupActionButton {
            Layout.alignment: Qt.AlignVCenter
            icon: root.actionIcon
            visible: root.actionIcon.length > 0
            onClicked: root.actionClicked()
        }
    }

    // Divider
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
