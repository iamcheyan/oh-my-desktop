import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.core.runtime
import QtQuick
import Quickshell

Item {
    id: root

    function toggleAppLauncher() {
        // Prefer ActionManager when registered; fallback to CLI.
        if (typeof ActionManager !== "undefined" && ActionManager.isAvailable("app-launcher.toggle")) {
            ActionManager.invoke("app-launcher.toggle")
            return
        }

        // Fallback: launch directly via SUMIKA_MODULES_HOME or OMD repo root
        var mh = Quickshell.env("SUMIKA_MODULES_HOME")
        var rootDir = Quickshell.env("OMD_REPO_ROOT") || Quickshell.env("OMD_ROOT") || ""
        var binDir = mh ? mh + "/launcher" : rootDir
        Quickshell.execDetached([binDir + "/bin/omd-applauncher", "toggle"])
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarTextButton {
        id: button
        text: "Applications"
        onTriggered: root.toggleAppLauncher()
    }
}
