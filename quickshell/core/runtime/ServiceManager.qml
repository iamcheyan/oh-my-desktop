pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

pragma ComponentBehavior: Bound

/// Central service provider registry for Sumika Shell.
///
/// Services are abstract capabilities (audio, network, power, MPRIS, etc.)
/// registered with a versioned ID. The ServiceManager acts as a broker:
/// modules request a service by ID and receive the best available provider.
///
/// Provider entry: {id, version, owner, provider, available: bool, error: string}
///
//
// IMPORTANT: This is NOT a full provider architecture. All providers are
// still QML singletons loaded in the Core process, wrapped for convenience.
// True hot-pluggable, out-of-process providers require a ServiceApi layer
// that does not exist yet. Do not claim "migration complete" or "replaceable
// providers" based on this facade.
//
/// Currently wraps known services as placeholders (available: false).
/// Real wrapping requires per-service migration.
Singleton {
    id: manager
    /// Emitted when any provider's availability changes.
    signal providersChanged()

    // ── Convenience accessors for core services ──
    // These expose the provider object directly for QML bindings.
    // Modules SHOULD use these instead of importing qs.services directly.
    //
    // Nested property changes on the provider (e.g. Audio.sinks) remain reactive
    // because QML tracks the returned object. Top-level provider swaps (available ->
    // unavailable) are signaled via the `_tick` dependency and providersChanged().
    property int _tick: 0
    onProvidersChanged: _tick++

    /// Audio service provider (Services.Audio singleton)
    readonly property var audio: (_tick, _providers["audio.v1"] ? _providers["audio.v1"].provider : null)
    /// Network service provider (Services.Network singleton)
    readonly property var network: (_tick, _providers["network.v1"] ? _providers["network.v1"].provider : null)
    /// Power service provider ({battery, powerProfiles} wrapper)
    readonly property var power: (_tick, _providers["power.v1"] ? _providers["power.v1"].provider : null)
    /// Notification service provider (Services.Notifications singleton)
    readonly property var notification: (_tick, _providers["notification.v1"] ? _providers["notification.v1"].provider : null)
    /// MPRIS service provider (Services.MprisController singleton)
    readonly property var mpris: (_tick, _providers["mpris.v1"] ? _providers["mpris.v1"].provider : null)
    /// Workspace service provider (Services.HyprlandData singleton)
    readonly property var workspace: (_tick, _providers["workspace.v1"] ? _providers["workspace.v1"].provider : null)
    /// Brightness service provider (Services.Brightness singleton)
    readonly property var brightness: (_tick, _providers["brightness.v1"] ? _providers["brightness.v1"].provider : null)
    /// Tray service provider (TrayService singleton)
    readonly property var tray: (_tick, _providers["tray.v1"] ? _providers["tray.v1"].provider : null)
    /// Bluetooth service provider (Services.BluetoothStatus singleton)
    readonly property var bluetooth: (_tick, _providers["bluetooth.v1"] ? _providers["bluetooth.v1"].provider : null)


    /// Internal provider registry keyed by service ID.
    property var _providers: ({})

    /// Ordered list of service IDs (for iteration).
    property var _order: []

    /// Register a service provider.
    /// Returns true on success, false if ID already exists (conflict).
    /// @param {string} serviceId - Versioned service ID (e.g. "audio.v1")
    /// @param {string} version - Semantic version string (e.g. "1.0.0")
    /// @param {string} owner - Module ID owning this provider
    /// @param {object} provider - Provider object or QML singleton reference
    function register(serviceId, version, owner, provider) {
        if (typeof serviceId !== "string" || serviceId.length === 0) {
            console.warn("[ServiceManager] register: invalid serviceId")
            return false
        }
        if (_providers[serviceId] !== undefined) {
            console.warn("[ServiceManager] register: duplicate serviceId '" + serviceId + "' (owner: " + owner + ")")
            return false
        }
        if (typeof version !== "string" || version.length === 0) {
            console.warn("[ServiceManager] register: invalid version for '" + serviceId + "'")
            return false
        }

        _providers[serviceId] = {
            id: serviceId,
            version: version,
            owner: owner || "unknown",
            provider: provider || null,
            available: false,
            error: ""
        }
        _order.push(serviceId)
        console.log("[ServiceManager] registered '" + serviceId + "' v" + version + " (owner: " + _providers[serviceId].owner + ")")
        return true
    }

    /// Update an existing provider's availability and optional error.
    /// Returns true if updated, false if serviceId not found.
    function setAvailable(serviceId, available, error) {
        const entry = _providers[serviceId]
        if (!entry) {
            console.warn("[ServiceManager] setAvailable: unknown serviceId '" + serviceId + "'")
            return false
        }
        entry.available = available !== false
        entry.error = error || ""
        console.log("[ServiceManager] '" + serviceId + "' available: " + entry.available + (entry.error ? " (" + entry.error + ")" : ""))
        providersChanged()
        return true
    }

    /// Unregister all providers belonging to an owner module.
    /// Returns the array of removed service IDs.
    function unregisterOwner(owner) {
        if (typeof owner !== "string") return []
        const removed = []
        for (var i = _order.length - 1; i >= 0; i--) {
            const e = _providers[_order[i]]
            if (e && e.owner === owner) {
                removed.push(_order[i])
                delete _providers[_order[i]]
                _order.splice(i, 1)
            }
        }
        if (removed.length > 0) {
            console.log("[ServiceManager] unregistered " + removed.length + " providers for owner '" + owner + "': " + removed.join(", "))
        }
        return removed
    }

    /// Resolve a service by ID, returning the best available provider.
    /// Returns the provider entry object or null if no provider is available.
    function resolve(serviceId) {
        const entry = _providers[serviceId]
        if (!entry) {
            console.warn("[ServiceManager] resolve: unknown serviceId '" + serviceId + "'")
            return null
        }
        if (!entry.available) {
            console.warn("[ServiceManager] resolve: service '" + serviceId + "' is not available" + (entry.error ? ": " + entry.error : ""))
            return null
        }
        // Return a snapshot to prevent external mutation
        return {
            id: entry.id,
            version: entry.version,
            owner: entry.owner,
            provider: entry.provider,
            available: entry.available,
            error: entry.error
        }
    }

    /// Check if a service is registered and available.
    function isAvailable(serviceId) {
        const entry = _providers[serviceId]
        return entry !== undefined && entry.available
    }

    /// List all registered services.
    /// Returns an array of {id, version, owner, available} objects.
    function listServices() {
        const result = []
        for (var i = 0; i < _order.length; i++) {
            const e = _providers[_order[i]]
            result.push({
                id: e.id,
                version: e.version,
                owner: e.owner,
                available: e.available
            })
        }
        return result
    }

    /// Register built-in service providers.
    /// Wraps existing QML service singletons as Phase 5 providers.
    function _registerPlaceholders() {
        // ── Audio: wrap Audio singleton (always available) ──
        this.register("audio.v1",    "1.0.0", "core",   Services.Audio)
        this.setAvailable("audio.v1", true, "")

        // ── Network: wrap Network singleton (always available) ──
        this.register("network.v1",  "1.0.0", "core",   Services.Network)
        this.setAvailable("network.v1", true, "")

        // ── Power: wrap Battery + PowerProfiles singletons ──
        this.register("power.v1",    "1.0.0", "core",   {
            battery: Services.Battery,
            powerProfiles: Services.PowerProfiles
        })
        this.setAvailable("power.v1",
            Services.Battery.available,
            Services.Battery.available ? "" : "no battery detected")

        // ── Workspace: wrap HyprlandData (consumers use ServiceManager.workspace.*) ──
        this.register("workspace.v1", "1.0.0", "core", Services.HyprlandData)
        this.setAvailable("workspace.v1", true, "")
        // ── Brightness: wrap Brightness singleton (always available) ──
        this.register("brightness.v1", "1.0.0", "core", Services.Brightness)
        this.setAvailable("brightness.v1", true, "")
        // ── Tray: wrap TrayService singleton (always available) ──
        // ── Bluetooth: wrap BluetoothStatus singleton ──
        this.register("bluetooth.v1", "1.0.0", "core", Services.BluetoothStatus)
        this.setAvailable("bluetooth.v1",
            Services.BluetoothStatus.available,
            Services.BluetoothStatus.available ? "" : "no bluetooth adapter")
        this.register("tray.v1", "1.0.0", "core", Services.TrayService)
        this.setAvailable("tray.v1", true, "")
        // ── Notification: wrap Notifications singleton ──
        this.register("notification.v1", "1.0.0", "core", Services.Notifications)
        this.setAvailable("notification.v1",
            typeof Services.Notifications !== "undefined",
            typeof Services.Notifications === "undefined" ? "notifications not available" : "")

        // ── MPRIS: real provider wrapping existing MprisController singleton ──
        this.register("mpris.v1", "1.0.0", "core", Services.MprisController)
        this.setAvailable("mpris.v1",
            Services.MprisController.availablePlayers.length > 0,
            Services.MprisController.availablePlayers.length === 0
                ? "no MPRIS players found" : "")
        console.log("[ServiceManager] Registered 9 providers (audio, network, power, workspace, brightness, notification, mpris, tray, bluetooth)")
    }
    /// Watch MPRIS player changes to update availability dynamically.
    readonly property Connections _mprisWatcher: Connections {
        target: Services.MprisController

        function onAvailablePlayersChanged(): void {
            const hasPlayers = Services.MprisController.availablePlayers.length > 0
            manager.setAvailable("mpris.v1", hasPlayers,
                hasPlayers ? "" : "no MPRIS players found")
        }
    }

    /// Watch Battery availability (laptop detection).
    readonly property Connections _batteryWatcher: Connections {
        target: Services.Battery

        function onAvailableChanged(): void {
            manager.setAvailable("power.v1",
                Services.Battery.available,
                Services.Battery.available ? "" : "no battery detected")
        }
    }


    /// Register services declared by registry modules.
    /// Reads ModuleLoader modules and their contributed services.
    function _registerFromRegistry() {
        if (typeof ModuleLoader === "undefined") return
        const mods = ModuleLoader.modules
        if (!mods || mods.length === 0) return

        var count = 0
        for (var mi = 0; mi < mods.length; mi++) {
            var m = mods[mi]
            if (!ModuleLoader.isEnabled(m.id)) continue
            var svcs = m.contributes ? m.contributes.services : null
            if (!svcs || svcs.length === 0) continue

            for (var si = 0; si < svcs.length; si++) {
                var svcId = svcs[si]
                // Skip if already registered (core placeholders take priority)
                if (_providers[svcId] !== undefined) {
                    console.log("[ServiceManager] registry service '" + svcId + "' from '" + m.id + "' — skipped, already registered by '" + _providers[svcId].owner + "'")
                    continue
                }
                this.register(svcId, "1.0.0", m.id, null)
                console.log("[ServiceManager] registered registry service '" + svcId + "' from module '" + m.id + "'")
                count++
            }
        }
        if (count > 0) {
            console.log("[ServiceManager] registered " + count + " services from registry modules")
        }
    }

    Component.onCompleted: {
        _registerPlaceholders()
        _registerFromRegistry()
    }
}
