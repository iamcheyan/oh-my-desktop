pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

/**
 * Shared context menu launcher for bar buttons.
 *
 * Centralizes PopupAnchor positioning and lifecycle for ALL bar context
 * menus — modules/extensions only provide menu content, never the anchor
 * boilerplate.
 *
 * ── Standard usage (ContextMenuWindow subclass) ─────────────────────────
 *   BarContextMenu {
 *       anchorItem: button
 *       sourceComponent: PowerContextMenu {
 *           ContextMenuItem { labelText: "…" }
 *       }
 *   }
 *
 * ── Custom PopupWindow (SysTrayMenu renders QsMenuHandle, not QML items) ─
 *   BarContextMenu {
 *       anchorItem: button
 *       sourceComponent: SysTrayMenu {
 *           trayItemMenuHandle: …
 *       }
 *   }
 *
 * Opens on demand via open().  Auto-closes and unloads when the menu emits
 * menuClosed.
 */
Loader {
    id: root

    /// Required: the bar button to anchor the menu to
    required property Item anchorItem

    /// Captured at open() time for gap calculation, avoiding layout-timing issues.
    property real _openHeight: 0

    active: false

    function open() {
        _openHeight = anchorItem ? anchorItem.height : 0;
        if (root.item != null) {
            root.item.open();
        } else {
            root.active = true;
        }
    }

    onLoaded: {
        const menu = root.item;
        if (!menu || !menu.anchor) return;

        // PopupAnchor positioning — canonical block shared by all bar menus.
        menu.anchor.window = anchorItem.QsWindow.window;
        menu.anchor.item = anchorItem;
        menu.anchor.gravity = Config.options.bar.vertical
            ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
            : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom);
        menu.anchor.edges = Config.options.bar.vertical
            ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
            : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom);

        // Margins — see BarPopupGeometry.menuAnchorGap() for the contract.
        // Uses _openHeight captured at click-time when layout is guaranteed done.
        const gap = BarPopupGeometry.menuAnchorGap(root._openHeight);
        menu.anchor.margins.top = Config.options.bar.bottom && !Config.options.bar.vertical
            ? gap : BarPopupGeometry.barGap;
        menu.anchor.margins.bottom = !Config.options.bar.bottom && !Config.options.bar.vertical
            ? -gap : BarPopupGeometry.barGap;
        menu.anchor.margins.left = BarPopupGeometry.barGap;
        menu.anchor.margins.right = BarPopupGeometry.rightGap;

        menu.open();

        // Unload Loader when the menu closes, so a subsequent open()
        // re-creates a fresh component with current config/anchor bindings.
        menu.menuClosed.connect(() => { root.active = false; });
    }
}
