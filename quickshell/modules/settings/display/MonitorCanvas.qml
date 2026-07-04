import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var state

    readonly property var displayBounds: (state.revision, state.bounds())

    width: parent ? parent.width : 720
    height: 260
    radius: 16
    color: "#101010"
    border.width: 1
    border.color: "#3c3c3c"
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 14
        radius: 12
        color: "#070707"
        border.width: 1
        border.color: "#2c2c2c"
    }

    Item {
        id: canvas
        anchors.fill: parent
        anchors.margins: 28

        property real scaleFactor: {
            const b = root.displayBounds;
            if (!b || b.width <= 0 || b.height <= 0)
                return 0.1;
            return Math.min(width / b.width, height / b.height);
        }
        property point offset: Qt.point(
            (width - root.displayBounds.width * scaleFactor) / 2 - root.displayBounds.minX * scaleFactor,
            (height - root.displayBounds.height * scaleFactor) / 2 - root.displayBounds.minY * scaleFactor
        )

        Repeater {
            model: root.state.visibleOutputs

            MonitorRect {
                required property var modelData
                state: root.state
                output: modelData
                canvasScaleFactor: canvas.scaleFactor
                canvasOffset: canvas.offset
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 14
        width: hintText.implicitWidth + 20
        height: 28
        radius: 14
        color: "#181818"
        border.width: 1
        border.color: "#363636"

        StyledText {
            id: hintText
            anchors.centerIn: parent
            text: "Drag displays to rearrange"
            color: "#a8a8a8"
            font.pixelSize: 12
        }
    }
}
