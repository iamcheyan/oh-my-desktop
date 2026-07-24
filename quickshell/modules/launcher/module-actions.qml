import QtQuick
import qs.core.runtime
import Quickshell

/// Registers process actions for the built-in application launcher.
/// Loaded by ModuleActionHost when the launcher module is enabled.
Item {
    Component.onCompleted: {
        var omdRoot = Quickshell.env("OMD_REPO_ROOT") || Quickshell.env("OMD_ROOT") || ""
        var cmd
        if (omdRoot) {
            cmd = [omdRoot + "/bin/omd-applauncher"]
        } else {
            cmd = ["omd-applauncher"]
        }

        // Keep stable action IDs used by Hyprland bindings (omd-action app-launcher.toggle).
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
