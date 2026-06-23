//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

// Remove two slashes below and adjust the value to change the UI scale
////@ pragma Env QT_SCALE_FACTOR=1

import "modules/common"
import "services"
import "panelFamilies"

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    // Stuff for every panel family
    ReloadPopup {}

    Timer {
        id: deferredBackgroundTasksTimer
        interval: Config.options?.startup?.backgroundTasksDelayMs ?? 4000
        repeat: false
        onTriggered: Cliphist.refresh()
    }

    Component.onCompleted: {
        // Kill stale quickshell processes: keep only the newest PID (us), silently
        // terminate the rest with SIGTERM, escalating to SIGKILL after 3 seconds.
        Quickshell.execDetached(["bash", "-c",
            "newest=$(pgrep -x quickshell -n 2>/dev/null); " +
            "for pid in $(pgrep -x quickshell 2>/dev/null); do " +
            "[ \"$pid\" = \"$newest\" ] && continue; " +
            "kill \"$pid\" 2>/dev/null; " +
            "( sleep 3; kill -9 \"$pid\" 2>/dev/null ) & " +
            "done"])

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
        component: IllogicalImpulseFamily {}
    }
}
