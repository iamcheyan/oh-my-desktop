import QtQuick
import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import Quickshell

/// Registers process actions for the built-in application launcher.
/// Loaded by ModuleActionHost when the launcher module is enabled.
Item {
    Component.onCompleted: {
        var sumikaRoot = FileUtils.trimFileProtocol(Directories.root)
        var cmd = [sumikaRoot + "/bin/sumika-applauncher"]

        // Keep stable action IDs used by Hyprland bindings (sumika-action app-launcher.toggle).
        ActionManager.register("app-launcher.toggle", "launcher", "Toggle app launcher", {
            type: "process",
            command: cmd
        }, { description: "Open or close the application launcher" })

        ActionManager.register("app-launcher.open", "launcher", "Open app launcher", {
            type: "process",
            command: cmd.concat(["open"])
        }, { description: "Open the application launcher" })

        ActionManager.register("app-launcher.close", "launcher", "Close app launcher", {
            type: "process",
            command: cmd.concat(["close"])
        }, { description: "Close the application launcher" })
    }
}
