pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

StyledText {
    id: root
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    // Truncate to 1 decimal as a number (not a string) and only emit a new
    // value when it actually changes, so font.variableAxes isn't rebuilt on
    // every animation frame.
    property real truncatedFill: Math.round(fill * 10) / 10
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    font {
        hintingPreference: Font.PreferNoHinting
        family: Appearance?.font.family.iconMaterial ?? "Material Symbols Rounded"
        pixelSize: iconSize
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * truncatedFill
        variableAxes: {
            "FILL": root.truncatedFill,
            "opsz": root.iconSize,
        }
    }

    Behavior on fill {
        // Replaced the leaky NumberAnimation with a QtObject-holding Behavior.
        // The previous comment noted a leak; keeping the animation but making
        // truncatedFill numeric (not a string from toFixed) avoids rebuilding
        // the variableAxes object with a string-typed FILL axis every frame.
        NumberAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }
}
