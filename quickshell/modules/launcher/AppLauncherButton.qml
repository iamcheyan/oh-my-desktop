pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.core.runtime
import QtQuick
import Quickshell

Item {
    id: root
    property string moduleId: "launcher"

    function toggleAppLauncher() {
        // Prefer ActionManager when registered; fallback to CLI.
        if (typeof ActionManager !== "undefined" && ActionManager.isAvailable("app-launcher.toggle")) {
            ActionManager.invoke("app-launcher.toggle")
            return
        }

        // Fallback: launch via canonical entry script
        var rootDir = FileUtils.trimFileProtocol(Directories.root)
        Quickshell.execDetached([rootDir + "/bin/sumika-applauncher", "toggle"])
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarTextButton {
        id: button
        text: "Applications"
        onTriggered: root.toggleAppLauncher()
    }

    Component {
        id: hoverComponent
        HoverInfo {}
    }

    Component.onCompleted: {
        HoverInfoService.register(root.moduleId, hoverComponent)
        // Resident mode: pre-warm the launcher process so the first open is
        // instant. The bin's `warm` subcommand is a no-op if already running.
        if (Config.options.launcher.resident)
            Quickshell.execDetached([FileUtils.trimFileProtocol(Directories.root) + "/bin/sumika-applauncher", "warm"])
    }

    HoverInfoPopup {
        moduleId: root.moduleId
        hoverTarget: button
    }
}
