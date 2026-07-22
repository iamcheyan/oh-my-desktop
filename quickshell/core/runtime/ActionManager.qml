pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services as Services

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

    /// Check if an action is available (registered AND enabled).
    function isAvailable(id) {
        const a = _actions[id]
        return a !== undefined && a.enabled
    }

    /// Invoke an action by ID with optional parameters.
    /// Returns {success: bool, error?: string}
    function invoke(id, params) {
        const a = _actions[id]
        if (!a) {
            console.warn("[ActionManager] invoke: unknown action '" + id + "'")
            return {success: false, error: "unknown_action"}
        }
        if (!a.enabled) {
            console.warn("[ActionManager] invoke: action '" + id + "' is disabled")
            return {success: false, error: "action_disabled"}
        }

        const h = a.handler
        const startTime = Date.now()

        try {
            switch (h.type) {
                case "qml":
                    if (typeof h.call === "function") {
                        h.call(params)
                    } else {
                        console.error("[ActionManager] invoke '" + id + "': handler.call is not a function")
                        return {success: false, error: "invalid_handler"}
                    }
                    break

                case "process":
                    if (Array.isArray(h.command) && h.command.length > 0) {
                        Quickshell.execDetached(h.command)
                    } else {
                        console.error("[ActionManager] invoke '" + id + "': invalid process command")
                        return {success: false, error: "invalid_command"}
                    }
                    break

                case "ipc":
                    console.warn("[ActionManager] invoke '" + id + "': IPC handler dispatch not yet supported directly")
                    return {success: false, error: "handler_unavailable"}

                case "shell":
                    if (typeof h.command === "string" && h.command.length > 0) {
                        Quickshell.execDetached(["bash", "-lc", h.command])
                    } else {
                        return {success: false, error: "invalid_command"}
                    }
                    break

                default:
                    console.error("[ActionManager] invoke '" + id + "': unknown handler type '" + h.type + "'")
                    return {success: false, error: "unknown_handler_type"}
            }

            const elapsed = Date.now() - startTime
            console.log("[ActionManager] invoked '" + id + "' (" + elapsed + "ms)")
            return {success: true}
        } catch (e) {
            const elapsed = Date.now() - startTime
            console.error("[ActionManager] invoke '" + id + "' failed (" + elapsed + "ms): " + e)
            return {success: false, error: String(e)}
        }
    }

    /// List of registered action objects (read-only).
    readonly property var actions: {
        const result = []
        for (var i = 0; i < _order.length; i++) {
            result.push(_actions[_order[i]])
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
            call: function() { Services.LockService.lock() }
        }, {description: "Lock the current session with the configured screen locker"})

        this.register("session.logout", "core", "Log out", {
            type: "process",
            command: [Quickshell.env("HOME") + "/.config/omd/bin/omd-logout"]
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
            command: Quickshell.env("HOME") + "/.config/omd/bin/omd-session save-auto >/dev/null 2>&1; " + Quickshell.env("HOME") + "/.config/omd/bin/omd-logout"
        }, {description: "Save session snapshot then log out"})

        this.register("session.reboot.save", "core", "Reboot after saving session", {
            type: "shell",
            command: Quickshell.env("HOME") + "/.config/omd/bin/omd-session save-auto >/dev/null 2>&1; reboot || loginctl reboot"
        }, {description: "Save session snapshot then reboot"})

        this.register("session.shutdown.save", "core", "Shut down after saving session", {
            type: "shell",
            command: Quickshell.env("HOME") + "/.config/omd/bin/omd-session save-auto >/dev/null 2>&1; systemctl poweroff || loginctl poweroff"
        }, {description: "Save session snapshot then power off"})

        // Shell actions
        this.register("shell.reload", "core", "Reload shell", {
            type: "process",
            command: ["bash", Quickshell.env("HOME") + "/.config/omd/scripts/reload-quickshell"]
        }, {description: "Reload the Quickshell UI"})

        // Settings
        this.register("settings.open", "core", "Open settings", {
            type: "process",
            command: [Quickshell.env("HOME") + "/.config/omd/bin/omd-settings", "open", "overview"]
        }, {description: "Open system settings", paramsSchema: {type: "object", properties: {section: {type: "string"}}}})

        // Overview
        this.register("overview.open", "core", "Toggle overview", {
            type: "process",
            command: ["qs", "-p", Quickshell.env("HOME") + "/.config/omd/apps/omd-overview", "ipc", "call", "overview", "toggle"]
        }, {description: "Open or close the overview/workspace view"})
    }
}
