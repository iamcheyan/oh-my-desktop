import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

Rectangle {
    id: root

    required property var displayState

    readonly property var displayBounds: (displayState.revision, displayState.bounds())

    width: parent ? parent.width : 720
    height: 160
    radius: SettingsTokens.radius
    color: SettingsTokens.bg
    border.width: 1
    border.color: SettingsTokens.buttonBorder
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: SettingsTokens.radius
        color: SettingsTokens.bg
        border.width: 1
        border.color: SettingsTokens.buttonBorder
    }

    Item {
        id: canvas
        anchors.fill: parent
        anchors.margins: 14

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
                canvasScaleFactor: canvas.scaleFactor
                canvasOffset: canvas.offset
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: hintText.implicitWidth + 20
        height: 24
        radius: SettingsTokens.radius
        color: SettingsTokens.button
        border.width: 1
        border.color: SettingsTokens.buttonBorder

        StyledText {
            id: hintText
            anchors.centerIn: parent
            text: "Drag displays to rearrange"
            color: SettingsTokens.muted
            font.pixelSize: 11
        }
    }
}
