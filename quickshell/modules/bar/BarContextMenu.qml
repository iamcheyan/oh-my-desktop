pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * BarContextMenu — shared container for all bar context menus.
 *
 * Usage:
 *   BarContextMenu {
 *       id: myMenu
 *       // add BarContextMenuItem children inside the default property
 *   }
 *
 * Style tokens are defined here as readonly properties.
 * To change the look of ALL menus, edit this file only.
 */
PopupWindow {
    id: barContextMenu

    // ── Style tokens ────────────────────────────────────────────────────────
    readonly property int   itemHeight:      TuiStyle.rowHeight  // row height (aligned to standard 38px)
    readonly property int   itemRadius:       5   // row corner radius
    readonly property int   iconColumnWidth: 26   // icon cell width
    readonly property int   iconSize:        18   // icon render size
    readonly property int   itemSpacing:      2   // gap between rows
    readonly property real  hPadding:         8   // left/right padding inside each row
    readonly property real  menuPadding:      6   // inner padding of menu background
    readonly property real  outerPadding:     Appearance.sizes.elevationMargin + 2   // space between window edge and background
    readonly property int   separatorMargin:  4   // top/bottom margin around separators
    // ────────────────────────────────────────────────────────────────────────

    // Public API
    property string menuName: ""
    property real popupBackgroundMargin: 0
    signal menuClosed()

    // Default property: children go into the ColumnLayout
    default property alias menuItems: columnLayout.children

    color: "transparent"
    visible: GlobalStates.activeContextMenu !== "" && GlobalStates.activeContextMenu === menuName

    implicitWidth:  popupBackground.implicitWidth  + barContextMenu.outerPadding * 2 + barContextMenu.popupBackgroundMargin
    implicitHeight: popupBackground.implicitHeight + barContextMenu.outerPadding * 2 + barContextMenu.popupBackgroundMargin

    function open()  {
        GlobalStates.barPopupType = "";
        GlobalStates.activeContextMenu = menuName;
    }
    function close() {
        if (GlobalStates.activeContextMenu === menuName) {
            GlobalStates.activeContextMenu = "";
        }
        barContextMenu.menuClosed();
    }

    Component.onDestruction: {
        if (GlobalStates.activeContextMenu === menuName) {
            GlobalStates.activeContextMenu = "";
        }
        dismissGuard.stop();
        GlobalFocusGrab.removeDismissable(barContextMenu);
    }

    Timer {
        id: dismissGuard
        interval: 180
        repeat: false
        onTriggered: {
            if (barContextMenu.visible)
                GlobalFocusGrab.addDismissable(barContextMenu);
        }
    }

    onVisibleChanged: {
        if (visible) {
            dismissGuard.restart();
        } else {
            dismissGuard.stop();
            GlobalFocusGrab.removeDismissable(barContextMenu);
        }
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() { barContextMenu.close() }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            if (event.button === Qt.RightButton)
                barContextMenu.close();
        }

        StyledRectangularShadow {
            target:  popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            anchors {
                left:    parent.left
                right:   parent.right
                top:     parent.top
                margins: barContextMenu.outerPadding
            }
            color:        TuiStyle.bg
            radius:       TuiStyle.shellRadius // unified rounded corners from design system
            border.width: TuiStyle.borderWidth // unified border stroke from design system
            border.color: TuiStyle.shellBorder
            clip:         true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth:  columnLayout.implicitWidth  + barContextMenu.menuPadding * 2
            implicitHeight: columnLayout.implicitHeight + barContextMenu.menuPadding * 2

            Behavior on opacity       { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            Behavior on implicitHeight { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }
            Behavior on implicitWidth  { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

            ColumnLayout {
                id: columnLayout
                anchors {
                    fill:    parent
                    margins: barContextMenu.menuPadding
                }
                spacing: barContextMenu.itemSpacing
            }
        }
    }
}
