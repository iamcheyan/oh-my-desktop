import QtQuick

import qs.core.runtime

/// MPRIS media control action registrations.
///
/// Registers QML-callback actions for media playback controls
/// via playerctl. Loaded by ModuleActionHost when the mpris
/// module is enabled.
Item {
    Component.onCompleted: {
        ActionManager.register("mpris.play-pause", "mpris",
            "Play / Pause", {
            type: "qml",
            call: function(p) { Quickshell.execDetached(["playerctl", "play-pause"]) }
        }, {description: "Toggle media playback"})

        ActionManager.register("mpris.next", "mpris",
            "Next track", {
            type: "qml",
            call: function(p) { Quickshell.execDetached(["playerctl", "next"]) }
        }, {description: "Skip to next track"})

        ActionManager.register("mpris.previous", "mpris",
            "Previous track", {
            type: "qml",
            call: function(p) { Quickshell.execDetached(["playerctl", "previous"]) }
        }, {description: "Go to previous track"})
    }
}
