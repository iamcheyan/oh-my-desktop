pragma ComponentBehavior: Bound
import QtQuick

import qs.core.runtime

/// On-screen display action registrations.
///
/// Registers QML-callback actions that trigger the in-process OSD
/// overlays. Loaded by ModuleActionHost when the on-screen-display
/// module is enabled. All OSD overlays are managed by GlobalStates
/// flags in the bar process context.
Item {
    Component.onCompleted: {
        ActionManager.register("osd.volume", "on-screen-display",
            "Show volume OSD", {
            type: "qml",
            call: function(p) {
                GlobalStates.osdVolumeOpen = true
            }
        }, {description: "Show the volume change on-screen display"})

        ActionManager.register("osd.brightness", "on-screen-display",
            "Show brightness OSD", {
            type: "qml",
            call: function(p) {
                GlobalStates.osdBrightnessOpen = true
            }
        }, {description: "Show the brightness change on-screen display"})
    }
}
