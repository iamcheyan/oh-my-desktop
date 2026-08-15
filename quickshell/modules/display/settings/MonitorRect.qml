pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common

Rectangle {
    id: root

    required property var displayState
    required property var output
    required property real canvasScaleFactor
    required property point canvasOffset
    property bool selected: false
    signal outputSelected(string name)

    property bool dragging: false
    property point snappedLogical: Qt.point(displayState.draftFor(output.name).x, displayState.draftFor(output.name).y)
    property bool validPosition: true
    readonly property var draft: (displayState.revision, displayState.draftFor(output.name))
    readonly property var logicalSize: (displayState.revision, displayState.logicalSize(output))

    x: dragging ? x : draft.x * canvasScaleFactor + canvasOffset.x
    y: dragging ? y : draft.y * canvasScaleFactor + canvasOffset.y
    width: Math.max(64, logicalSize.w * canvasScaleFactor)
    height: Math.max(42, logicalSize.h * canvasScaleFactor)
    radius: SettingsTokens.radius
    color: !validPosition ? SettingsTokens.warningPanel : dragging ? SettingsTokens.accentSoft : (mouse.containsMouse ? SettingsTokens.cardHover : SettingsTokens.button)
    border.width: selected || dragging ? 2 : 1
    border.color: !validPosition ? SettingsTokens.danger : (selected || dragging ? SettingsTokens.accent : SettingsTokens.buttonBorder)
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
            color: root.selected ? SettingsTokens.accent : SettingsTokens.fg
        }

        StyledText {
            width: parent.width
            text: root.displayState.displayName(root.output)
            color: SettingsTokens.fg
            font.pixelSize: Math.max(10, Math.min(13, root.width * 0.09))
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        StyledText {
            width: parent.width
            text: `${root.logicalSize.w} x ${root.logicalSize.h}`
            color: SettingsTokens.muted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: displayState.visibleOutputs.length > 1
        hoverEnabled: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.threshold: 0

        onPressed: {
            root.outputSelected(root.output.name);
            root.dragging = true;
            root.snappedLogical = Qt.point(root.draft.x, root.draft.y);
            root.validPosition = true;
        }

        onPositionChanged: {
            if (!root.dragging)
                return;
            const rawX = Math.round((root.x - root.canvasOffset.x) / root.canvasScaleFactor);
            const rawY = Math.round((root.y - root.canvasOffset.y) / root.canvasScaleFactor);
            const snapped = root.displayState.snapToEdges(root.output.name, rawX, rawY, root.logicalSize.w, root.logicalSize.h);
            root.snappedLogical = snapped;
            root.validPosition = !root.displayState.checkOverlap(root.output.name, snapped.x, snapped.y, root.logicalSize.w, root.logicalSize.h);
        }

        onReleased: {
            if (!root.dragging)
                return;
            if (!root.validPosition) {
                root.dragging = false;
                return;
            }
            root.displayState.updatePosition(root.output.name, root.snappedLogical.x, root.snappedLogical.y);
            root.dragging = false;
        }
    }
}
