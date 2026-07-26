pragma Singleton

import QtQuick
import qs.modules.common

// Shared placement contract for surfaces opened from the top/bottom bar.
// The window starts just outside the bar; the visual card starts after the
// common shadow/elevation allowance.
QtObject {
    // ── Canonical PopupAnchor block for bar context menus ──────────────
    // All right-click menus MUST use this pattern (goes on the
    // PopupWindow instance, typically via BarContextMenu):
    //
    //   anchor {
    //       window: button.QsWindow.window
    //       item: button
    //       gravity: Config.options.bar.vertical
    //           ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
    //           : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
    //       edges: Config.options.bar.vertical
    //           ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
    //           : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
    //       margins.top: Config.options.bar.bottom && !Config.options.bar.vertical
    //           ? menuAnchorGap(button.height) : barGap
    //       margins.bottom: !Config.options.bar.bottom && !Config.options.bar.vertical
    //           ? -(menuAnchorGap(button.height)) : barGap
    //       margins.left: barGap
    //       margins.right: rightGap
    //   }
    //
    // Visual card position (after the menu's own outerPadding):
    //   top bar: button.bottom + gap + outerPadding = 46 (default)
    //   ────────────────────────────────────────────

    readonly property real barGap: Appearance.sizes.barGap
    readonly property real rightGap: Appearance.sizes.rightGap
    readonly property real shadowMargin: Appearance.sizes.elevationMargin
    readonly property real windowTopMargin: Appearance.sizes.barHeight + barGap
    readonly property real visualTopMargin: windowTopMargin + shadowMargin

    // PopupAnchor margins move the anchor rectangle, not the popup's visual
    // border.  For a top bar the gap between button bottom and popup window
    // goes on margins.bottom (negative to expand the anchor rectangle away
    // from the button); for a bottom bar it goes on margins.top.
    //
    //   gap = (barHeight - itemHeight) / 2 + barGap
    //        = (32 - 28) / 2 + 4 = 6  (with defaults)
    //
    // ContextMenuWindow / SysTrayMenu add their own outerPadding (=elevationMargin=10)
    // inside the window, so the visual card lands at:
    //   button.bottom + gap + outerPadding = 30 + 6 + 10 = 46
    // which matches BarStatusPopup's visualTopMargin (windowTopMargin + shadowMargin).
    function menuAnchorGap(itemHeight) {
        return (Appearance.sizes.barHeight - itemHeight) / 2 + barGap
    }
}
