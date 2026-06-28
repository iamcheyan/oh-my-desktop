import QtQuick
pragma Singleton

QtObject {
    id: root

    // Early GNOME Shell inspired palette: black translucent surfaces, grey
    // outlines, and low-saturation semantic states.
    readonly property color bg: "#de050505"
    readonly property color panel: "#2b2b2b"
    readonly property color panelAlt: "#494949"
    readonly property color fg: "#f4f4f4"
    readonly property color dim: "#a8a8a8"
    readonly property color line: "#8a8a8a"
    readonly property color green: "#eeeeee"
    readonly property color yellow: "#d0d0d0"
    readonly property color blue: "#eeeeee"
    readonly property color purple: "#c8c8c8"
    readonly property color red: "#f0f0f0"
    readonly property color dangerPanel: "#282828"
    readonly property color selection: "#4d4d4d"
    readonly property color scrim: "#90000000"

    // Shell/dialog chrome
    readonly property color shellGradientTop: "#ee151515"
    readonly property color shellGradientMid: "#e7080808"
    readonly property color shellGradientBottom: "#ef111111"
    readonly property color shellBorder: "#8f8f8f"

    // Interior surfaces
    readonly property color surfaceSubtle: "#181818"
    readonly property color surfaceRaised: "#202020"
    readonly property color surfaceHover: "#242424"
    readonly property color surfacePressed: "#303030"

    // Controls
    readonly property color control: "#2b2b2b"
    readonly property color controlHover: "#4d4d4d"
    readonly property color controlMuted: "#222222"
    readonly property color controlActiveBorder: "#9a9a9a"
    readonly property color miniControlHover: "#303030"
    readonly property color miniControlPressed: "#3a3a3a"
    readonly property real accentWashOpacity: 0.14

    // Meters
    readonly property color meterTrack: "#181818"

    // Separators
    readonly property real dividerOpacity: 0.28

    readonly property color accent: green
    readonly property color success: green
    readonly property color warning: yellow
    readonly property color info: blue
    readonly property color muted: dim
    readonly property color danger: red

    readonly property int borderWidth: 2
    readonly property int radius: 14
    readonly property int shellRadius: 18
    readonly property int miniRadius: 4
    readonly property int panelPadding: 14
    readonly property int rowHeight: 38
    readonly property int buttonHeight: 36
    readonly property int meterSegments: 14

    function accentWash(color) {
        return Qt.rgba(color.r, color.g, color.b, accentWashOpacity);
    }
}
