import QtQuick
pragma Singleton

QtObject {
    id: root

    // Base terminal palette. Keep the TUI surfaces monochrome; semantic states
    // use brightness and contrast instead of saturated color.
    readonly property color bg: "#050505"
    readonly property color panel: "#0d0d0d"
    readonly property color panelAlt: "#171717"
    readonly property color fg: "#f2f2f2"
    readonly property color dim: "#8a8a8a"
    readonly property color line: "#3a3a3a"
    readonly property color green: "#d7d7d7"
    readonly property color yellow: "#b8b8b8"
    readonly property color blue: "#c6c6c6"
    readonly property color purple: "#ababab"
    readonly property color red: "#e0e0e0"
    readonly property color dangerPanel: "#1c1c1c"
    readonly property color selection: "#2b2b2b"
    readonly property color scrim: "#80000000"

    readonly property color accent: green
    readonly property color success: green
    readonly property color warning: yellow
    readonly property color info: blue
    readonly property color muted: dim
    readonly property color danger: red

    readonly property int borderWidth: 1
    readonly property int radius: 0
    readonly property int panelPadding: 12
    readonly property int rowHeight: 34
    readonly property int buttonHeight: 30
    readonly property int meterSegments: 14
}
