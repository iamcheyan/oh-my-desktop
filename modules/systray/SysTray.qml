import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property alias trayModel: trayRepeater.model

    readonly property var trayItems: TrayService.trayItems
    readonly property var trayFiltered: {
        const wantedKeys = Config.options.tray.hiddenIcons ?? [];
        const wantPinned = Config.options.tray.showPinnedOnly ?? false;
        let result = { pinned: [], unpinned: [] };

        for (let i = 0; i < root.trayItems.length; i++) {
            const item = root.trayItems[i];
            if (wantPinned || TrayService.isPinned(item.id)) {
                item._isPinned = true;
                result.pinned.push(item);
            } else {
                item._isPinned = false;
                result.unpinned.push(item);
            }
        }
        return result;
    }

    readonly property var modelPinned: root.trayFiltered.pinned
    readonly property var modelUnpinned: root.trayFiltered.unpinned

    readonly property int overflowItemCount: root.modelUnpinned.length
    readonly property bool overflowMenuOpen: statusButtonLoader.active
        && (statusButtonLoader.item?.toggled ?? false)

    readonly property int trayIconCount: root.trayFiltered.pinned.length

    Binding on visible {
        value: root.trayFiltered.pinned.length > 0 || root.trayFiltered.unpinned.length > 0
        when: !Config.options.tray.showOnlyWhenVisible
    }

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: Config.options.bar.trayIconSpacing

        Repeater {
            id: trayRepeater
            model: root.modelPinned
            delegate: SysTrayItem {
                required property var modelData
                item: modelData
                onMenuClosed: root.hideOverflowMenu()
            }
        }

        Loader {
            id: statusButtonLoader
            active: root.overflowItemCount > 0
            sourceComponent: RippleButton {
                implicitWidth: Config.options.bar.rightIconSlotWidth
                implicitHeight: Config.options.bar.rightIconSlotWidth
                buttonRadius: Config.options.bar.rightIconSlotWidth / 2
                colBackground: "transparent"
                colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
                colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
                colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
                colRipple: Qt.rgba(1, 1, 1, 0.12)
                colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
                toggled: overflowMenuActive

                onClicked: {
                    if (overflowMenuActive) {
                        root.hideOverflowMenu();
                    } else {
                        root.showOverflowMenu();
                    }
                }

                contentItem: BarNerdIcon {
                    text: NerdIconMap.greaterThan
                    color: Appearance.colors.colBarText
                }
            }
        }
    }

    readonly property bool overflowMenuActive: overflowMenu?.active ?? false

    property var overflowMenu: null

    function showOverflowMenu() {
        if (overflowMenu) {
            overflowMenu.active = true;
            overflowMenu.item.open();
        }
    }

    function hideOverflowMenu() {
        if (overflowMenu) {
            if (overflowMenu.item) {
                overflowMenu.item.close();
            }
        }
    }

    onModelUnpinnedChanged: {
        if (root.modelUnpinned.length === 0)
        {
            root.hideOverflowMenu();
        }
    }

    Loader {
        id: overflowMenu
        active: false
        sourceComponent: TrayOverflowPopup {
            trayItems: root.modelUnpinned
            anchor {
                window: root.QsWindow.window
                item: statusButtonLoader.item ?? root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                overflowMenu.active = false;
            }
        }
    }

    component TrayOverflowPopup: PopupWindow {
        id: trayOverflowPopup
        required property var trayItems
        color: "transparent"

        signal menuClosed()

        property real outerPadding: Appearance.sizes.elevationMargin

        function open() {
            trayOverflowPopup.visible = true;
        }

        function close() {
            trayOverflowPopup.visible = false;
            trayOverflowPopup.menuClosed();
        }

        implicitWidth: popupBackground.implicitWidth + outerPadding * 2
        implicitHeight: popupBackground.implicitHeight + outerPadding * 2

        onVisibleChanged: {
            if (!visible) trayOverflowPopup.menuClosed();
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: event => {
                const pos = mapToItem(popupBackground, event.x, event.y)
                if (pos.x < 0 || pos.x > popupBackground.width || pos.y < 0 || pos.y > popupBackground.height)
                    trayOverflowPopup.close();
            }

            StyledRectangularShadow {
                target: popupBackground
                opacity: popupBackground.opacity
            }

            Rectangle {
                id: popupBackground
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: trayOverflowPopup.outerPadding
                }
                color: TuiStyle.bg
                radius: TuiStyle.shellRadius
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.menuBorder
                clip: true

                opacity: 0
                Component.onCompleted: opacity = 1
                implicitWidth: columnLayout.implicitWidth + 12
                implicitHeight: columnLayout.implicitHeight + 12

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                ColumnLayout {
                    id: columnLayout
                    anchors {
                        fill: parent
                        margins: 6
                    }
                    spacing: 2

                    Repeater {
                        model: trayItems
                        delegate: SysTrayItem {
                            required property var modelData
                            item: modelData
                            onMenuClosed: trayOverflowPopup.close()
                        }
                    }
                }
            }
        }
    }
}
