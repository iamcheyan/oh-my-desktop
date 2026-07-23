import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

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
            root.notifications.forEach(notif => ServiceManager.notification.cancelTimeout(notif.notificationId));
        else
            root.notifications.forEach(notif => ServiceManager.notification.timeoutNotification(notif.notificationId));
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
            Qt.callLater(() => ServiceManager.notification.discardNotification(notif.notificationId)))
    }

    DragManager {
        id: dragManager
        anchors.fill: parent
        interactive: !root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.RightButton | Qt.MiddleButton

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

    readonly property bool singleNotification: root.notificationCount === 1

    Rectangle {
        id: frame
        anchors.left: parent.left
        anchors.leftMargin: root.xOffset
        width: parent.width
        radius: TuiStyle.shellRadius
        clip: true
        color: TuiStyle.bg
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.menuBorder
        implicitHeight: titlebar.implicitHeight + notificationsColumn.implicitHeight

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                id: titlebar
                Layout.fillWidth: true
                visible: !root.singleNotification
                implicitHeight: visible ? 28 : 0

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 10
                    }
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: notificationGroup?.appName || "notification"
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: TuiStyle.fg
                    }

                    StyledText {
                        visible: root.isCritical
                        text: "critical"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.main
                        color: TuiStyle.danger
                    }

                    StyledText {
                        text: NotificationUtils.getFriendlyNotifTimeString(notificationGroup?.time)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.main
                        color: TuiStyle.dim
                    }

                    NotificationGroupExpandButton {
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: Appearance.font.pixelSize.smaller
                        onClicked: root.toggleExpanded()
                    }
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
                    opacity: (!root.expanded && index == 1 && root.notificationCount > 2) ? 0.5 : 1
                    visible: root.expanded || index < 2
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                }
            }
        }
    }
}
