pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick

Rectangle {
    id: meter

    property real value: 0 // 0 - 100
    property color accent: TuiStyle.accent
    property color trackColor: Qt.rgba(1, 1, 1, 0.1)

    implicitWidth: 100
    implicitHeight: 8
    radius: height / 2
    color: meter.trackColor
    clip: true

    Rectangle {
        height: parent.height
        width: Math.max(0, Math.min(parent.width, parent.width * (meter.value / 100)))
        radius: parent.radius
        color: meter.accent

        Behavior on width {
            NumberAnimation { duration: 200 }
        }
    }
}
