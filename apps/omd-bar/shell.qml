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
    //
    // All methods now delegate through ActionManager for module-enabled checks.
    IpcHandler {
        target: "screenshot"

        function begin(): void {
            ActionManager.invoke("screenshot.freeze")
        }

        function end(): void {
            ActionManager.invoke("screenshot.unfreeze")
        }
    }

    IpcHandler {
        target: "voice"

        function toggle(): void {
            ActionManager.invoke("voice.toggle")
        }

        function cancel(): void {
            ActionManager.invoke("voice.cancel")
        }
    }

    IpcHandler {
        target: "inputMethod"

        function cycle(direction: int): void {
            ActionManager.invoke("input-method.cycle", {direction})
        }
    }

    IpcHandler {
        target: "notifications"

        function dismissLast(): void {
            ActionManager.invoke("notification.dismiss-last")
        }

        function dismissAll(): void {
            ActionManager.invoke("notification.dismiss-all")
        }

        function toggleSilent(): void {
            ActionManager.invoke("notification.toggle-silent")
        }

        function editMuted(): void {
            ActionManager.invoke("notification.edit-muted")
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

    /// Register module actions from the registry.
    /// Each declared action ID gets a handler based on its known contract.
    /// ActionManager's `isAvailable()`/`invoke()` dynamically checks
    /// ModuleLoader.isEnabled(owner) so disabling modules blocks all entry points.
    function _registerModuleActions() {
        // ── Voice ──
        ActionManager.register("voice.toggle", "voice", "Toggle voice input", {
            type: "qml",
            call: function(p) { VoiceInput.toggle() }
        }, {description: "Start or stop voice input recording"})
        ActionManager.register("voice.cancel", "voice", "Cancel voice input", {
            type: "qml",
            call: function(p) { VoiceInput.cancel() }
        }, {description: "Cancel active voice input"})

        // ── Input method ──
        ActionManager.register("input-method.cycle", "input-method", "Cycle input method schema", {
            type: "qml",
            call: function(p) {
                let dir = 1
                if (typeof p === "number") dir = p
                else if (typeof p === "string") {
                    const n = parseInt(p, 10)
                    if (!isNaN(n)) dir = n
                }
                else if (p && p.direction !== undefined) dir = p.direction
                Services.InputMethod.cycleSchema(dir)
            }
        }, {description: "Switch to the next or previous input method schema",
            paramsSchema: {type: "object", properties: {direction: {type: "integer"}}}})

        // ── Screenshot ──
        ActionManager.register("screenshot.freeze", "screenshot", "Freeze screenshot overlays", {
            type: "qml",
            call: function(p) { GlobalStates.screenshotActive = true }
        }, {description: "Hide bar popups before grim capture"})
        ActionManager.register("screenshot.unfreeze", "screenshot", "Unfreeze screenshot overlays", {
            type: "qml",
            call: function(p) { GlobalStates.screenshotActive = false }
        }, {description: "Restore bar popups after grim capture"})
        ActionManager.register("screenshot.capture", "screenshot", "Take region screenshot", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-screenshot", "screenshot"]
        }, {description: "Capture a selected screen region"})
        ActionManager.register("screenshot.capture-edit", "screenshot", "Take region screenshot and edit", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-screenshot", "edit"]
        }, {description: "Capture a region and open in editor"})
        ActionManager.register("screenshot.capture-ocr", "screenshot", "Extract text from screenshot", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-screenshot", "ocr"]
        }, {description: "OCR text from a screen region"})

        // ── Notifications ──
        ActionManager.register("notification.dismiss-last", "notification", "Dismiss last notification", {
            type: "qml",
            call: function(p) { Notifications.discardLatestNotification() }
        }, {description: "Remove the most recent notification"})
        ActionManager.register("notification.dismiss-all", "notification", "Dismiss all notifications", {
            type: "qml",
            call: function(p) { Notifications.discardAllNotifications() }
        }, {description: "Clear all visible notifications"})
        ActionManager.register("notification.toggle-silent", "notification", "Toggle silent mode", {
            type: "qml",
            call: function(p) { Notifications.toggleSilent() }
        }, {description: "Toggle do-not-disturb"})
        ActionManager.register("notification.edit-muted", "notification", "Edit muted apps", {
            type: "qml",
            call: function(p) { Notifications.openMutedAppsEditor() }
        }, {description: "Open muted applications editor"})

        // ── App launcher ──
        ActionManager.register("app-launcher.toggle", "app-launcher", "Toggle app launcher", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-applauncher"]
        }, {description: "Open or close the application launcher"})

        // ── WiFi / Bluetooth ──
        ActionManager.register("wifi.launch", "wifi", "Open WiFi manager", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-launch-wifi"]
        }, {description: "Open the WiFi TUI"})
        ActionManager.register("bluetooth.launch", "bluetooth", "Open Bluetooth manager", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-launch-bluetooth"]
        }, {description: "Open the Bluetooth pairing TUI"})

        // ── Clipboard store (clipboard.toggle is registered by ActionManager._registerBuiltins) ──
        // Resolve from external module path (clipboard lives in sumika-modules, not OMD repo)
        var clipDir = typeof ActionManager !== "undefined" ? ActionManager._modulePath("clipboard") : ""
        if (!clipDir) clipDir = Quickshell.env("OMD_REPO_ROOT")
        ActionManager.register("clipboard.store-toggle", "clipboard", "Toggle clipboard store", {
            type: "process",
            command: [clipDir + "/bin/omd-clipboard-store", "toggle"]
        }, {description: "Start or stop the clipboard history daemon"})
    }

    Component.onCompleted: {
        // Register all core builtin actions.
        ActionManager._registerBuiltins()
        // Register all module-hosted actions.
        _registerModuleActions()
        Hyprsunset.load()
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
