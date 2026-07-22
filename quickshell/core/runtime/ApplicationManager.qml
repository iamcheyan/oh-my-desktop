pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.core.runtime

/// High-level manager for application modules.
///
/// Reads manifests from registered modules via ModuleLoader,
/// registers each app module's command with ProcessSupervisor,
/// and exposes a clean launch/stop/query by moduleId or app name.
///
/// This is the public API consumers use instead of calling
/// ProcessSupervisor directly (though direct access is fine for
/// advanced use).
Singleton {
    id: appManager

    // ── Public signals ──
    signal appStateChanged(string instanceId, string state)

    // ── Properties ──

    /// Map of registered apps: { instanceId: queryObject, ... }
    readonly property var apps: ({})
    readonly property var supervisor: ProcessSupervisor

    // ── Initialization ──

    /// Register all app modules known to ModuleLoader.
    /// Call once at startup after ModuleLoader is ready.
    function initialize() {
        console.log("[ApplicationManager] initializing from ModuleLoader manifest...")

        // Access the module registry via ModuleLoader
        const registry = ModuleLoader.registry
        if (!registry || !registry.modules) {
            console.warn("[ApplicationManager] ModuleLoader registry not ready yet")
            retryTimer.start()
            return
        }
        _processRegistry(registry)
    }

    // Retry if registry not ready yet
    property Timer retryTimer: Timer {
        id: retryTimer
        interval: 500
        repeat: true
        onTriggered: {
            const registry = ModuleLoader.registry
            if (registry && registry.modules) {
                stop()
                _processRegistry(registry)
            }
        }
    }

    function _processRegistry(registry) {
        const modEntries = registry.modules
        if (!Array.isArray(modEntries)) {
            console.warn("[ApplicationManager] registry.modules is not an array — got " + typeof modEntries)
            return
        }

        var count = 0
        for (var i = 0; i < modEntries.length; i++) {
            const mod = modEntries[i]
            if (!mod || !mod.id) continue

            // Only application-kind modules are supervised
            if (mod.kind !== "application") continue
            if (!mod.entry || !Array.isArray(mod.entry.command)) {
                console.warn("[ApplicationManager] module '" + mod.id + "' is application kind but has no entry.command array")
                continue
            }

            const entry = mod.entry
            const instanceId = entry.instance || ("omd-" + mod.id)

            ProcessSupervisor.register(mod.id, instanceId, entry.command, {
                readyTimeout: entry.readyTimeout || 10,
                restartLimit: 5,
                logTag: mod.id,
                cwd: mod.path || "",
                env: null
            })

            apps[instanceId] = { instanceId, moduleId: mod.id, appName: mod.id }
            count++
        }

        console.log("[ApplicationManager] registered " + count + " application module(s)")
    }

    // ── Public API ──

    /// Launch an app by instanceId. Returns true if launch was initiated.
    /// If already running, does nothing (singleton).
    function launch(instanceId) {
        return ProcessSupervisor.start(instanceId)
    }

    /// Stop an app by instanceId.
    function close(instanceId) {
        return ProcessSupervisor.stop(instanceId)
    }

    /// Launch an app, force-restarting if in failed state.
    function launchForce(instanceId) {
        return ProcessSupervisor.start(instanceId, {forceRestart: true})
    }

    /// Get state name for an instanceId.
    function stateOf(instanceId) {
        return ProcessSupervisor.getStateName(instanceId)
    }

    /// Get full query object.
    function query(instanceId) {
        return ProcessSupervisor.query(instanceId)
    }

    /// List all registered apps with their states.
    function list() {
        return ProcessSupervisor.listProcesses()
    }

    /// List only ready (healthy) apps.
    function listReady() {
        return ProcessSupervisor.listProcesses().filter(p => p.stateName === "ready")
    }

    /// Health check across all managed apps.
    function healthCheck() {
        return ProcessSupervisor.healthCheck()
    }

    IpcHandler {
        target: "app-manager"

        function launch(instanceId: string): string {
            const ok = appManager.launch(instanceId)
            return ok ? "launched" : "failed"
        }

        function start(instanceId: string): string {
            return launch(instanceId)
        }

        function close(instanceId: string): string {
            const ok = appManager.close(instanceId)
            return ok ? "closed" : "not_found"
        }

        function stop(instanceId: string): string {
            return close(instanceId)
        }

        function state(instanceId: string): string {
            return appManager.stateOf(instanceId)
        }

        function list(): string {
            const procs = appManager.list()
            return procs.map(p => p.instanceId + "=" + p.stateName).join("\n")
        }

        function health(): string {
            const hc = appManager.healthCheck()
            return "healthy:" + hc.healthy.length + " unhealthy:" + hc.unhealthy.length
        }
    }
}
