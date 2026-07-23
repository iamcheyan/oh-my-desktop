import QtQuick

import qs.core.runtime
import qs.services as Svcs

/// Notification action registrations.
///
/// Registers QML-callback actions for notification management
/// via the Notifications service. Loaded by ModuleActionHost
/// when the notification module is enabled.
Item {
    Component.onCompleted: {
        ActionManager.register("notification.dismiss-last", "notification", "Dismiss last notification", {
            type: "qml",
            call: function(p) { Svcs.Notifications.discardLatestNotification() }
        }, {description: "Remove the most recent notification"})

        ActionManager.register("notification.dismiss-all", "notification", "Dismiss all notifications", {
            type: "qml",
            call: function(p) { Svcs.Notifications.discardAllNotifications() }
        }, {description: "Clear all visible notifications"})

        ActionManager.register("notification.toggle-silent", "notification", "Toggle silent mode", {
            type: "qml",
            call: function(p) { Svcs.Notifications.toggleSilent() }
        }, {description: "Toggle do-not-disturb"})

        ActionManager.register("notification.edit-muted", "notification", "Edit muted apps", {
            type: "qml",
            call: function(p) { Svcs.Notifications.openMutedAppsEditor() }
        }, {description: "Open muted applications editor"})
    }

    Component.onDestruction: {
        ActionManager.unregisterOwner("notification")
    }
}
