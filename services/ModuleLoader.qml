pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/// Modules live in ~/development/sumika-modules/<id>/ and are discovered
/// by the startup script, which writes $XDG_RUNTIME_DIR/sumika-shell/modules.json.
/// This singleton parses that JSON (v2 schema) and exposes contributions
/// for dynamic loading via Repeater + Loader.
///
/// Registry v2 compatibility:
/// - Primary fields: contributes.widgets, contributes.popupSections,
///   contributes.settingsPages, contributes.services, contributes.actions
/// - v1 fallback: barButtons, popupSections, settingsPages (flat top-level keys)
/// - v1 manifests are converted to v2 by the startup script's merge_manifest()

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
        const disabled = Config.options.modules?.disabled ?? []
        if (Array.isArray(disabled) && disabled.indexOf(moduleId) >= 0) return false
        return true
    }

    // Helper: read a contributes array with v1 fallback.
    function _contributes(key, v1key) {
        const c = _registry.contributes
        if (c && Array.isArray(c[key]) && c[key].length > 0) {
            return c[key]
        }
        // v1 fallback (flat top-level key)
        const v1 = _registry[v1key]
        if (Array.isArray(v1)) return v1
        return []
    }

    function _filterBarButtons(slot) {
        const buttons = _contributes("widgets", "barButtons")
        // No fallback: if registry has no widgets, return empty.
        // Builtin alwaysShow buttons come from builtin/bar.json merged at startup.
        const result = []
        for (var i = 0; i < buttons.length; i++) {
            var b = buttons[i]
            if (b.slot !== slot) continue
            // alwaysShow buttons visible regardless of module state
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
        var coreTypes = {wifi:1, bluetooth:1, audio:1, display:1, battery:1, notifications:1, voice:1, inputMethod:1, keyboard:1, session:1, xkb:1, tools:1}
        const sections = _contributes("popupSections", "popupSections")
        return sections.filter(s => {
            if (!isEnabled(s.moduleId)) return false
            if (!s.type || typeof s.type !== 'string') {
                console.warn("[ModuleLoader] popupSection missing type:", JSON.stringify(s))
                return false
            }
            return true
        })
    }

    readonly property var settingsPages: {
        if (!modulesEnabled) return []
        const pages = _contributes("settingsPages", "settingsPages").filter(p => isEnabled(p.moduleId))
        return pages.sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
    }

    readonly property var activeModuleIds: {
        if (!modulesEnabled) return []
        return (_registry.modules ?? []).filter(m => isEnabled(m.id ?? m)).map(m => m.id ?? m)
    }

    readonly property var overviewProviders: {
        if (!modulesEnabled) return []
        const providers = _contributes("overviewProviders", "overviewProviders")
        return providers.filter(p => isEnabled(p.moduleId))
            .sort((a, b) => (a.order ?? 100) - (b.order ?? 100))
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
                overviewProviders: []
            }
        }
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
                        const parsed = JSON.parse(text)
                        // Accept both v1 and v2 schemas
                        if (parsed.schemaVersion !== 2 && parsed.schemaVersion !== 1 && parsed.schemaVersion !== undefined) {
                            console.warn("[ModuleLoader] Registry schemaVersion mismatch: got", parsed.schemaVersion, "expected 2")
                        }
                        loader._registry = parsed
                        const c = parsed.contributes || {}
                        const wCount = (c.widgets || parsed.barButtons || []).length
                        const pCount = (c.popupSections || parsed.popupSections || []).length
                        const sCount = (c.settingsPages || parsed.settingsPages || []).length
                        console.log("[ModuleLoader] Loaded registry v" + (parsed.schemaVersion ?? "?"), JSON.stringify({
                            modules: loader._registry.modules?.length ?? 0,
                            widgets: wCount,
                            popupSections: pCount,
                            settingsPages: sCount
                        }))
                    }
                } catch (e) {
                    console.warn("[ModuleLoader] Failed to parse registry:", e)
                }
            }
        }
        running: true
    }
}
