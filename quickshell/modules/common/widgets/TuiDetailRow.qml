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
    spacing: 10

    StyledText {
        Layout.preferredWidth: root.keyWidth
        text: root.keyText
        font.family: Appearance.font.family.monospace
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Bold
        color: root.keyColor
        elide: Text.ElideRight
    }

    StyledText {
        Layout.fillWidth: true
        text: root.valueText
        font.family: Appearance.font.family.monospace
        font.pixelSize: root.fontPixelSize
        font.weight: Font.Bold
        color: root.valueColor
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }
}
