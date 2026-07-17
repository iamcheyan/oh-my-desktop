import QtQuick

Text {
    id: root

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    font {
        hintingPreference: Font.PreferDefaultHinting
        family: ClipboardStyle.fontFamily
        pixelSize: ClipboardStyle.fontPixelSmall
    }
    color: ClipboardStyle.fg
    linkColor: ClipboardStyle.accent
}