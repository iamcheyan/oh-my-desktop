import QtQuick
import qs.services
pragma Singleton

QtObject {
    id: root

    // Early GNOME Shell inspired palette: opaque black surfaces, grey outlines,
    // and low-saturation semantic states.
    readonly property color bg: "#050505"
    readonly property color panel: "#2b2b2b"
    readonly property color panelAlt: "#494949"
    readonly property color fg: "#f4f4f4"
    readonly property color dim: "#a8a8a8"
    readonly property color line: "#8a8a8a"
    readonly property color green: OmarchyTheme.accent
    readonly property color yellow: OmarchyTheme.accent
    readonly property color blue: OmarchyTheme.accent
    readonly property color purple: OmarchyTheme.accent
    readonly property color red: "#f0f0f0"
    readonly property color dangerPanel: "#282828"
    readonly property color selection: OmarchyTheme.accentSoft
    readonly property color scrim: "#000000"

    // Shell/dialog chrome
    readonly property color shellGradientTop: "#303030"
    readonly property color shellGradientMid: "#080808"
    readonly property color shellGradientBottom: "#161616"
    readonly property color shellBorder: OmarchyTheme.accentBorder

    // Interior surfaces
    readonly property color surfaceSubtle: "#181818"
    readonly property color surfaceRaised: "#1c1c1c"
    readonly property color surfaceHover: "#242424"
    readonly property color surfacePressed: "#303030"

    // Controls
    readonly property color control: "#2b2b2b"
    readonly property color controlHover: "#4d4d4d"
    readonly property color controlMuted: "#222222"
    readonly property color controlActiveBorder: OmarchyTheme.accentActiveBorder
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
