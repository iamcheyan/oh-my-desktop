import QtQuick

import qs.core.runtime
import Quickshell

/// App launcher action registrations.
///
/// Registers process actions for toggling the application launcher.
/// Loaded by ModuleActionHost when the app-launcher module is enabled.
Item {
    Component.onCompleted: {
        var omdRoot = Quickshell.env("OMD_REPO_ROOT") || ""

        ActionManager.register("app-launcher.toggle", "app-launcher", "Toggle app launcher", {
            type: "process",
            command: [omdRoot + "/bin/omd-applauncher"]
        }, {description: "Open or close the application launcher"})
    }
}
