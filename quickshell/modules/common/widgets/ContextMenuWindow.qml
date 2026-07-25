pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root

    default property alias content: columnLayout.data

    property real outerPadding: Appearance.sizes.elevationMargin
    property real menuPadding: 4

    signal menuClosed()

    color: "transparent"

    implicitWidth: popupBackground.implicitWidth + root.outerPadding * 2
    implicitHeight: popupBackground.implicitHeight + root.outerPadding * 2

    function open() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onDestruction: {
        dismissGuard.stop();
        GlobalFocusGrab.removeDismissable(root);
    }

    Timer {
        id: dismissGuard
        interval: 180
        repeat: false
        onTriggered: {
            if (root.visible)
                GlobalFocusGrab.addDismissable(root);
        }
    }

    onVisibleChanged: {
        if (visible) {
            dismissGuard.restart();
        } else {
            dismissGuard.stop();
            GlobalFocusGrab.removeDismissable(root);
        }
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            const pos = mapToItem(popupBackground, event.x, event.y)
            if (pos.x < 0 || pos.x > popupBackground.width || pos.y < 0 || pos.y > popupBackground.height)
                root.close();
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.outerPadding
            }
            color: TuiStyle.bg
            radius: TuiStyle.shellRadius
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.menuBorder
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: columnLayout.implicitWidth + root.menuPadding * 2
            implicitHeight: columnLayout.implicitHeight + root.menuPadding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(popupBackground)
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: 120 }
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(popupBackground)
            }

            ColumnLayout {
                id: columnLayout
                anchors {
                    fill: parent
                    margins: root.menuPadding
                }
                spacing: 0
            }
        }
    }
}
