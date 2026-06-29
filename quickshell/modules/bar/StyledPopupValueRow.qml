import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    required property string icon
    required property string label
    required property string value

    readonly property int horizontalPadding: 8
    readonly property int labelMaxWidth: 170

    // Strictly enforce minimum/implicit widths to prevent right side text clipping
    implicitWidth: Math.min(360, 26 + spacing + Math.min(labelText.implicitWidth, labelMaxWidth) + spacing + valueText.implicitWidth + (horizontalPadding * 2))
    implicitHeight: TuiStyle.rowHeight
    Layout.fillWidth: true
    Layout.minimumHeight: TuiStyle.rowHeight
    Layout.preferredHeight: TuiStyle.rowHeight
    Layout.maximumHeight: TuiStyle.rowHeight
    Layout.leftMargin: horizontalPadding
    Layout.rightMargin: horizontalPadding
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
        id: labelText
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: root.labelMaxWidth
        text: root.label
        color: TuiStyle.fg
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Normal
        elide: Text.ElideRight
    }

    StyledText {
        id: valueText
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
        visible: root.value !== ""
        color: TuiStyle.dim
        text: root.value
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Normal
        elide: Text.ElideRight
    }
}
