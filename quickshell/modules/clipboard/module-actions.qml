import QtQuick

import qs.core.runtime
import Quickshell

/// Clipboard action registrations.
///
/// Registers process actions for clipboard history management.
/// Loaded by ModuleActionHost when the clipboard module is enabled.
Item {
    Component.onCompleted: {
        var clipDir = ModuleLoader.modulePath("clipboard")
        if (!clipDir) return

        ActionManager.register("clipboard.store-repair", "clipboard", "Repair clipboard store", {
            type: "process",
            command: [clipDir + "/bin/sumika-clipboard-store", "repair"]
        }, {description: "Ensure the clipboard history watcher is running"})

        // Compatibility alias for older keybindings and menus.
        ActionManager.register("clipboard.store-toggle", "clipboard", "Repair clipboard store", {
            type: "process",
            command: [clipDir + "/bin/sumika-clipboard-store", "repair"]
        }, {description: "Ensure the clipboard history watcher is running"})

        ActionManager.register("clipboard.toggle", "clipboard", "Toggle clipboard", {
            type: "process",
            command: [clipDir + "/bin/sumika-clipboard", "toggle"]
        }, {description: "Open or close the clipboard history"})

        ActionManager.register("clipboard.toggleBar", "clipboard", "Toggle clipboard at bar", {
            type: "shell",
            command: clipDir + "/bin/sumika-clipboard toggle-at-bar"
        }, {description: "Open or close the clipboard anchored to the top bar"})

        ActionManager.register("clipboard.open", "clipboard", "Open clipboard", {
            type: "process",
            command: [clipDir + "/bin/sumika-clipboard", "open"]
        }, {description: "Open the clipboard history"})

        ActionManager.register("clipboard.close", "clipboard", "Close clipboard", {
            type: "process",
            command: [clipDir + "/bin/sumika-clipboard", "close"]
        }, {description: "Close the clipboard history"})

        ActionManager.register("clipboard.paste", "clipboard", "Paste clipboard selection", {
            type: "process",
            command: [clipDir + "/bin/sumika-clipboard", "paste"]
        }, {description: "Paste the currently selected clipboard entry"})
    }
}
