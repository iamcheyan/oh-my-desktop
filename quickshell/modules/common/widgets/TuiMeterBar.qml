import qs.modules.common
import QtQuick

Item {
    id: root

    property real value: 0
    property color accent: TuiStyle.success
    property color emptyColor: TuiStyle.meterTrack

    clip: true

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.emptyColor
        border.width: 0
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(height, parent.width * Math.max(0, Math.min(100, root.value)) / 100)
        radius: height / 2
        color: root.accent
        opacity: 0.85
    }
}
