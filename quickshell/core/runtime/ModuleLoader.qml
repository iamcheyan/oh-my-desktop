pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/// Modules live in ~/development/sumika-modules/<id>/ and are discovered
/// by the startup script, which writes $XDG_RUNTIME_DIR/sumika-shell/modules.json.
/// This singleton parses that JSON (v2 schema) and exposes contributions
/// for dynamic loading via Repeater + Loader.
/// Registry access helpers for module contributes.
/// The registry is always v2 format (startup script converts v1 manifests during generation).
/// Fields: contributes.widgets, contributes.popupSections, contributes.settingsPages, contributes.services, contributes.actions

Singleton {
    id: loader

    readonly property string registryPath: Quickshell.env("SUMIKA_MODULE_REGISTRY") ?? (() => {
        const rt = Quickshell.env("XDG_RUNTIME_DIR") ?? "/run/user/" + (typeof Quickshell !== "undefined" ? Quickshell.env("UID") ?? "1000" : "1000")
        return rt + "/sumika-shell/modules.json"
    })()

    // Raw registry data — populated by registryReader Process.
    property var _registry: _emptyRegistry()

    // Master switch — if false, all modules are disabled.
    readonly property bool modulesEnabled: Config.options.modules?.enabled !== false

    function isEnabled(moduleId) {
        if (!modulesEnabled) return false
        // Per-module exclusion check
        // NOTE: QML list<var> is NOT a JS Array — Array.isArray() returns false,
        // indexOf() is not available. Use manual iteration instead.
        const disabled = Config.options.modules?.disabled ?? []
        if (disabled && disabled.length > 0) {
            for (var i = 0; i < disabled.length; i++) {
                if (disabled[i] === moduleId) return false
            }
        }
        return true
    }

    // Helper: read a contributes array. Registry is always v2 format
    // (startup script converts v1 manifests during generation).
    function _contributes(key) {
        const c = _registry.contributes
        if (c && Array.isArray(c[key]) && c[key].length > 0) {
            return c[key]
        }
        return []
    }

    function _filterBarButtons(slot) {
        const buttons = _contributes("widgets")
        // No fallback: if registry has no widgets, return empty.
        const result = []
        for (var i = 0; i < buttons.length; i++) {
            var b = buttons[i]
            if (b.slot !== slot) continue
            // alwaysShow buttons visible regardless of per-module disabled list
            if (b.alwaysShow) {
                result.push(b)
            } else if (loader.isEnabled(b.moduleId)) {
                result.push(b)
            }
        }
        result.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
        return result
    }

    /** Left-side bar buttons (Workspace-adjacent slot) */
    readonly property var leftBarButtons: _filterBarButtons("left")

    /** Right-side bar buttons (tray slot) */
    readonly property var rightBarButtons: _filterBarButtons("right")

    /** @deprecated Use rightBarButtons instead */
    readonly property var barButtons: rightBarButtons

    /**
     * Popup sections — appended AFTER the main content for a popup type.
     * These are ADDITIONAL content, not full popup replacements.
     *
     * Contract:
     * - type: string matching root.activeType (e.g. "audio", "battery")
     * - component: file:// URL to a QML component (section content)
     * - moduleId: owning module — used for per-module enable/disable
     */
    readonly property var popupSections: {
        if (!modulesEnabled) return []
        const sections = _contributes("popupSections")
        const singletonTypes = {battery: 1, inputMethod: 1, keyboard: 1, voice: 1}
        const seenSingletonTypes = {}
        return sections.filter(s => {
            if (!isEnabled(s.moduleId)) return false
            if (!s.type || typeof s.type !== 'string') {
                console.warn("[ModuleLoader] popupSection missing type:", JSON.stringify(s))
                return false
            }
            if (singletonTypes[s.type]) {
                if (seenSingletonTypes[s.type]) {
                    console.warn("[ModuleLoader] ignoring duplicate singleton popup type:",
                                 s.type, "from", s.moduleId)
                    return false
                }
                seenSingletonTypes[s.type] = true
            }
            return true
        })
    }

    readonly property var settingsPages: {
        if (!modulesEnabled) return []
        const pages = _contributes("settingsPages").filter(p => isEnabled(p.moduleId))
        return pages.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    readonly property var activeModuleIds: {
        if (!modulesEnabled) return []
        return (_registry.modules ?? []).filter(m => isEnabled(m.id ?? m)).map(m => m.id ?? m)
    }

    readonly property var overviewProviders: {
        if (!modulesEnabled) return []
        const providers = _contributes("overviewProviders")
        return providers.filter(p => isEnabled(p.moduleId))
            .sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    readonly property var overlays: {
        if (!modulesEnabled) return []
        const c = _registry.contributes
        if (c && Array.isArray(c.overlays)) return c.overlays.filter(o => isEnabled(o.moduleId))
            .sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
        return []
    }

    function _emptyRegistry() {
        return {
            schemaVersion: 2,
            modules: [],
            contributes: {
                widgets: [],
                popupSections: [],
                settingsPages: [],
                services: [],
                actions: [],
                overviewProviders: [],
                overlays: []
            }
        }
    }

    // Read registry JSON via FileView (Process inline in Singleton does not start).
    FileView {
        id: registryFileView
        path: loader.registryPath
        onLoaded: {
            try {
                const text = registryFileView.text()
                if (text.length > 0) {
                    const parsed = JSON.parse(text)
                    if (parsed.schemaVersion !== 2 && parsed.schemaVersion !== undefined) {
                        console.warn("[ModuleLoader] Registry schemaVersion mismatch: got", parsed.schemaVersion, "expected 2")
                    }
                    loader._registry = parsed
                    const c = parsed.contributes || {}
                    const wCount = (c.widgets || []).length
                    const pCount = (c.popupSections || []).length
                    const sCount = (c.settingsPages || []).length
                    const oCount = (c.overlays || []).length
                    console.log("[ModuleLoader] Loaded registry v" + (parsed.schemaVersion ?? "?"), JSON.stringify({
                        modules: loader._registry.modules?.length ?? 0,
                        widgets: wCount,
                        popupSections: pCount,
                        settingsPages: sCount,
                        overlays: oCount
                    }))
                }
            } catch (e) {
                console.warn("[ModuleLoader] Failed to parse registry:", e)
            }
        }
        onLoadFailed: error => {
            console.warn("[ModuleLoader] Failed to load registry from '" + loader.registryPath + "':", error)
        }
    }
}
