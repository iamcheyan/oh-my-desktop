import qs.modules.common
import QtQuick

Row {
    id: root

    property real value: 0
    property color accent: TuiStyle.success
    property color emptyColor: TuiStyle.line
    property int segments: TuiStyle.meterSegments
    property int segmentSpacing: 3
    property int minSegmentWidth: 8

    spacing: segmentSpacing

    Repeater {
        model: root.segments

        Rectangle {
            required property int index
            width: Math.max(root.minSegmentWidth, (root.width - root.segmentSpacing * Math.max(0, root.segments - 1)) / root.segments)
            height: root.height
            color: index < Math.ceil(Math.max(0, Math.min(100, root.value)) / 100 * root.segments) ? root.accent : root.emptyColor
        }
    }
}
