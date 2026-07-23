import QtQuick

import qs.core.runtime
import Quickshell

/// WiFi action registrations.
///
/// Registers process actions for opening the WiFi manager TUI.
/// Loaded by ModuleActionHost when the wifi module is enabled.
Item {
    Component.onCompleted: {
        var omdRoot = Quickshell.env("OMD_REPO_ROOT") || ""

        ActionManager.register("wifi.launch", "wifi", "Open WiFi manager", {
            type: "process",
            command: [omdRoot + "/bin/omd-launch-wifi"]
        }, {description: "Open the WiFi TUI"})
    }

    Component.onDestruction: {
        ActionManager.unregisterOwner("wifi")
    }
}
