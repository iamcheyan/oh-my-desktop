// PopupInfoRow — GNOME Quick Settings info row.
// Label left (white), value right (dim). Height 44px. No divider by default.
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property color valueColor: TuiStyle.dim
    property bool showDivider: false   // default OFF — continuous info rows have no separator

    implicitHeight: 44
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 20
            rightMargin: 20
        }
        spacing: 10

        NerdIcon {
            visible: root.icon.length > 0
            iconSize: 16
            text: root.icon
            color: TuiStyle.dim
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.label
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal + 1   // ~16px
            font.weight: Font.Normal
            color: TuiStyle.fg
            elide: Text.ElideRight
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.value
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal         // ~15px
            font.weight: Font.Normal
            color: root.valueColor
            horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: TuiStyle.line
        opacity: 0.10
        visible: root.showDivider
    }
}
