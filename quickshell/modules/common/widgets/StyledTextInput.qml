import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextInput {
    color: Appearance.tiling.textBright
    renderType: Text.NativeRendering
    selectedTextColor: Appearance.tiling.bg
    selectionColor: Appearance.tiling.accent
    font {
        family: Appearance.font.family.monospace
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
    }
}
