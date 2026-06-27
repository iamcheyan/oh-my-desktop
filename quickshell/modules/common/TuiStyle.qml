import QtQuick
pragma Singleton

QtObject {
    id: root

    readonly property color bg: "#030806"
    readonly property color panel: "#06110e"
    readonly property color panelAlt: "#091814"
    readonly property color fg: "#e8fff3"
    readonly property color dim: "#65736e"
    readonly property color line: "#174339"
    readonly property color green: "#36ff8b"
    readonly property color yellow: "#e8ff82"
    readonly property color blue: "#7bc7ff"
    readonly property color purple: "#c792ea"
    readonly property color red: "#ff6b8b"
    readonly property color selection: "#6576a8"

    readonly property int borderWidth: 1
    readonly property int radius: 0
    readonly property int panelPadding: 12
    readonly property int rowHeight: 34
    readonly property int buttonHeight: 30
    readonly property int meterSegments: 14
}
