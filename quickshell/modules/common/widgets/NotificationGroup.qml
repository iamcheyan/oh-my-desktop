import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

MouseArea {
    id: root
    property var notificationGroup
    property var notifications: notificationGroup?.notifications ?? []
    property int notificationCount: notifications.length
    property bool expanded: false
    property bool popup: false
    property real dragConfirmThreshold: 70
    property real dismissOvershoot: 20
    property var qmlParent: root?.parent?.parent
    property var parentDragIndex: qmlParent?.dragIndex
    property var parentDragDistance: qmlParent?.dragDistance
    property var dragIndexDiff: Math.abs(parentDragIndex - index)
    property real xOffset: dragIndexDiff == 0 ? parentDragDistance :
        Math.abs(parentDragDistance) > dragConfirmThreshold ? 0 :
        dragIndexDiff == 1 ? (parentDragDistance * 0.3) :
        dragIndexDiff == 2 ? (parentDragDistance * 0.1) : 0
    readonly property bool isCritical: root.notifications.some(n =>
        n.urgency == NotificationUrgency.Critical || n.urgency == NotificationUrgency.Critical.toString())

    implicitHeight: frame.implicitHeight
    hoverEnabled: true

    function destroyWithAnimation(left = false) {
        root.qmlParent.resetDrag();
        frame.anchors.leftMargin = frame.anchors.leftMargin;
        destroyAnimation.left = left;
        destroyAnimation.running = true;
    }

    function toggleExpanded() {
        root.expanded = !root.expanded;
    }

    onContainsMouseChanged: {
        if (!root.popup)
            return;
        if (root.containsMouse)
            root.notifications.forEach(notif => Notifications.cancelTimeout(notif.notificationId));
        else
            root.notifications.forEach(notif => Notifications.timeoutNotification(notif.notificationId));
    }

    SequentialAnimation {
        id: destroyAnimation
        property bool left: true
        running: false

        NumberAnimation {
            target: frame.anchors
            property: "leftMargin"
            to: (root.width + root.dismissOvershoot) * (destroyAnimation.left ? -1 : 1)
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
        onFinished: root.notifications.forEach(notif =>
            Qt.callLater(() => Notifications.discardNotification(notif.notificationId)))
    }

    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: {
            if (mouse.button === Qt.RightButton)
                root.toggleExpanded();
        }

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                root.destroyWithAnimation();
        }

        onDraggingChanged: {
            if (dragging)
                root.qmlParent.dragIndex = root.index ?? root.parent.children.indexOf(root);
        }

        onDragDiffXChanged: root.qmlParent.dragDistance = dragDiffX

        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > root.dragConfirmThreshold)
                root.destroyWithAnimation(diffX < 0);
            else
                dragManager.resetDrag();
        }
    }

    Rectangle {
        id: frame
        anchors.left: parent.left
        anchors.leftMargin: root.xOffset
        width: parent.width
        radius: 0
        clip: true
        color: Appearance.tiling.bg
        border.width: Appearance.tiling.borderWidth
        border.color: root.isCritical ? Appearance.tiling.borderCritical : Appearance.tiling.border
        implicitHeight: titlebar.implicitHeight + notificationsColumn.implicitHeight

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.isCritical ? 2 : 0
            color: Appearance.tiling.error
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: titlebar
                Layout.fillWidth: true
                implicitHeight: Appearance.tiling.titlebarHeight
                radius: 0
                color: root.isCritical ? ColorUtils.mix(Appearance.tiling.error, Appearance.tiling.bgTitlebar, 0.78)
                    : Appearance.tiling.bgTitlebar

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 8 + (root.isCritical ? 4 : 0)
                        rightMargin: 4
                    }
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: notificationGroup?.appName || "notification"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.monospace
                        color: Appearance.tiling.textBright
                    }

                    StyledText {
                        visible: root.isCritical
                        text: "critical"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: Appearance.tiling.error
                    }

                    StyledText {
                        text: NotificationUtils.getFriendlyNotifTimeString(notificationGroup?.time)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: Appearance.tiling.textDim
                    }

                    NotificationGroupExpandButton {
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: Appearance.font.pixelSize.smaller
                        onClicked: root.toggleExpanded()
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 1
                    color: Appearance.tiling.border
                }
            }

            StyledListView {
                id: notificationsColumn
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                spacing: 0
                model: ScriptModel {
                    values: root.expanded
                        ? root.notifications.slice().reverse()
                        : root.notifications.slice().reverse().slice(0, 2)
                }
                delegate: NotificationItem {
                    required property int index
                    required property var modelData
                    notificationObject: modelData
                    expanded: root.expanded
                    onlyNotification: root.notificationCount === 1
                    opacity: (!root.expanded && index == 1 && root.notificationCount > 2) ? 0.55 : 1
                    visible: root.expanded || index < 2
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                }
            }
        }
    }
}
