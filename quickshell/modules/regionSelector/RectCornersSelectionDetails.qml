import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    required property real regionX
    required property real regionY
    required property real regionWidth
    required property real regionHeight
    required property real mouseX
    required property real mouseY
    required property color color
    required property color overlayColor
    property bool showAimLines: Config.options.regionSelector.rect.showAimLines
    property bool captureReady: true

    property bool breathingBorderOnly: false

    readonly property real safeX: Math.max(0, Math.min(root.regionX, root.width))
    readonly property real safeY: Math.max(0, Math.min(root.regionY, root.height))
    readonly property real safeRight: Math.max(root.safeX, Math.min(root.regionX + root.regionWidth, root.width))
    readonly property real safeBottom: Math.max(root.safeY, Math.min(root.regionY + root.regionHeight, root.height))
    readonly property bool showOverlay: root.captureReady && !root.breathingBorderOnly

    // Four simple rectangles avoid the full-screen-width border previously
    // rebuilt for every pointer movement.
    Rectangle {
        z: 1
        visible: root.showOverlay
        x: 0
        y: 0
        width: root.width
        height: root.safeY
        color: root.overlayColor
    }
    Rectangle {
        z: 1
        visible: root.showOverlay
        x: 0
        y: root.safeBottom
        width: root.width
        height: Math.max(0, root.height - root.safeBottom)
        color: root.overlayColor
    }
    Rectangle {
        z: 1
        visible: root.showOverlay
        x: 0
        y: root.safeY
        width: root.safeX
        height: Math.max(0, root.safeBottom - root.safeY)
        color: root.overlayColor
    }
    Rectangle {
        z: 1
        visible: root.showOverlay
        x: root.safeRight
        y: root.safeY
        width: Math.max(0, root.width - root.safeRight)
        height: Math.max(0, root.safeBottom - root.safeY)
        color: root.overlayColor
    }

    DashedBorder {
        id: selectionBorder
        z: 9
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: Math.round(root.regionX) - borderWidth
            topMargin: Math.round(root.regionY) - borderWidth
        }
        width: Math.round(root.regionWidth) + borderWidth * 2
        height: Math.round(root.regionHeight) + borderWidth * 2

        color: root.color
        dashLength: 8
        gapLength: 4
        borderWidth: 1

        // Breathing (disabled)
        opacity: 0.9
    }

    StyledText {
        z: 2
        visible: !root.breathingBorderOnly
        anchors {
            top: selectionBorder.bottom
            right: selectionBorder.right
            margins: 8
        }
        color: root.color
        text: `${Math.round(root.regionWidth)} x ${Math.round(root.regionHeight)}`
    }

    // Coord lines
    Rectangle { // Vertical
        visible: root.showAimLines && !root.breathingBorderOnly
        opacity: 0.2
        z: 2
        x: root.mouseX
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        width: 1
        color: root.color
    }
    Rectangle { // Horizontal
        visible: root.showAimLines && !root.breathingBorderOnly
        opacity: 0.2
        z: 2
        y: root.mouseY
        anchors {
            left: parent.left
            right: parent.right
        }
        height: 1
        color: root.color
    }
}
