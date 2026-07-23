import QtQuick

import qs.core.runtime
import qs.services as Svcs

/// Notification popup action registrations.
///
/// Delegates to the notification module's process-level actions.
/// These are in-process QML delegates because the registration
/// happens in the overlay context (bar process), not the notification
/// process.
Item {
    Component.onCompleted: {
        var desc = "Dismiss the most recent notification"
        ActionManager.register("notifications.dismiss-last", "notification-popup",
            "Dismiss last notification", {
            type: "delegate", targetId: "notification.dismiss-last"
        }, {description: desc})

        ActionManager.register("notifications.dismiss-all", "notification-popup",
            "Dismiss all notifications", {
            type: "delegate", targetId: "notification.dismiss-all"
        }, {description: "Dismiss all visible notifications"})

        ActionManager.register("notifications.toggle-silent", "notification-popup",
            "Toggle silent mode", {
            type: "delegate", targetId: "notification.toggle-silent"
        }, {description: "Toggle do-not-disturb mode"})

        ActionManager.register("notifications.edit-muted", "notification-popup",
            "Edit muted apps", {
            type: "delegate", targetId: "notification.edit-muted"
        }, {description: "Open muted applications editor"})
    }
}
