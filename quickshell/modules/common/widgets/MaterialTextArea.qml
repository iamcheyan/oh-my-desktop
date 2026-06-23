import qs.modules.common
import QtQuick
import QtQuick.Controls

TextArea {
    id: root
    renderType: Text.QtRendering

    selectedTextColor: Appearance.tiling.bg
    selectionColor: Appearance.tiling.accent
    placeholderTextColor: Appearance.tiling.textDim
    color: Appearance.tiling.textBright

    background: Rectangle {
        implicitHeight: 34
        color: Appearance.tiling.bgInput
        radius: 0
        border.width: Appearance.tiling.borderWidth
        border.color: root.focus ? Appearance.tiling.borderFocus
            : root.hovered ? Appearance.tiling.textDim
            : Appearance.tiling.border
    }

    font {
        family: Appearance.font.family.monospace
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
    }
    wrapMode: TextEdit.Wrap
}
