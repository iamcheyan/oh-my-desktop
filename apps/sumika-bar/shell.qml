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

import qs.modules.powerIndicator

import qs.modules.onScreenDisplay
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
            // Settings is now a separate process (sumika-settings)
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

    // Action IPC compat layer — external processes (overview, settings, etc.)
    // can invoke or query any registered ActionManager action by ID.
    // This is the migration path from old direct qs -p ipc calls.
    IpcHandler {
        target: "action"

        function call(id: string, params: string): void {
            let parsed = undefined
            if (params && params.length > 0) {
                try { parsed = JSON.parse(params) } catch (e) { parsed = params }
            }
            ActionManager.invoke(id, parsed)
        }


        function list(): string {
            return JSON.stringify(ActionManager.getActionList())
        }
        function query(id: string): string {
            const a = ActionManager.query(id)
            return JSON.stringify(a)
        }

        function isAvailable(id: string): bool {
            return ActionManager.isAvailable(id)
        }
    }


    Component.onCompleted: {
        ActionManager._registerBuiltins()
        ApplicationManager.initialize()
        // Overview is a separate on-demand qs process. Without pre-warming,
        // the first open after boot pays the full cold-start cost (registry
        // regen + QML compile + per-screen widget tree) and the very first
        // click only spawns the process hidden. Pre-warm it shortly after
        // the bar is up so the first user-triggered open is instant. The
        // overview keepAliveWindow then keeps the process alive.
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

        // Notification popup overlay — PanelWindow bound to popupList
        PanelWindow {
            id: notifPopup
            visible: (ServiceManager.notification.popupList.length > 0) && !GlobalStates.screenLocked
            screen: Quickshell.screens.find(s =>
                Config.options.notifications.forceMonitor.enable
                    ? s.name === Config.options.notifications.forceMonitor.name
                    : s.name === Hyprland.focusedMonitor?.name) ?? null
            readonly property bool barOnBottom: Config.options.bar.bottom
            readonly property real outerMargin: Appearance.sizes.elevationMargin

            WlrLayershell.namespace: "quickshell:notificationPopup"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: !notifPopup.barOnBottom
                bottom: notifPopup.barOnBottom
                right: true
            }

            margins {
                top: notifPopup.barOnBottom ? 0 : BarPopupGeometry.windowTopMargin
                bottom: notifPopup.barOnBottom ? BarPopupGeometry.windowTopMargin : 0
                right: BarPopupGeometry.rightGap
            }

            mask: Region {
                item: listview.contentItem
            }

            color: "transparent"
            implicitWidth: Appearance.sizes.notificationPopupWidth + notifPopup.outerMargin * 2
            implicitHeight: Math.min(
                listview.contentHeight + notifPopup.outerMargin * 2,
                (notifPopup.screen?.height ?? 1080) - Appearance.sizes.barHeight - 8
            )

            NotificationListView {
                id: listview
                anchors {
                    fill: parent
                    margins: notifPopup.outerMargin
                }
                popup: true
            }
        }
        OnScreenDisplay {}
    }
}
