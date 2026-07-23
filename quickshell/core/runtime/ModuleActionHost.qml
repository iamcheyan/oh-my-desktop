import QtQuick
import qs.core.runtime

/// Loads module-actions.qml from each enabled module.
///
/// This is the extension point for modules to register QML-callback actions
/// (and module-local process actions) without Core knowing module internals.
/// Each module places a `module-actions.qml` in its root directory; the host
/// loads it when the module is enabled and destroys it (triggering
/// `Component.onDestruction → ActionManager.unregisterOwner(moduleId)`) when
/// the module is disabled.
///
/// Place one instance in the bar process Scope, alongside Bar / BarStatusPopup.
Item {
    id: root

    Repeater {
        model: {
            const mods = ModuleLoader._registry.modules ?? []
            const result = []
            for (var i = 0; i < mods.length; i++) {
                var m = mods[i]
                if (m.id && m.path && ModuleLoader.isEnabled(m.id)) {
                    result.push({
                        moduleId: m.id,
                        actionsUrl: "file://" + m.path + "/module-actions.qml"
                    })
                }
            }
            return result
        }

        delegate: Item {
            id: wrapper
            required property var modelData

            readonly property url actionsUrl: modelData.actionsUrl

            Loader {
                source: wrapper.actionsUrl
                asynchronous: true

                onLoaded: {
                    console.log("[ModuleActionHost] loaded actions for '" + modelData.moduleId + "'")
                }
            }
        }
    }
}
