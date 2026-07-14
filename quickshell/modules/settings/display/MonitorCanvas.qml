import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

Rectangle {
    id: root

    required property var displayState
    property string selectedOutputName: ""
    signal outputSelected(string name)

    readonly property var displayBounds: (displayState.revision, displayState.bounds())

    implicitHeight: 220
    radius: SettingsTokens.radius
    color: SettingsTokens.bg
    border.width: 1
    border.color: SettingsTokens.line
    clip: true

    Item {
        id: canvas
        anchors.fill: parent
        anchors.margins: 22
        anchors.bottomMargin: 36

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
            model: root.displayState.visibleOutputs

            MonitorRect {
                required property var modelData
                displayState: root.displayState
                output: modelData
                selected: modelData.name === root.selectedOutputName
                canvasScaleFactor: canvas.scaleFactor
                canvasOffset: canvas.offset
                onOutputSelected: name => root.outputSelected(name)
            }
        }
    }

    Row {
        visible: root.displayState.visibleOutputs.length > 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 6

        MaterialSymbol {
            text: "drag_pan"
            iconSize: 14
            color: SettingsTokens.dim
        }

        StyledText {
            text: "Drag to match your physical layout"
            color: SettingsTokens.dim
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
