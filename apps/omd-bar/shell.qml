//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs
import "modules/common"
import "services"
import "services" as Services

import qs.modules.bar
import qs.modules.onScreenDisplay
import qs.modules.lock
import qs.modules.notificationPopup

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

        property Timer hideTimer: Timer {
            interval: 800
            repeat: false
            onTriggered: GlobalStates.barPopupType = ""
        }

        function cycle(direction: int): void {
            Services.InputMethod.cycleSchema(direction)
            // Show popup and auto-hide after delay
            GlobalStates.barPopupType = "inputMethod";
            hideTimer.restart();
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
    }

    Component.onCompleted: {
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Updates.load()
    }

    // Create top-level windows immediately. Gating this scope on Config.ready
    // lets Quickshell exit during cold login/reload before any window exists.
    Scope {
        Bar {}
        NotificationPopup {}
        Lock {}
        BarDismissLayer {}
        BarStatusPopup {}
        SessionConfirmOverlay {}
        SessionAutoRestore {}
        OnScreenDisplay {}
    }
}
