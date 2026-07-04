import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var state
    required property var output
    required property real canvasScaleFactor
    required property point canvasOffset

    property bool dragging: false
    property point snappedLogical: Qt.point(state.draftFor(output.name).x, state.draftFor(output.name).y)
    property bool validPosition: true
    readonly property var draft: (state.revision, state.draftFor(output.name))
    readonly property var logicalSize: (state.revision, state.logicalSize(output))

    x: dragging ? x : draft.x * canvasScaleFactor + canvasOffset.x
    y: dragging ? y : draft.y * canvasScaleFactor + canvasOffset.y
    width: Math.max(64, logicalSize.w * canvasScaleFactor)
    height: Math.max(42, logicalSize.h * canvasScaleFactor)
    radius: 10
    color: !validPosition ? "#3a2020" : dragging ? TuiStyle.accentWash(TuiStyle.accent) : (mouse.containsMouse ? "#303030" : "#242424")
    border.width: output.focused || dragging ? 2 : 1
    border.color: !validPosition ? "#d0d0d0" : (output.focused || dragging ? TuiStyle.accent : "#777777")
    z: dragging ? 10 : 1

    Rectangle {
        visible: root.dragging && root.validPosition
        x: root.snappedLogical.x * root.canvasScaleFactor + root.canvasOffset.x - root.x
        y: root.snappedLogical.y * root.canvasScaleFactor + root.canvasOffset.y - root.y
        width: parent.width
        height: parent.height
        radius: parent.radius
        color: "transparent"
        border.width: 2
        border.color: TuiStyle.accent
        opacity: 0.5
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 18
        spacing: 4

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "desktop_windows"
            iconSize: Math.min(26, Math.max(16, parent.width * 0.14))
            color: output.focused ? TuiStyle.accent : "#d8d8d8"
        }

        StyledText {
            width: parent.width
            text: root.state.displayName(root.output)
            color: "#f4f4f4"
            font.pixelSize: Math.max(10, Math.min(13, root.width * 0.09))
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        StyledText {
            width: parent.width
            text: `${root.logicalSize.w} x ${root.logicalSize.h}`
            color: "#a8a8a8"
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.threshold: 0

        onPressed: {
            root.dragging = true;
            root.snappedLogical = Qt.point(root.draft.x, root.draft.y);
            root.validPosition = true;
        }

        onPositionChanged: {
            if (!root.dragging)
                return;
            const rawX = Math.round((root.x - root.canvasOffset.x) / root.canvasScaleFactor);
            const rawY = Math.round((root.y - root.canvasOffset.y) / root.canvasScaleFactor);
            const snapped = root.state.snapToEdges(root.output.name, rawX, rawY, root.logicalSize.w, root.logicalSize.h);
            root.snappedLogical = snapped;
            root.validPosition = !root.state.checkOverlap(root.output.name, snapped.x, snapped.y, root.logicalSize.w, root.logicalSize.h);
        }

        onReleased: {
            if (!root.dragging)
                return;
            root.dragging = false;
            if (!root.validPosition)
                return;
            root.state.updatePosition(root.output.name, root.snappedLogical.x, root.snappedLogical.y);
        }
    }
}
