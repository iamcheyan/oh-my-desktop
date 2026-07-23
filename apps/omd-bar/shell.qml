//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs.core.runtime
import qs.modules.common
import qs.services
import qs.services as Services
import qs

import qs.modules.bar

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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
    }

    // Create top-level windows immediately. Gating this scope on Config.ready
    // lets Quickshell exit during cold login/reload before any window exists.
    // Core bar infrastructure — always present.
    Scope {
        Bar {}
        BarDismissLayer {}
        ModuleActionHost {}
        BarStatusPopup {}
    }

    // Dynamic overlays loaded from module registry.
    // Modules register via contributes.overlays in their module.json.
    Repeater {
        model: ModuleLoader.overlays
        delegate: Loader {
            required property var modelData
            source: modelData.component
        }
    }
}
