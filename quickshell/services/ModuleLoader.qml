pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/// ModuleLoader — loads external Sumika Shell modules at runtime.
///
/// Modules live in ~/development/sumika-modules/<id>/ and are discovered
/// by the startup script, which writes /tmp/sumika-module-registry.json.
/// This singleton parses that JSON and exposes bar buttons, popup sections,
/// and settings pages for dynamic loading via Repeater + Loader.

Singleton {
    id: loader

    readonly property string registryPath: Quickshell.env("SUMIKA_MODULE_REGISTRY") ?? "/tmp/sumika-module-registry.json"

    // Raw registry data — populated by registryReader Process.
    property var _registry: _emptyRegistry()

    // Master switch — if false, all modules are disabled.
    readonly property bool modulesEnabled: Config.options.modules?.enabled !== false

    function isEnabled(moduleId) {
        if (!modulesEnabled) return false
        return true
    }


    readonly property var barButtons: {
        if (!modulesEnabled) return []
        const buttons = (_registry.barButtons ?? []).filter(b => isEnabled(b.moduleId))
        return buttons.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    // Left-side modules (built-in and external) — registered in the workspace-adjacent slot
    readonly property var leftBarModules: {
        if (!modulesEnabled) return []
        var items = []
        // Built-in core modules (Applications, ActiveWindow)
        items.push({
            component: Qt.resolvedUrl("../modules/bar/AppLauncherButton.qml"),
            id: "appLauncher",
            name: "Applications"
        })
        items.push({
            component: Qt.resolvedUrl("../modules/bar/ActiveWindow.qml"),
            id: "activeWindow",
            name: "Active Window"
        })
        // External modules that declare barButtons with slot: "left"
        var extButtons = (_registry.barButtons ?? []).filter(function(b) {
            return b.slot === "left" && loader.isEnabled(b.moduleId)
        })
        for (var i = 0; i < extButtons.length; i++) {
            items.push(extButtons[i])
        }
        return items
    }

    readonly property var popupSections: {
        if (!modulesEnabled) return []
        return (_registry.popupSections ?? []).filter(s => isEnabled(s.moduleId))
    }

    readonly property var settingsPages: {
        if (!modulesEnabled) return []
        const pages = (_registry.settingsPages ?? []).filter(p => isEnabled(p.moduleId))
        return pages.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    readonly property var activeModuleIds: {
        if (!modulesEnabled) return []
        return (_registry.modules ?? []).filter(m => isEnabled(m.id ?? m)).map(m => m.id ?? m)
    }

    function _emptyRegistry() {
        return { modules: [], barButtons: [], popupSections: [], settingsPages: [] }
    }

    // Read registry JSON via cat (Quickshell has no readFile API).
    Process {
        id: registryReader
        command: ["cat", loader.registryPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const text = this.text.trim()
                    if (text.length > 0) {
                        loader._registry = JSON.parse(text)
                        console.log("[ModuleLoader] Loaded registry:", JSON.stringify({
                            modules: loader._registry.modules?.length ?? 0,
                            barButtons: loader._registry.barButtons?.length ?? 0,
                            popupSections: loader._registry.popupSections?.length ?? 0,
                            settingsPages: loader._registry.settingsPages?.length ?? 0
                        }))
                    }
                } catch (e) {
                    console.warn("[ModuleLoader] Failed to parse registry:", e)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // File doesn't exist yet — silent, modules just won't load.
            }
        }
        running: true
    }
}