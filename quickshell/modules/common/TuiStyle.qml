import QtQuick
pragma Singleton

QtObject {
    id: root

    // Base terminal palette. Keep the UI mostly monochrome; use green as the
    // only strong accent, amber for warning, and red only for destructive/error states.
    readonly property color bg: "#030806"
    readonly property color panel: "#06110e"
    readonly property color panelAlt: "#0a1914"
    readonly property color fg: "#e8fff3"
    readonly property color dim: "#6f8179"
    readonly property color line: "#1f4a3e"
    readonly property color green: "#36ff8b"
    readonly property color yellow: "#d7c86a"
    readonly property color blue: "#9fb8ad"
    readonly property color purple: "#94a89f"
    readonly property color red: "#ff6b78"
    readonly property color dangerPanel: "#251016"
    readonly property color selection: "#214f42"
    readonly property color scrim: "#80030806"

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
