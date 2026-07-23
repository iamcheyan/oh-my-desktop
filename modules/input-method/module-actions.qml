import QtQuick

import qs.core.runtime
import qs.services as Svcs

/// Input method action registrations.
///
/// Registers QML-callback actions for cycling the input method schema
/// via the InputMethod service. Loaded by ModuleActionHost when the
/// input-method module is enabled.
Item {
    Component.onCompleted: {
        ActionManager.register("input-method.cycle", "input-method", "Cycle input method schema", {
            type: "qml",
            call: function(p) {
                var dir = 1
                if (typeof p === "number") dir = p
                else if (typeof p === "string") {
                    var n = parseInt(p, 10)
                    if (!isNaN(n)) dir = n
                }
                else if (p && p.direction !== undefined) dir = p.direction
                Svcs.InputMethod.cycleSchema(dir)
            }
        }, {description: "Switch to the next or previous input method schema",
            paramsSchema: {type: "object", properties: {direction: {type: "integer"}}}})
    }

    Component.onDestruction: {
        ActionManager.unregisterOwner("input-method")
    }
}
