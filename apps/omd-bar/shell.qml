//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs
import "modules/common"
import "services"

import qs.modules.bar
import qs.modules.onScreenDisplay
import qs.modules.lock

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
            if (GlobalStates.activeContextMenu !== "") {
                GlobalStates.activeContextMenu = "";
            }
            if (GlobalStates.barPopupType !== "") {
                GlobalStates.barPopupType = "";
            }
            // Settings is now a separate process (omd-settings)
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

    Component.onCompleted: {
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Updates.load()
    }

    LazyLoader {
        active: Config.ready
        component: Scope {
            Bar {}
            Lock {}
            BarDismissLayer {}
            BarStatusPopup {}
            SessionConfirmOverlay {}
            SessionAutoRestore {}
            OnScreenDisplay {}
        }
    }
}
