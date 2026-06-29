import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    required property var icon
    required property var label

    implicitHeight: TuiStyle.rowHeight
    Layout.fillWidth: true
    Layout.minimumHeight: TuiStyle.rowHeight
    Layout.preferredHeight: TuiStyle.rowHeight
    Layout.maximumHeight: TuiStyle.rowHeight
    spacing: 8

    Item {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignVCenter

        NerdIcon {
            anchors.centerIn: parent
            text: root.icon
            color: TuiStyle.fg
            iconSize: 18
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: root.label
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: TuiStyle.fg
    }
}