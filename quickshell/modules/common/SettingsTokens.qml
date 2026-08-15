pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

/**
 * Settings Center palette — cosmic-style tokens mapped from TuiStyle / OmarchyTheme.
 * Shell widgets and pages should use these instead of hard-coded colors or root.cosmic*.
 */
QtObject {
    id: root

    readonly property color bg: TuiStyle.bg
    readonly property color panel: TuiStyle.panel
    readonly property color panelAlt: TuiStyle.panelAlt
    readonly property color panelHover: TuiStyle.surfaceHover
    readonly property color card: TuiStyle.panel
    readonly property color cardHover: TuiStyle.surfaceHover
    readonly property color button: TuiStyle.control
    readonly property color buttonHover: TuiStyle.controlHover
    readonly property color buttonActive: TuiStyle.accentWash(TuiStyle.accent)
    readonly property color buttonBorder: TuiStyle.line
    readonly property color fg: TuiStyle.fg
    readonly property color muted: TuiStyle.muted
    readonly property color dim: TuiStyle.dim
    readonly property color line: TuiStyle.line
    readonly property color accent: TuiStyle.accent
    readonly property color accentSoft: OmarchyTheme.accentSoft
    readonly property color danger: TuiStyle.danger
    readonly property color warningPanel: TuiStyle.dangerPanel
    readonly property color warningBorder: TuiStyle.line

    readonly property int radius: 4
    readonly property int roundRadius: 6

    // Shared settings layout geometry. Pages should compose these tokens
    // instead of compensating locally with one-off margins.
    readonly property int shellInset: 6
    readonly property int pagePadding: 16
    readonly property int panelPadding: 16
    readonly property int columnGap: 16
    readonly property int sectionGap: 14
    readonly property int controlGap: 12
    readonly property int controlHeight: 42
    // The content viewport contributes pagePadding above the footer. The
    // footer reserves the same amount below its fixed-height button row. Half
    // the shell inset balances the frame space that otherwise appears only
    // above the footer boundary.
    readonly property int footerBalanceOffset: Math.round(shellInset / 2)
    readonly property int footerHeight: controlHeight + pagePadding + footerBalanceOffset
    readonly property int footerButtonWidth: 120
    readonly property int footerCloseButtonWidth: 110

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }
}
