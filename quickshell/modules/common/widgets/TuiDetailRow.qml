import qs.modules.common
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string keyText: ""
    property string valueText: ""
    property color keyColor: TuiStyle.muted
    property color valueColor: TuiStyle.fg
    property int keyWidth: 70
    property int fontPixelSize: Appearance.font.pixelSize.smaller

    Layout.fillWidth: true
    spacing: 12
    Layout.preferredHeight: TuiStyle.rowHeight

    StyledText {
        Layout.preferredWidth: root.keyWidth
        Layout.alignment: Qt.AlignVCenter
        text: root.keyText
        font.family: Appearance.font.family.main
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Medium
        color: root.keyColor
        elide: Text.ElideRight
    }

    StyledText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: root.valueText
        font.family: Appearance.font.family.main
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Medium
        color: root.valueColor
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }
}
