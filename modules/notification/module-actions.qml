import QtQuick

import qs.core.runtime

/// Notification action registrations.
///
/// Registers QML-callback actions for notification management
/// via the Notifications service. Loaded by ModuleActionHost
/// when the notification module is enabled.
Item {
    Component.onCompleted: {
        ActionManager.register("notification.dismiss-last", "notification", "Dismiss last notification", {
            type: "qml",
            call: function(p) { ServiceManager.notification.discardLatestNotification() }
        }, {description: "Remove the most recent notification"})

        ActionManager.register("notification.dismiss-all", "notification", "Dismiss all notifications", {
            type: "qml",
            call: function(p) { ServiceManager.notification.discardAllNotifications() }
        }, {description: "Clear all visible notifications"})

        ActionManager.register("notification.toggle-silent", "notification", "Toggle silent mode", {
            type: "qml",
            call: function(p) { ServiceManager.notification.toggleSilent() }
        }, {description: "Toggle do-not-disturb"})

        ActionManager.register("notification.edit-muted", "notification", "Edit muted apps", {
            type: "qml",
            call: function(p) { ServiceManager.notification.openMutedAppsEditor() }
        }, {description: "Open muted applications editor"})
    }
}
