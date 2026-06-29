import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root

    property alias text: icon.text
    property color color: Appearance.colors.colBarText
    property real iconSize: Config.options.bar.rightIconSize
    property bool opticalBalance: true
    property real targetInkSize: iconSize * 0.82
    property real minOpticalScale: 0.82
    property real maxOpticalScale: 1.14

    readonly property real measuredInkSize: Math.max(1, Math.max(
        iconMetrics.tightBoundingRect.width,
        iconMetrics.tightBoundingRect.height
    ))
    readonly property real opticalScale: opticalBalance
        ? Math.max(minOpticalScale, Math.min(maxOpticalScale, targetInkSize / measuredInkSize))
        : 1

    implicitWidth: Config.options.bar.rightIconSize
    implicitHeight: Config.options.bar.rightIconSize

    TextMetrics {
        id: iconMetrics
        text: root.text
        font.family: Appearance?.font.family.iconNerd ?? "JetBrainsMono Nerd Font Mono"
        font.pixelSize: root.iconSize
    }

    NerdIcon {
        id: icon
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        iconSize: root.iconSize * root.opticalScale
        color: root.color
    }
}
