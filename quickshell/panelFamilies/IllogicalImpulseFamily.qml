import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.appLauncher
import qs.modules.background
import qs.modules.bar
import qs.modules.cheatsheet
import qs.modules.lock
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.controlCenter

Scope {
    id: family

    readonly property bool staggerPanels: Config.options?.startup?.staggerPanelLoading ?? true
    property bool tier1Ready: !family.staggerPanels
    property bool tier2Ready: !family.staggerPanels

    Timer {
        interval: Config.options?.startup?.tier1DelayMs ?? 1500
        running: Config.ready && family.staggerPanels
        repeat: false
        onTriggered: family.tier1Ready = true
    }

    Timer {
        interval: Config.options?.startup?.tier2DelayMs ?? 6000
        running: Config.ready && family.staggerPanels
        repeat: false
        onTriggered: family.tier2Ready = true
    }

    // Tier 0 — 立即可见的核心 UI
    PanelLoader { component: Bar {} }
    PanelLoader { component: Background {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: NotificationPopup {} }
    PanelLoader { component: Lock {} }

    // Tier 1 — 含全局快捷键，略延迟以让出 CPU
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Overview {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: AppLauncher {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: RegionSelector {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: SessionScreen {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Cheatsheet {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: BarDialogOverlay {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: Polkit {}
    }
    PanelLoader {
        loadTier: 1
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: ControlCenter {}
    }

    // Tier 2 — 低频或重型模块
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: MediaControls {}
    }
}
