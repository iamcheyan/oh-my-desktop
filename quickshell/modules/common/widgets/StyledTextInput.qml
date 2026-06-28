import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextInput {
    color: TuiStyle.fg
    renderType: Text.NativeRendering
    selectedTextColor: TuiStyle.bg
    selectionColor: TuiStyle.accent
    font {
        family: Appearance.font.family.monospace
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
    }
}
