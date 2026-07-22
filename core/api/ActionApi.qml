pragma Singleton
import QtQuick
import Quickshell

pragma ComponentBehavior: Bound

/// Action Dispatch API — external interface for dispatching actions.
///
/// Provides a clean facade over ActionManager for use by modules and UI
/// components that need to trigger actions without direct dependency on
/// the runtime internals.
///
/// All action IDs referenced here MUST be registered with ActionManager
/// before dispatch. The API delegates to ActionManager.invoke() and
/// returns its result verbatim.
Singleton {
    id: api

    /// Dispatch an action by ID with optional parameters.
    /// Returns {success: bool, error?: string}
    /// @param {string} id - Globally unique action identifier (e.g. "session.lock")
    /// @param {object} params - Optional parameters forwarded to the action handler
    function dispatch(id, params) {
        return _resolveManager().invoke(id, params || {})
    }

    /// Check whether an action is available (registered and enabled).
    /// @param {string} id - Action identifier to query
    function isAvailable(id) {
        const mgr = _resolveManager()
        return mgr && mgr.isAvailable(id)
    }

    /// Query action metadata.
    /// Returns the action descriptor or null if not found.
    /// @param {string} id - Action identifier to query
    function query(id) {
        const mgr = _resolveManager()
        return mgr ? mgr.query(id) : null
    }

    /// Resolve the ActionManager singleton.
    /// Returns null if the runtime module is not available.
    property var _manager: null
    function _resolveManager() {
        if (_manager === null) {
            try {
                const module = Qt.createQmlObject(
                    "import qs.core.runtime; ActionManager {}",
                    this, "_actionApiLoader"
                )
                _manager = module
            } catch (e) {
                console.warn("[ActionApi] ActionManager not available: " + e)
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
