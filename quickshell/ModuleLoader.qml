pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/// ModuleLoader — loads external Sumika Shell modules at runtime.
///
/// Modules live in ~/development/sumika-modules/<id>/ and are discovered
/// by the startup script, which sets SUMIKA_MODULE_PATHS (colon-separated).
/// Each module has a module.json declaring its capabilities.
///
/// This singleton parses the registry JSON (written by the startup script
/// to /tmp/sumika-module-registry.json) and exposes:
///   - barButtons:  [{ component, slot, order, moduleId }] sorted by order
///   - popupSections: [{ type, component, moduleId }]
///   - settingsPages: [{ id, title, component, icon, order, moduleId }]
///   - disabledModules: [string] — user-config blacklisted module IDs

Singleton {
    id: loader

    // Path to the registry JSON written by the startup script.
    readonly property string registryPath: Quickshell.env("SUMIKA_MODULE_REGISTRY") ?? "/tmp/sumika-module-registry.json"

    // Parsed registry data.
    readonly property var registry: {
        try {
            const f = Quickshell.readFile(registryPath)
            if (!f || f.length === 0) return _emptyRegistry()
            return JSON.parse(f)
        } catch (e) {
            console.warn("[ModuleLoader] Failed to load registry:", e)
            return _emptyRegistry()
        }
    }

    // User-config disabled modules (from config.json modules.disabled).
    readonly property var disabled: {
        const list = Config.options.modules?.disabled ?? []
        return Array.isArray(list) ? list : []
    }

    function isEnabled(moduleId) {
        return !disabled.includes(moduleId)
    }

    // Bar buttons from all enabled modules, sorted by order.
    readonly property var barButtons: {
        const buttons = (registry.barButtons ?? []).filter(b => isEnabled(b.moduleId))
        return buttons.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    // Popup sections from all enabled modules.
    readonly property var popupSections: {
        return (registry.popupSections ?? []).filter(s => isEnabled(s.moduleId))
    }

    // Settings pages from all enabled modules, sorted by order.
    readonly property var settingsPages: {
        const pages = (registry.settingsPages ?? []).filter(p => isEnabled(p.moduleId))
        return pages.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    // Module IDs that are physically present and not disabled.
    readonly property var activeModuleIds: {
        return (registry.modules ?? []).filter(m => isEnabled(m)).map(m => m.id)
    }

    function _emptyRegistry() {
        return { modules: [], barButtons: [], popupSections: [], settingsPages: [] }
    }
}