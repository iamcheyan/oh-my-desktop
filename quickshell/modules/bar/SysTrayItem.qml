pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

MouseArea {
    id: root
    required property SystemTrayItem item
    property bool targetMenuOpen: false
    readonly property string searchableIdentity: [
        item.id,
        item.title,
        item.tooltipTitle,
        item.tooltipDescription
    ].join(" ").toLowerCase()
    readonly property string itemIconName: String(item.icon ?? "")
    readonly property bool useArrowIcon: searchableIdentity.includes("search")
        || searchableIdentity.includes("walker")
        || searchableIdentity.includes("main-tray")
    readonly property bool useNetworkFallbackIcon: itemIconName === "network-transmit"

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu)
                if (menu.active && menu.item && typeof menu.item.close === "function")
                    menu.item.close();
                else 
                    menu.open();
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        tooltip.text = TrayService.getTooltipForItem(root.item);
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            trayItemId: root.item.id
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon
        visible: !root.useArrowIcon && !root.useNetworkFallbackIcon && !Config.options.tray.monochromeIcons
        source: visible ? root.itemIconName : ""
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSize
        height: Config.options.bar.rightIconSize
    }

    MaterialSymbol {
        visible: root.useArrowIcon || root.useNetworkFallbackIcon
        anchors.centerIn: parent
        text: root.useNetworkFallbackIcon ? "sync_alt" : "arrow_forward"
        iconSize: Config.options.bar.rightIconSize
        color: Appearance.colors.colBarText
    }

    Loader {
        active: !root.useArrowIcon && !root.useNetworkFallbackIcon && Config.options.tray.monochromeIcons
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false
                anchors.fill: parent
                source: trayIcon
                desaturation: 0.8
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: Appearance.colors.colBarText
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

}
