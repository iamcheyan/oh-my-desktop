import qs.modules.common
import QtQuick
import QtQuick.Controls

TextArea {
    id: root
    renderType: Text.QtRendering

    selectedTextColor: TuiStyle.bg
    selectionColor: TuiStyle.accent
    placeholderTextColor: TuiStyle.dim
    color: TuiStyle.fg

    background: Rectangle {
        implicitHeight: 34
        color: "#181818"
        radius: 0
        border.width: TuiStyle.borderWidth
        border.color: root.focus ? TuiStyle.accent
            : root.hovered ? TuiStyle.dim
            : TuiStyle.line
    }

    font {
        family: Appearance.font.family.monospace
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
    }
    wrapMode: TextEdit.Wrap
}
