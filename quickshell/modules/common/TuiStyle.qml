import QtQuick
pragma Singleton

QtObject {
    id: root

    // Early GNOME Shell inspired palette: black translucent surfaces, grey
    // outlines, and low-saturation semantic states.
    readonly property color bg: "#9a050505"
    readonly property color panel: "#662b2b2b"
    readonly property color panelAlt: "#7a494949"
    readonly property color fg: "#f4f4f4"
    readonly property color dim: "#a8a8a8"
    readonly property color line: "#8a8a8a"
    readonly property color green: "#eeeeee"
    readonly property color yellow: "#d0d0d0"
    readonly property color blue: "#eeeeee"
    readonly property color purple: "#c8c8c8"
    readonly property color red: "#f0f0f0"
    readonly property color dangerPanel: "#70282828"
    readonly property color selection: "#784d4d4d"
    readonly property color scrim: "#90000000"

    // Shell/dialog chrome
    readonly property color shellGradientTop: "#a8303030"
    readonly property color shellGradientMid: "#8c080808"
    readonly property color shellGradientBottom: "#a6161616"
    readonly property color shellBorder: "#99b8b8b8"

    // Interior surfaces
    readonly property color surfaceSubtle: "#66181818"
    readonly property color surfaceRaised: "#70202020"
    readonly property color surfaceHover: "#78242424"
    readonly property color surfacePressed: "#88303030"

    // Controls
    readonly property color control: "#802b2b2b"
    readonly property color controlHover: "#a04d4d4d"
    readonly property color controlMuted: "#70222222"
    readonly property color controlActiveBorder: "#b0b0b0b0"
    readonly property color miniControlHover: "#78303030"
    readonly property color miniControlPressed: "#903a3a3a"
    readonly property real accentWashOpacity: 0.14

    // Meters
    readonly property color meterTrack: "#66181818"

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
