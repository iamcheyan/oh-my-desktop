pragma Singleton
import QtQuick

pragma ComponentBehavior: Bound

/// Service Lifecycle API — external interface for service management.
///
/// Provides a clean facade over ServiceManager for use by modules and UI
/// components that need to query, register, or resolve service providers
/// without direct dependency on runtime internals.
///
/// Methods return service descriptors or null when the requested service
/// is unavailable. This API is intended for module-level service discovery
/// and lifecycle management.
Singleton {
    id: api

    /// Resolve a service provider by ID.
    /// Returns the provider entry {id, version, owner, provider, available, error}
    /// or null if not found or unavailable.
    /// @param {string} serviceId - Versioned service identifier (e.g. "audio.v1")
    function resolve(serviceId) {
        const mgr = _resolveManager()
        return mgr ? mgr.resolve(serviceId) : null
    }

    /// Check whether a service is registered and available.
    /// @param {string} serviceId - Service identifier to query
    function isAvailable(serviceId) {
        const mgr = _resolveManager()
        return mgr ? mgr.isAvailable(serviceId) : false
    }

    /// List all registered services.
    /// Returns an array of {id, version, owner, available} objects.
    function listServices() {
        const mgr = _resolveManager()
        return mgr ? mgr.listServices() : []
    }

    /// Register a new service provider.
    /// Returns true on success, false if the ID already exists.
    /// @param {string} serviceId - Versioned service identifier (e.g. "audio.v1")
    /// @param {string} version - Semantic version string
    /// @param {string} owner - Module ID owning this provider
    /// @param {object} provider - Provider object or QML singleton reference
    function register(serviceId, version, owner, provider) {
        const mgr = _resolveManager()
        return mgr ? mgr.register(serviceId, version, owner, provider) : false
    }

    /// Update an existing provider's availability status.
    /// Returns true if updated, false if serviceId not found.
    /// @param {string} serviceId - Service identifier to update
    /// @param {boolean} available - Whether the service is now available
    /// @param {string} error - Optional error description
    function setAvailable(serviceId, available, error) {
        const mgr = _resolveManager()
        return mgr ? mgr.setAvailable(serviceId, available, error) : false
    }

    /// Unregister all providers belonging to an owner.
    /// Returns the array of removed service IDs.
    /// @param {string} owner - Module ID whose providers to remove
    function unregisterOwner(owner) {
        const mgr = _resolveManager()
        return mgr ? mgr.unregisterOwner(owner) : []
    }

    /// Resolve the ServiceManager singleton.
    /// Returns null if the runtime module is not available.
    property var _manager: null
    function _resolveManager() {
        if (_manager === null) {
            try {
                const module = Qt.createQmlObject(
                    "import qs.core.runtime; ServiceManager {}",
                    this, "_serviceApiLoader"
                )
                _manager = module
            } catch (e) {
                console.warn("[ServiceApi] ServiceManager not available: " + e)
                _manager = false
            }
        }
        return _manager || null
    }

    /// Component completed handler — warm the manager reference.
    Component.onCompleted: {
        _resolveManager()
    }
}
