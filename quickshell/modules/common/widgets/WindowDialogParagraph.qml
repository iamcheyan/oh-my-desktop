import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

StyledText {
    text: "Some body content"
    color: Appearance.tiling.text
    font.pixelSize: Appearance.font.pixelSize.smaller
    wrapMode: Text.Wrap
}