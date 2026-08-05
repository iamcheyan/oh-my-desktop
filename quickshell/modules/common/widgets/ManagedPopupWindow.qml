pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

// ManagedPopupWindow — PopupWindow with shared lifecycle management.
// Provides: dismiss guard, GlobalFocusGrab integration, click-outside-to-close,
// fade-in animation, StyledRectangularShadow, popupBackground Rectangle.
//
// Subclass or use directly by setting the `content` default property.
// Override `close()` if you need custom cleanup.
//
// Unlike ContextMenuWindow, does NOT register with ContextMenuTracker.
//
// Hover state: `hovered` is true while the pointer is over the visible menu
// card. Context-menu mnemonic binds (routed through Hyprland → ActionManager)
// check this so a letter key only activates when the user is pointing at the
// menu, never while they are typing elsewhere.
PopupWindow {
    id: root

    default property alias content: columnLayout.data
    /// true while the pointer is over the popupBackground card.
    readonly property bool hovered: menuHover.hovered


    signal popupClosed()

    color: "transparent"

    property real outerPadding: Appearance.sizes.elevationMargin
    property real menuPadding: 6

    implicitWidth: popupBackground.implicitWidth + root.outerPadding * 2
    implicitHeight: popupBackground.implicitHeight + root.outerPadding * 2

    function open() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.popupClosed();
    }

    // ── Dismiss guard ──
    // Delay registering dismissable to avoid click-on-open being mis-detected as "click outside"
    Timer {
        id: dismissGuard
        interval: 50
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

    Component.onDestruction: {
        dismissGuard.stop();
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() { root.close() }
    }

    // ── Click outside to close ──
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
            HoverHandler {
                id: menuHover
                grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.CanTakeOverFromAnything
            }

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: columnLayout.implicitWidth + root.menuPadding * 2
            implicitHeight: columnLayout.implicitHeight + root.menuPadding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(popupBackground)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(popupBackground)
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
