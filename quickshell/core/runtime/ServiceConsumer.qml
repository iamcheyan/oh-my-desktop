import QtQuick
import qs.core.runtime

/// Reactive consumer for a ServiceManager service provider.
///
/// Connects to ServiceManager.providersChanged to stay in sync when
/// provider availability changes dynamically (e.g. MPRIS players appearing).
///
/// Usage:
///   ServiceConsumer {
///       id: audio
///       serviceId: "audio.v1"
///   }
///   // then: audio.provider.defaultSink
///
/// For inline access in simple bindings, use ServiceManager convenience
/// accessors (ServiceManager.audio, ServiceManager.network, etc.).
QtObject {
    id: root

    /// Versioned service ID to consume (e.g. "audio.v1", "network.v1").
    property string serviceId: ""

    /// The resolved provider object (null when unavailable).
    readonly property var provider: _provider

    /// Whether the service is available.
    readonly property bool available: _available

    /// Error message from the provider (empty string when available).
    readonly property string error: _error

    /// Internal state — updated reactively via _sync().
    property var _provider: null
    property bool _available: false
    property string _error: ""

    /// Resolve the current serviceId through ServiceManager.
    function _sync() {
        if (root.serviceId.length === 0) {
            _provider = null
            _available = false
            _error = ""
            return
        }
        const entry = ServiceManager.resolve(root.serviceId)
        if (entry) {
            _provider = entry.provider
            _available = entry.available
            _error = entry.error
        } else {
            _provider = null
            _available = false
            _error = "service not registered: " + root.serviceId
        }
    }

    /// Re-resolve when serviceId changes.
    onServiceIdChanged: {
        _sync()
    }

    /// React to ServiceManager provider availability changes.
    readonly property Connections _watcher: Connections {
        target: ServiceManager
        function onProvidersChanged(): void { root._sync() }
    }

    Component.onCompleted: _sync()
}
