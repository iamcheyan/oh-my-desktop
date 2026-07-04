//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs
import "modules/common"
import "services"

import qs.modules.bar
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.polkit
import qs.modules.schedulePopup
import qs.modules.controlCenter
import qs.modules.regionSelector
import qs.modules.sessionScreen

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: root

    ReloadPopup {}

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
            if (GlobalStates.barDialogOpen) {
                GlobalStates.barDialogOpen = false;
            }
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
            BarStatusPopup {}
            BarDialogOverlay {}
            SessionConfirmOverlay {}
            SessionAutoRestore {}
            ControlCenter {}
            NotificationPopup {}
            OnScreenDisplay {}
            Polkit {}
            RegionSelector {}
            SessionScreen {}
        }
    }
}
