import QtQuick

import qs.core.runtime
import Quickshell

/// WiFi action registrations.
///
/// Registers process actions for opening the WiFi manager TUI.
/// Loaded by ModuleActionHost when the wifi module is enabled.
Item {
    Component.onCompleted: {
        var mh = Quickshell.env("SUMIKA_MODULES_HOME")
        var wifiBin
        if (mh) {
            wifiBin = mh + "/wifi/bin/omd-launch-wifi"
        } else {
            var omdRoot = Quickshell.env("OMD_REPO_ROOT") || ""
            wifiBin = omdRoot + "/modules/wifi/bin/omd-launch-wifi"
        }

        ActionManager.register("wifi.launch", "wifi", "Open WiFi manager", {
            type: "process",
            command: [wifiBin]
        }, {description: "Open the WiFi TUI"})
    }
}
