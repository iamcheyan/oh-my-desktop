//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs.core.runtime
import qs.services
import qs.modules.common
import qs

import qs.modules.bar

import qs.modules.lock
import qs.modules.powerIndicator

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.modules.common.widgets

ShellRoot {
    id: root

    // Esc closes active menus — Hyprland binds ESCAPE to 'dispatch exec qs -p ... ipc call menus close'
    IpcHandler {
        target: "menus"

        function close(): void {
            if (GlobalStates.barPopupType !== "") {
                GlobalStates.barPopupType = "";
            }
            // Context menus are PopupWindows tracked separately from barPopupType.
            if (ContextMenuTracker.activeMenu)
                ContextMenuTracker.activeMenu.close();
            GlobalFocusGrab.dismiss();
        }
    }


    // Session actions requested by independent Quickshell processes (for
    // example the Overview command palette) reuse the bar's confirmation UI.
    IpcHandler {
        target: "session"

        function confirm(action: string, label: string): void {
            GlobalStates.requestSessionConfirm(action, label)
        }
    }

    Component.onCompleted: {
        ApplicationManager.initialize()
        // Overview is a separate on-demand qs process. Without pre-warming,
        // the first open after boot pays the full cold-start cost (registry
        // regen + QML compile + per-screen widget tree) and the very first
        // click only spawns the process hidden. Pre-warm it shortly after
        // the bar is up so the first user-triggered open is instant. The
        // overview keepAliveWindow then keeps the process alive.
        // labwc 会话彻底禁用 overview（workspaces 模块切换到 labwc 原生
        // client-list-combined-menu），不预热。
        if (Quickshell.env("XDG_CURRENT_DESKTOP") !== "labwc")
            overviewPreWarmTimer.start()
    }

    Timer {
        id: overviewPreWarmTimer
        interval: 1500
        repeat: false
        onTriggered: Quickshell.execDetached([Directories.root + "/bin/sumika-overview", "warm"])
    }

    // Create top-level windows immediately. Gating this scope on Config.ready
    // lets Quickshell exit during cold login/reload before any window exists.
    // Core bar infrastructure — always present.
    Scope {
        Bar {}
        Lock {}
        BarDismissLayer {}
        ModuleActionHost {}
        BarStatusPopup {}

        SessionAutoRestore {}

        // NotificationServer MUST be inside ShellRoot context to claim org.freedesktop.Notifications
        // (nesting inside a Singleton like Services.Notifications doesn't work).
        // It delegates to the Notifications service singleton for processing.
        NotificationServer {
            id: notifServer
            actionsSupported: true
            bodyHyperlinksSupported: true
            bodyImagesSupported: true
            bodyMarkupSupported: true
            bodySupported: true
            imageSupported: true
            keepOnReload: false
            persistenceSupported: true

            onNotification: (notification) => {
                console.log("[BarNotificationServer] Received notification from:", notification.appName, "summary:", notification.summary)
                Notifications.handleNotification(notification)
            }
        }


        // ── Registry overlays ──
        // Module-contributed overlay components (notification popup window,
        // on-screen display, night-light bootstrap) are instantiated from the
        // module registry instead of being hardcoded here, so a module's
        // `contributes.overlays` entry is the single source of truth.
        // Loaded once after the registry is ready; each overlay component
        // manages its own windows. Re-run sumika-restart to pick up registry
        // changes (objects are intentionally not torn down on registry reload).
        Component.onCompleted: root._instantiateOverlays()

        Connections {
            target: ModuleLoader
            function onRegistryLoaded() {
                root._instantiateOverlays()
            }
        }
    }

    property var _overlayObjects: []
    property var _overlayIds: ({})

    function _instantiateOverlays() {
        if (root._overlayObjects.length > 0)
            return
        const overlays = ModuleLoader.overlays
        for (let i = 0; i < overlays.length; i++) {
            const entry = overlays[i]
            if (!entry || !entry.component || root._overlayIds[entry.id]) {
                if (entry && entry.id && !entry.component)
                    console.warn("[Bar] overlay has no component:", entry.id)
                continue
            }
            const comp = Qt.createComponent(entry.component)
            if (comp.status !== Component.Ready) {
                console.warn("[Bar] overlay failed to load:", entry.id, comp.errorString())
                continue
            }
            const obj = comp.createObject(root)
            if (obj) {
                root._overlayIds[entry.id] = true
                root._overlayObjects.push(obj)
                console.log("[Bar] overlay loaded:", entry.id)
            }
        }
    }
}

