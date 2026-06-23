import QtQuick
import Quickshell

import qs.modules.common

LazyLoader {
    property bool extraCondition: true
    // 0 = 立即加载；1/2 = 分档延迟（需父级传入 tier1Ready / tier2Ready）
    property int loadTier: 0
    property bool tier1Ready: true
    property bool tier2Ready: true

    readonly property bool staggerEnabled: Config.options?.startup?.staggerPanelLoading ?? true
    readonly property bool tierReady: {
        if (!staggerEnabled)
            return true
        if (loadTier <= 0)
            return true
        if (loadTier === 1)
            return tier1Ready
        return tier2Ready
    }

    active: Config.ready && extraCondition && tierReady
}
