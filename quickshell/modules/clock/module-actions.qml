pragma ComponentBehavior: Bound
import QtQuick

import qs.core.runtime
import qs

/// Clock action registrations.
///
/// Registers QML-callback actions for clock/notification-center toggle.
/// Loaded by ModuleActionHost when the clock module is enabled.
Item {
    Component.onCompleted: {
        ActionManager.register("clock.notifications", "clock",
            "Toggle notification center", {
            type: "qml",
            call: function(p) {
                GlobalStates.barPopupType = GlobalStates.barPopupType === "notifications"
                    ? "" : "notifications"
            }
        }, {description: "Toggle the notification center popup"})
    }
}
