pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.runtime
import qs.services as Svcs

pragma ComponentBehavior: Bound

/// Central action registry for Sumika Shell.
///
/// All system behaviors are registered as Actions with stable IDs.
/// UI components call `invoke()` instead of executing commands directly.
///
/// Handler types:
///   {type: "qml", call: function}         — direct QML function reference
///   {type: "process", command: [argv...]}  — safe process launch via execDetached
///   {type: "ipc", target: target, method: func}  — IPC handler call (IpcHandler dispatch)
///   {type: "shell", command: string}       — well-known shell string (legacy, avoid)
///
/// Action object: {id, owner, title, description, handler, paramsSchema?, timeout?, enabled}
Singleton {
    id: manager

    /// Registered actions keyed by ID.
    property var _actions: ({})

    /// Ordered list of action IDs (for iteration).
    property var _order: []

    /// Register an action.
    /// Returns true on success, false if ID already exists (conflict).
    /// @param {string} id - Globally unique action ID (e.g. "session.lock")
    /// @param {string} owner - Module ID owning this action
    /// @param {string} title - Human-readable title
    /// @param {object} handler - Handler descriptor (see handler types above)
    /// @param {object} options - Optional {description, paramsSchema, timeout, enabled}
    function register(id, owner, title, handler, options) {
        if (typeof id !== "string" || id.length === 0) {
            console.warn("[ActionManager] register: invalid id")
            return false
        }
        if (_actions[id] !== undefined) {
            console.warn("[ActionManager] register: duplicate action ID '" + id + "' (owner: " + owner + ")")
            return false
        }
        if (typeof handler !== "object" || !handler.type) {
            console.warn("[ActionManager] register: invalid handler for '" + id + "'")
            return false
        }

        const opts = options || {}
        _actions[id] = {
            id: id,
            owner: owner || "unknown",
            title: title || id,
            description: opts.description || "",
            handler: handler,
            paramsSchema: opts.paramsSchema || null,
            timeout: opts.timeout || 0,
            enabled: opts.enabled !== false,
            registeredAt: Date.now()
        }
        _order.push(id)
        console.log("[ActionManager] registered '" + id + "' (owner: " + _actions[id].owner + ")")
        return true
    }

    /// Unregister an action by ID.
    function unregister(id) {
        if (_actions[id] === undefined) return false
        const owner = _actions[id].owner
        delete _actions[id]
        const idx = _order.indexOf(id)
        if (idx >= 0) _order.splice(idx, 1)
        console.log("[ActionManager] unregistered '" + id + "' (owner: " + owner + ")")
        return true
    }

    /// Unregister all actions belonging to an owner module.
    function unregisterOwner(owner) {
        if (typeof owner !== "string") return
        const removed = []
        for (var i = _order.length - 1; i >= 0; i--) {
            const a = _actions[_order[i]]
            if (a && a.owner === owner) {
                removed.push(_order[i])
                delete _actions[_order[i]]
                _order.splice(i, 1)
            }
        }
        if (removed.length > 0) {
            console.log("[ActionManager] unregistered " + removed.length + " actions for owner '" + owner + "': " + removed.join(", "))
        }
        return removed
    }

    /// Query an action's current state.
    /// Returns the action object or null if not found.
    function query(id) {
        const a = _actions[id]
        if (!a) return null
        return {
            id: a.id,
            owner: a.owner,
            title: a.title,
            description: a.description,
            available: a.enabled,
            handlerType: a.handler.type,
            paramsSchema: a.paramsSchema,
            timeout: a.timeout
        }
    }
    /// Resolve a module's absolute directory path from ModuleLoader's registry.
    /// Returns empty string if module or registry unavailable.
    function _modulePath(moduleId) {
        if (typeof ModuleLoader === "undefined" || !ModuleLoader._registry || !ModuleLoader._registry.modules)
            return ""
        for (var i = 0; i < ModuleLoader._registry.modules.length; i++) {
            var m = ModuleLoader._registry.modules[i]
            if (m.id === moduleId) return m.path || ""
        }
        return ""
    }

    /// Check if an action is available (registered, enabled, AND module-enabled).
    function isAvailable(id) {
        const a = _actions[id]
        if (!a || !a.enabled) return false
        // Dynamic module enabled check — reacts to Config changes via FileView.
        // "core" owner is never module-disabled.
        if (a.owner !== "core" && !ModuleLoader.isEnabled(a.owner)) return false
        return true
    }

    /// Invoke an action by ID with optional parameters.
    /// Returns {success: bool, error?: string}
    function invoke(id, params) {
        const exists = _actions[id]
        if (!exists) {
            console.warn("[ActionManager] invoke: unknown action '" + id + "'")
            return {success: false, error: "unknown_action"}
        }
        if (!exists.enabled) {
            console.warn("[ActionManager] invoke: action '" + id + "' is disabled")
            return {success: false, error: "action_disabled"}
        }
        // Dynamic module enabled check — reacts to Config changes via FileView.
        // Non-core actions require the owning module to be enabled.
        if (exists.owner !== "core" && !ModuleLoader.isEnabled(exists.owner)) {
            console.log("[ActionManager] invoke: action '" + id + "' module '" + exists.owner + "' is disabled")
            return {success: false, error: "module_disabled"}
        }
        return _doInvoke(exists, params)
    }

    /// Internal: execute a verified action's handler.
    function _doInvoke(a, params) {

        const h = a.handler
        const startTime = Date.now()
        function _elapsed() { return Date.now() - startTime }

        try {
            switch (h.type) {
                case "qml":
                    if (typeof h.call === "function") {
                        h.call(params)
                    } else {
                        console.error("[ActionManager] invoke '" + a.id + "': handler.call is not a function")
                        return {success: false, error: "invalid_handler"}
                    }
                    break
                case "process":
                    if (Array.isArray(h.command) && h.command.length > 0) {
                        var cmd = h.command
                        if (params && params.page) {
                            cmd = h.command.concat([params.page])
                        }
                        Quickshell.execDetached(cmd)
                    } else {
                        console.error("[ActionManager] invoke '" + a.id + "': invalid process command")
                        return {success: false, error: "invalid_command"}
                    }
                    break

                case "supervised":
                    // Process managed by ProcessSupervisor for lifecycle tracking
                    if (!h.instanceId) {
                        console.error("[ActionManager] invoke '" + a.id + "': supervised handler missing instanceId")
                        return {success: false, error: "missing_instance_id"}
                    }
                    var ps = ProcessSupervisor
                    if (!ps) {
                        // Fallback to direct exec if ProcessSupervisor not available
                        if (Array.isArray(h.command) && h.command.length > 0) {
                            Quickshell.execDetached(h.command)
                        } else {
                            return {success: false, error: "invalid_command"}
                        }
                    } else {
                        // Ensure registered and start
                        var state = ps.getState(h.instanceId)
                        if (state === 0) { // Stopped
                            ps.register(h.owner || h.instanceId, h.instanceId,
                                h.command, h.options || {})
                        }
                        ps.start(h.instanceId)
                    }
                    break

                case "ipc":
                    console.warn("[ActionManager] invoke '" + a.id + "': IPC handler dispatch not yet supported directly")
                    return {success: false, error: "handler_unavailable"}
                case "shell":
                    if (typeof h.command === "string" && h.command.length > 0) {
                        Quickshell.execDetached(["bash", "-lc", h.command])
                    } else {
                        return {success: false, error: "invalid_command"}
                    }
                    break

                default:
                    console.error("[ActionManager] invoke '" + a.id + "': unknown handler type '" + h.type + "'")
                    return {success: false, error: "unknown_handler_type"}
            }

            console.log("[ActionManager] invoked '" + a.id + "' (" + _elapsed() + "ms)")
            return {success: true}
        } catch (e) {
            console.error("[ActionManager] invoke '" + a.id + "' failed (" + _elapsed() + "ms): " + e)
            return {success: false, error: String(e)}
        }
    }

    /// Get a serializable array of all registered actions.
    /// Returns an array of {id, owner, title, enabled, handlerType}.
    function getActionList() {
        const result = []
        for (var i = 0; i < _order.length; i++) {
            const a = _actions[_order[i]]
            result.push({
                id: a.id,
                owner: a.owner,
                title: a.title,
                enabled: a.enabled,
                handlerType: a.handler.type
            })
        }
        return result
    }

    /// Number of registered actions.
    readonly property int count: _order.length

    /// Register core startup actions.
    function _registerBuiltins() {
        // Session actions
        this.register("session.lock", "core", "Lock session", {
            type: "qml",
            call: function() { Svcs.LockService.lock() }
        }, {description: "Lock the current session with the configured screen locker"})

        this.register("session.logout", "core", "Log out", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-logout"]
        }, {description: "End the current Hyprland session"})

        this.register("session.reboot", "core", "Reboot", {
            type: "shell",
            command: "reboot || loginctl reboot"
        }, {description: "Restart the computer"})

        this.register("session.shutdown", "core", "Shut down", {
            type: "shell",
            command: "systemctl poweroff || loginctl poweroff"
        }, {description: "Power off the computer"})

        this.register("session.suspend", "core", "Suspend", {
            type: "shell",
            command: "systemctl suspend || loginctl suspend"
        }, {description: "Suspend to RAM"})

        this.register("session.hibernate", "core", "Hibernate", {
            type: "shell",
            command: "systemctl hibernate || loginctl hibernate"
        }, {description: "Suspend to disk"})

        this.register("session.logout.save", "core", "Log out and save session", {
            type: "shell",
            command: Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-session save-auto >/dev/null 2>&1; " + Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-logout"
        }, {description: "Save session snapshot then log out"})

        this.register("session.reboot.save", "core", "Reboot after saving session", {
            type: "shell",
            command: Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-session save-auto >/dev/null 2>&1; reboot || loginctl reboot"
        }, {description: "Save session snapshot then reboot"})

        this.register("session.shutdown.save", "core", "Shut down after saving session", {
            type: "shell",
            command: Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-session save-auto >/dev/null 2>&1; systemctl poweroff || loginctl poweroff"
        }, {description: "Save session snapshot then power off"})

        // Shell actions
        this.register("shell.reload", "core", "Reload shell", {
            type: "process",
            command: ["bash", Quickshell.env("OMD_REPO_ROOT") + "/scripts/reload-quickshell"]
        }, {description: "Reload the Quickshell UI"})

        // Settings
        this.register("settings.open", "core", "Open settings", {
            type: "process",
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-settings", "open"]
        }, {description: "Open system settings", paramsSchema: {type: "object", properties: {page: {type: "string"}}}})

        // Overview
        this.register("overview.open", "core", "Toggle overview", {
            type: "process",
            command: ["qs", "-p", Quickshell.env("OMD_REPO_ROOT") + "/modules/overview", "ipc", "call", "overview", "toggle"]
        }, {description: "Open or close the overview/workspace view"})

        // Clipboard — managed via ProcessSupervisor for lifecycle tracking
        // Resolve path from external module (clipboard lives in sumika-modules, not OMD repo)
        var clipDir = this._modulePath("clipboard")
        if (!clipDir) clipDir = Quickshell.env("OMD_REPO_ROOT") // fallback
        var clipCmd = clipDir + "/bin/omd-clipboard"

        this.register("clipboard.toggle", "clipboard", "Toggle clipboard", {
            type: "supervised",
            instanceId: "clipboard",
            owner: "clipboard",
            command: [clipCmd, "toggle"],
            options: {readyTimeout: 10, restartLimit: 3}
        }, {description: "Open or close the clipboard history"})

        this.register("clipboard.toggleBar", "clipboard", "Toggle clipboard at bar", {
            type: "shell",
            command: clipCmd + " toggle-at-bar"
        }, {description: "Open or close the clipboard anchored to the top bar"})

        this.register("clipboard.open", "clipboard", "Open clipboard", {
            type: "supervised",
            instanceId: "clipboard",
            owner: "clipboard",
            command: [clipCmd, "open"],
            options: {readyTimeout: 10, restartLimit: 3}
        }, {description: "Open the clipboard history"})

        this.register("clipboard.close", "clipboard", "Close clipboard", {
            type: "supervised",
            instanceId: "clipboard",
            owner: "clipboard",
            command: [clipCmd, "close"],
            options: {readyTimeout: 10, restartLimit: 3}
        }, {description: "Close the clipboard history"})

        this.register("clipboard.paste", "clipboard", "Paste clipboard selection", {
            type: "supervised",
            instanceId: "clipboard",
            owner: "clipboard",
            command: [clipCmd, "paste"],
            options: {readyTimeout: 10, restartLimit: 3}
        }, {description: "Paste the currently selected clipboard entry"})
        // Load additional actions from module manifests in the registry
        this._registerFromRegistry()
    }

    /// Register actions declared in module manifests via the registry.
    /// Module actions with a 'handler' field are registered as-is; application
    /// modules (kind=application) without explicit handlers get a process action
    function _registerFromRegistry() {
        // Access ModuleLoader for registry data
        var reg = ModuleLoader ? ModuleLoader._registry : null
        if (!reg || !reg.modules) return

        var actions = reg.contributes ? (reg.contributes.actions || []) : []
        // Build a map of moduleId -> entry for application modules
        var moduleEntries = ({})
        var modules = reg.modules || []
        for (var mi = 0; mi < modules.length; mi++) {
            var m = modules[mi]
            if (m.kind === "application" && m.entry && m.entry.command) {
                moduleEntries[m.id] = m.entry
            }
        }

        for (var ai = 0; ai < actions.length; ai++) {
            var a = actions[ai]
            if (!a || !a.id) continue
            if (_actions[a.id] !== undefined) continue // skip duplicates from builtins

            var owner = a.moduleId || "unknown"
            var entry = moduleEntries[owner]

            // Build handler: prefer explicit handler field; for application
            // modules without explicit handler, use process command from entry
            var handler = null
            if (a.handler) {
                var parts = a.handler.split(":")
                var htype = parts[0]
                if (htype === "ipc") {
                    handler = {type: "ipc", target: parts[1]}
                } else if (htype === "process") {
                    // Format: "process:command arg1 arg2"
                    var rest = parts.slice(1).join(":")
                    handler = {type: "process", command: rest.split(" ")}
                } else if (htype === "action") {
                    // Delegate to another action — resolve at invoke time
                    handler = {type: "delegate", targetId: parts[1]}
                }
            } else if (entry && entry.command) {
                handler = {type: "process", command: entry.command.slice()}
            }

            if (!handler) {
                console.warn("[ActionManager] _registerFromRegistry: no handler for action '" + a.id + "' (module: " + owner + ")")
                continue
            }

            this.register(a.id, owner, a.name || a.id, handler,
                {description: a.description || ""})
        }

        console.log("[ActionManager] registered " + actions.length + " actions from registry")
    }
}
