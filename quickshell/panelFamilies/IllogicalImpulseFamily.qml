import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.appLauncher
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.schedulePopup
import qs.modules.ii.screenCorners
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarRight

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
    PanelLoader { component: SchedulePopup {} }
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
        component: SidebarRight {}
    }

    // Tier 2 — 低频或重型模块
    PanelLoader {
        loadTier: 2
        tier1Ready: family.tier1Ready
        tier2Ready: family.tier2Ready
        component: MediaControls {}
    }
}
