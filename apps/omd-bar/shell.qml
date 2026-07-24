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

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    // Esc closes active menus — Hyprland binds ESCAPE to 'dispatch exec qs -p ... ipc call menus close'
    IpcHandler {
        target: "menus"

        function close(): void {
            if (GlobalStates.barPopupType !== "") {
                GlobalStates.barPopupType = "";
            }
            // Settings is now a separate process (omd-settings)
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
    }

    // Create top-level windows immediately. Gating this scope on Config.ready
    // lets Quickshell exit during cold login/reload before any window exists.
    // Core bar infrastructure — always present.
    Scope {
        Bar {}
        BarDismissLayer {}
        ModuleActionHost {}
        BarStatusPopup {}

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
        
        // Dynamic overlays loaded from module registry.
        // Modules register via contributes.overlays in their module.json.
        Repeater {
            id: overlaysRepeater
            Component.onCompleted: console.log("[Bar] Overlays count:", ModuleLoader.overlays.length, "items:", JSON.stringify(ModuleLoader.overlays.map(o => o.id)))
            model: ModuleLoader.overlays
            delegate: Loader {
                required property var modelData
                source: modelData.component
            }
        }
        
        Timer {
            interval: 5000
            repeat: true
            running: true
            onTriggered: {
                console.log("[BarDiag] Overlays count:", ModuleLoader.overlays.length, "Repeater children:", overlaysRepeater.count)
                for (var i = 0; i < overlaysRepeater.count; i++) {
                    var item = overlaysRepeater.itemAt(i)
                    console.log("[BarDiag] Overlay", i, "item:", item ? "exists" : "null")
                    if (item && item.status === Loader.Error) {
                        console.log("[BarDiag] Overlay", i, "error:", item.errorString())
                    }
                }
            }
        }
    }
}
