import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property string keyText: ""
    property string valueText: ""
    property color valueColor: TuiStyle.fg
    property color keyColor: TuiStyle.dim
    property int keyWidth: 96

    Layout.fillWidth: true
    spacing: 8

    StyledText {
        text: root.keyText
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.keyColor
        Layout.preferredWidth: root.keyWidth
    }

    StyledText {
        text: root.valueText
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Medium
        color: root.valueColor
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
    }
}
