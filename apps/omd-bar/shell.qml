//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import "services"

import qs.modules.bar
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.polkit
import qs.modules.schedulePopup
import qs.modules.sidebarRight

import QtQuick
import Quickshell

ShellRoot {
    id: root

    ReloadPopup {}

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
            BarDialogOverlay {}
            SidebarRight {}
            SchedulePopup {}
            NotificationPopup {}
            OnScreenDisplay {}
            Polkit {}
        }
    }
}