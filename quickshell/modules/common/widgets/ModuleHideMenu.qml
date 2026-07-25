pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

/// Reusable right-click menu for hiding a bar module.
/// Usage: create a Loader with sourceComponent pointing here,
/// set moduleId, and call .open() anchored to the button.
ContextMenuWindow {
    id: root

    required property string moduleId

    signal hidingTriggered(string moduleId)

    ContextMenuItem {
        nerdIcon: NerdIconMap.visibilityOff
        labelText: "Hide"

        onClicked: {
            var hidden = Config.options.bar.hiddenIcons;
            var alreadyHidden = false;
            for (var i = 0; i < hidden.length; i++) {
                if (hidden[i] === root.moduleId) {
                    alreadyHidden = true;
                    break;
                }
            }
            if (!alreadyHidden) {
                var newHidden = [];
                for (var i = 0; i < hidden.length; i++)
                    newHidden.push(hidden[i]);
                newHidden.push(root.moduleId);
                Config.setNestedValue("bar.hiddenIcons", newHidden);
                root.hidingTriggered(root.moduleId);
            }
            root.close();
        }
    }
}
