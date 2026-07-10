pragma Singleton

import QtQuick
import qs.modules.common
import qs.services

/**
 * Settings Center palette — cosmic-style tokens mapped from TuiStyle / OmarchyTheme.
 * Shell widgets and pages should use these instead of hard-coded colors or root.cosmic*.
 */
QtObject {
    id: root

    readonly property color bg: TuiStyle.surfaceSubtle
    readonly property color panel: TuiStyle.surfaceHover
    readonly property color panelAlt: TuiStyle.surfaceRaised
    readonly property color panelHover: TuiStyle.surfacePressed
    readonly property color card: TuiStyle.surfacePressed
    readonly property color cardHover: TuiStyle.controlHover
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

    readonly property int radius: 8
    readonly property int roundRadius: 12

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }
}