import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    required property string icon
    required property string label
    required property string value
    spacing: 6

    CosmicIcon {
        name: root.icon
        color: TuiStyle.accent
        iconSize: Appearance.font.pixelSize.small
    }
    StyledText {
        text: root.label
        color: TuiStyle.fg
        font.pixelSize: Appearance.font.pixelSize.smaller
    }
    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        visible: root.value !== ""
        color: TuiStyle.fg
        text: root.value
        font.pixelSize: Appearance.font.pixelSize.smaller
    }
}