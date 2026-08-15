pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Text {
    id: root
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font {
        family: Appearance?.font.family.iconNerd ?? "JetBrainsMono Nerd Font Mono"
        pixelSize: iconSize
    }
}

