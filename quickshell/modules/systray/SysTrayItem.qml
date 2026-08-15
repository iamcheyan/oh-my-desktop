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

Item {
    id: root
    required property SystemTrayItem item
    property bool targetMenuOpen: false
    readonly property string searchableIdentity: [
        item.id,
        item.title,
        item.tooltipTitle,
        item.tooltipDescription
    ].join(" ").toLowerCase()
    readonly property var itemIconSource: (item.iconName && item.iconName.length > 0) ? item.iconName : (item.icon ?? "")
    readonly property string itemIconName: typeof itemIconSource === "string" ? itemIconSource : String(item.iconName ?? "")
    readonly property bool useNetworkFallbackIcon: itemIconName === "network-transmit"
    readonly property bool hasValidIcon: itemIconSource !== null && itemIconSource !== undefined && (typeof itemIconSource !== "string" || itemIconSource.length > 0)
    // Detect icon load failure.
    // Two paths:
    //   1. image://icon/X  — Qt 6 built-in handler runs QIcon::fromTheme(X)
    //      → theme miss produces Image.Error (catches WeChat et al.)
    //   2. image://qspixmap/... — via TrayImageHandle → createPixmap()
    //      → failure returns missingPixmap (valid full-size pixmap) → Image.Ready
    //      → QML cannot distinguish this from a real icon.
    //      Guard only the extreme case (provider returns sub-2px pixmap).
    readonly property bool iconLoadFailed: {
        if (!root.hasValidIcon) return false;
        if (trayIcon.status === Image.Error) return true;
        // IconImage is an Item wrapper with no sourceSize property; read the
        // size from its backing QtQuick.Image.
        if (trayIcon.status === Image.Ready
            && (trayIcon.backer.sourceSize.width <= 2 || trayIcon.backer.sourceSize.height <= 2))
            return true;
        return false;
    }
    readonly property string tooltipText: {
        var parts = [];
        var t = root.item.title || root.item.tooltipTitle || "";
        if (t) parts.push(t);
        if (root.item.tooltipDescription) parts.push(root.item.tooltipDescription);
        return parts.join("\n");
    }


    readonly property bool useInputKeyboardFallback: itemIconName === "input-keyboard-symbolic"
        || itemIconName === "input-keyboard"
        || itemIconName === "fcitx-keyboard"
        || (root.isInputMethod && (itemIconName === "" || itemIconName === "input-keyboard-symbolic"))

    readonly property bool isInputMethod: searchableIdentity.includes("fcitx")
        || searchableIdentity.includes("rime")
        || searchableIdentity.includes("ibus")
        || searchableIdentity.includes("input")

    readonly property bool useArrowIcon: searchableIdentity.includes("search")
        || searchableIdentity.includes("walker")
        || searchableIdentity.includes("main-tray")

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    implicitWidth: Appearance.sizes.rightIconSlotSize
    implicitHeight: Appearance.sizes.rightIconSlotSize

    RippleButton {
        id: button
        anchors.centerIn: parent
        width: Appearance.sizes.rightIconSlotSize
        height: Appearance.sizes.rightIconSlotSize
        buttonRadius: Appearance.sizes.rightIconSlotSize / 2
        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: menu.active

        onClicked: {
            item.activate();
        }

        altAction: function(event) {
            if (item.hasMenu) {
                if (menu.active && menu.item && typeof menu.item.close === "function")
                    menu.item.close();
                else 
                    menu.open();
            }
        }
    }

    BarContextMenu {
        id: menu
        anchorItem: button
        sourceComponent: SysTrayMenu {
            trayItemMenuHandle: root.item.menu
            trayItemId: root.item.id
            onMenuOpened: (window) => root.menuOpened(window)
            onMenuClosed: () => root.menuClosed()
        }
    }

    IconImage {
        id: trayIcon
        visible: !root.useArrowIcon && !root.useNetworkFallbackIcon && !root.useInputKeyboardFallback && root.hasValidIcon && !root.iconLoadFailed && trayIcon.status === Image.Ready
        // Keep the source visible. The monochrome effect is rendered by the
        // overlay below; hiding the source makes that overlay blank as well.
        opacity: 1
        source: root.itemIconSource
        anchors.centerIn: button
        width: Math.round(Appearance.sizes.rightIconSize * 0.82)
        height: Math.round(Appearance.sizes.rightIconSize * 0.82)
    }


    MaterialSymbol {
        visible: root.useArrowIcon || root.useNetworkFallbackIcon || root.useInputKeyboardFallback
        anchors.centerIn: button
        text: root.useInputKeyboardFallback ? "keyboard" : (root.useNetworkFallbackIcon ? "sync_alt" : "arrow_forward")
        iconSize: Math.round(Appearance.sizes.rightIconSize * 0.82)
        color: Appearance.colors.colBarText
    }

    /// Fallback: tray item without valid icon → show downward arrow
    MaterialSymbol {
        visible: !root.useArrowIcon && !root.useNetworkFallbackIcon && !root.useInputKeyboardFallback && !root.hasValidIcon
        anchors.centerIn: button
        text: root.isInputMethod ? "keyboard" : "expand_more"
        iconSize: Math.round(Appearance.sizes.rightIconSize * 0.82)
        color: Appearance.colors.colBarText
    }

    Loader {
        active: !root.useArrowIcon && !root.useNetworkFallbackIcon && !root.useInputKeyboardFallback && root.hasValidIcon && !root.iconLoadFailed && trayIcon.status === Image.Ready && Config.options.tray.monochromeIcons
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

    // Also covers invalid icon names, not only providers that omit an icon.
    MaterialSymbol {
        visible: !root.useArrowIcon && !root.useNetworkFallbackIcon && !root.useInputKeyboardFallback
            && (!root.hasValidIcon || root.iconLoadFailed)
        anchors.centerIn: button
        text: root.isInputMethod ? "keyboard" : "apps"
        iconSize: Math.round(Appearance.sizes.rightIconSize * 0.82)
        color: Appearance.colors.colBarText
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: button.hovered && root.tooltipText.length > 0
        alternativeVisibleCondition: extraVisibleCondition
        text: root.tooltipText
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
