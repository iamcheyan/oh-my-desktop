import QtQuick
import qs.core.runtime

/// Loads the declared actions provider from each enabled module.
///
/// Modules declare their actions provider script in module.json via the
/// `actionsProvider` field (e.g. "module-actions.qml"). Only modules that
/// explicitly declare this field get a Loader created.
///
/// When a module is disabled or the host is destroyed, all actions belonging
/// to that module are automatically unregistered — no manual cleanup needed
/// in module-actions.qml files.
Item {
    id: root

    Repeater {
        model: {
            const providers = ModuleLoader.actionProviders
            const result = []
            for (var i = 0; i < providers.length; i++) {
                var m = providers[i]
                if (ModuleLoader.isEnabled(m.id)) {
                    result.push({
                        moduleId: m.id,
                        actionsUrl: "file://" + m.path + "/" + m.actionsProvider
                    })
                }
            }
            return result
        }

        delegate: Item {
            id: wrapper
            required property var modelData

            readonly property url actionsUrl: modelData.actionsUrl
            // Save ownerId at creation time so Component.onDestruction still has
            // the correct owner ID even if the model data is removed from the list.
            readonly property string ownerId: modelData.moduleId

            Loader {
                source: wrapper.actionsUrl
                asynchronous: true

                onLoaded: {
                    console.info("[ModuleActionHost] loaded actions for '" + modelData.moduleId + "'")
                }
            }

            // Automatic cleanup: when the Repeater removes this delegate
            // (module disabled) or the host is destroyed, all actions for
            // this module are unregistered. This eliminates the fragile
            // Component.onDestruction pattern from module-actions.qml files.
            Component.onDestruction: {
                ActionManager.unregisterOwner(wrapper.ownerId)
            }
        }
    }
}
