pragma Singleton
import QtQuick
import Quickshell
import qs.core.runtime

pragma ComponentBehavior: Bound

/// Collects runtime state snapshots for TUI diagnostics and health checks.
///
/// The DiagnosticReporter queries core runtime singletons (ServiceManager,
/// ModuleLoader, ActionManager, etc.) and returns a flat state object
/// that can be rendered by diagnostic tools or exported for telemetry.
Singleton {
    id: reporter

    /// Collect a snapshot of current runtime state.
    /// Returns an object with paths to the state of each core subsystem.
    /// Returns a flat object of key-value pairs describing runtime health.
    function collectInfo() {
        const info = {
            timestamp: new Date().toISOString(),
            services: {},
            modules: {},
            actions: {}
        }

        // Service states
        if (typeof ServiceManager !== "undefined") {
            const svcs = ServiceManager.listServices()
            info.services.count = svcs.length
            info.services.list = svcs
        }

        // Module states
        if (typeof ModuleLoader !== "undefined") {
            info.modules.loaded = ModuleLoader.loadedCount !== undefined
                ? ModuleLoader.loadedCount : "unknown"
        }

        // Action states
        if (typeof ActionManager !== "undefined") {
            info.actions.count = ActionManager.ids !== undefined
                ? ActionManager.ids.length : "unknown"
        }

        return info
    }
}
