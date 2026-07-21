pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/// Modules live in ~/development/sumika-modules/<id>/ and are discovered
/// by the startup script, which writes $XDG_RUNTIME_DIR/sumika-shell/modules.json.
/// This singleton parses that JSON and exposes bar buttons, popup sections,
/// and settings pages for dynamic loading via Repeater + Loader.

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


    function _filterBarButtons(slot) {
        const buttons = _registry.barButtons ?? []
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
     *
     * For full popup replacement (replacing the core content entirely),
     * a future `popupRoutes` capability will be introduced. Until then,
     * all contributions go through this section channel and are always
     * shown after the core contentLoader.
     */
    readonly property var popupSections: {
        if (!modulesEnabled) return []
        var coreTypes = {wifi:1, bluetooth:1, audio:1, display:1, battery:1, notifications:1, voice:1, inputMethod:1, keyboard:1, session:1, xkb:1, tools:1}
        return (_registry.popupSections ?? []).filter(s => {
            if (!isEnabled(s.moduleId)) return false
            // Validate required fields
            if (!s.type || typeof s.type !== 'string') {
                console.warn("[ModuleLoader] popupSection missing type:", JSON.stringify(s))
                return false
            }
            // Warn if section might be a full route (core popup content exists for this type)
            if (s.type in coreTypes && (!s.contributionType || s.contributionType === "section")) {
                // This is expected for modules adding supplemental content (e.g. MPRIS in audio)
                // Log at debug level if/when we add verbose logging
            }
            return true
        })
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
        return { schemaVersion: 0, modules: [], barButtons: [], popupSections: [], settingsPages: [] }
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
                        // Validate schemaVersion
                        if (parsed.schemaVersion !== 1 && parsed.schemaVersion !== undefined) {
                            console.warn("[ModuleLoader] Registry schemaVersion mismatch: got", parsed.schemaVersion, "expected 1")
                        }
                        loader._registry = parsed
                        // Safety check: warn if registry has no buttons
                        if (!parsed.barButtons || parsed.barButtons.length === 0) {
                            console.warn("[ModuleLoader] Registry has no barButtons — bar will be empty")
                        }
                        console.log("[ModuleLoader] Loaded registry:", JSON.stringify({
                            schemaVersion: parsed.schemaVersion,
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
        running: true
    }
}