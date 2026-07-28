import QtQuick

import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import Quickshell

/// WiFi action registrations.
///
/// Registers process actions for opening the WiFi manager TUI.
/// Loaded by ModuleActionHost when the wifi module is enabled.
Item {
    Component.onCompleted: {
        var sumikaRoot = FileUtils.trimFileProtocol(Directories.root)
        var wifiBin = sumikaRoot + "/quickshell/modules/wifi/bin/sumika-launch-wifi"

        ActionManager.register("wifi.launch", "wifi", "Open WiFi manager", {
            type: "process",
            command: [wifiBin]
        }, {description: "Open the WiFi TUI"})
    }
}
