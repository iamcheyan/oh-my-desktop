import QtQuick

import qs.core.runtime
import qs.services

/// Notification popup action registrations.
///
/// In-process QML handlers against the Notifications service singleton
/// (the earlier delegate targetIds pointed at actions that were never
/// registered — invoking them always failed).
Item {
    Component.onCompleted: {
        ActionManager.register("notifications.dismiss-last", "notification-popup",
            "Dismiss last notification", {
            type: "qml",
            call: function() { Notifications.discardLatestNotification() }
        }, {description: "Dismiss the most recent notification"})

        ActionManager.register("notifications.dismiss-all", "notification-popup",
            "Dismiss all notifications", {
            type: "qml",
            call: function() { Notifications.discardAllNotifications() }
        }, {description: "Dismiss all visible notifications"})

        ActionManager.register("notifications.toggle-silent", "notification-popup",
            "Toggle silent mode", {
            type: "qml",
            call: function() { Notifications.toggleSilent() }
        }, {description: "Toggle do-not-disturb mode"})

        ActionManager.register("notifications.edit-muted", "notification-popup",
            "Edit muted apps", {
            type: "qml",
            call: function() { Notifications.openMutedAppsEditor() }
        }, {description: "Open muted applications editor"})
    }
}
