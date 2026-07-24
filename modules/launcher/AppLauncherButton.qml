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
        const rootDir = Directories.root || Quickshell.env("OMD_ROOT") || ""
        Quickshell.execDetached([rootDir + "/bin/omd-applauncher", "toggle"])
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarTextButton {
        id: button
        text: "Applications"
        onTriggered: root.toggleAppLauncher()
    }
}
