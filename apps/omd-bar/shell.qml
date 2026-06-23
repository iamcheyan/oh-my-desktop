//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import "services"

import qs.modules.ii.bar
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.polkit
import qs.modules.ii.schedulePopup
import qs.modules.ii.screenCorners
import qs.modules.ii.sidebarRight

import QtQuick
import Quickshell

ShellRoot {
    id: root

    ReloadPopup {}

    Timer {
        id: deferredBackgroundTasksTimer
        interval: Config.options?.startup?.backgroundTasksDelayMs ?? 4000
        repeat: false
        onTriggered: Cliphist.refresh()
    }

    Component.onCompleted: {
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Updates.load()

        if (Config.options?.startup?.deferBackgroundTasks ?? true)
            deferredBackgroundTasksTimer.start()
        else
            Cliphist.refresh()
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
            ScreenCorners {}
            Polkit {}
        }
    }
}
