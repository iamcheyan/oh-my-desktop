//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs.core.runtime
import qs.modules.common
import qs.services
import qs.services as Services

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

    // Screenshot coordination: the standalone omd-screenshot process calls
    // these to freeze bar overlays *before* grim runs, so popups/menus are
    // preserved in the captured image. Without this, HyprlandFocusGrab fires
    // the moment the screenshot process creates its layer-shell surface and
    // dismisses the live popup before grim can capture it.
    IpcHandler {
        target: "screenshot"

        function begin(): void {
            GlobalStates.screenshotActive = true;
        }

        function end(): void {
            GlobalStates.screenshotActive = false;
        }
    }

    // Keep voice hotkeys independent from optional/dynamic bar modules.
    IpcHandler {
        target: "voice"

        function toggle(): void {
            VoiceInput.toggle()
        }

        function cancel(): void {
            VoiceInput.cancel()
        }
    }

    IpcHandler {
        target: "inputMethod"

        function cycle(direction: int): void {
            Services.InputMethod.cycleSchema(direction)
        }
    }

    IpcHandler {
        target: "notifications"

        function dismissLast(): void {
            Notifications.discardLatestNotification()
        }

        function dismissAll(): void {
            Notifications.discardAllNotifications()
        }

        function toggleSilent(): void {
            Notifications.toggleSilent()
        }

        function editMuted(): void {
            Notifications.openMutedAppsEditor()
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

        function invoke(id: string, params: var): void {
            const result = ActionManager.invoke(id, params)
            if (!result.success) {
                console.warn("[action IPC] invoke '" + id + "' failed: " + (result.error || "unknown"))
            }
        }

        function query(id: string): var {
            return ActionManager.query(id)
        }

        function isAvailable(id: string): bool {
            return ActionManager.isAvailable(id)
        }
    }

    Component.onCompleted: {
        // Register all core builtin actions.
        ActionManager._registerBuiltins()
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Updates.load()
    }

    // Create top-level windows immediately. Gating this scope on Config.ready
    // lets Quickshell exit during cold login/reload before any window exists.
    // Core bar infrastructure — always present.
    Scope {
        Bar {}
        BarDismissLayer {}
        BarStatusPopup {}
        SessionConfirmOverlay {}
        SessionAutoRestore {}
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
