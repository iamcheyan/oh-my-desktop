pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.runtime

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
    /// Reflects both the action-level enabled flag and module enable state.
    function query(id) {
        const a = _actions[id]
        if (!a) return null
        // Compute effective availability: action must be enabled AND
        // (core actions always available OR owning module must be enabled).
        const moduleOk = a.owner === "core" || ModuleLoader.isEnabled(a.owner)
        return {
            id: a.id,
            owner: a.owner,
            title: a.title,
            description: a.description,
            available: a.enabled && moduleOk,
            handlerType: a.handler.type,
            paramsSchema: a.paramsSchema,
            timeout: a.timeout
        }
    }
    /// Resolve a module's absolute directory path from ModuleLoader's registry.
    /// Returns empty string if module or registry unavailable.
    function _modulePath(moduleId) {
        return typeof ModuleLoader !== "undefined" ? ModuleLoader.modulePath(moduleId) : ""
    }

    /// Check if a module ID exists in the registry.
    function _moduleExists(moduleId) {
        if (typeof ModuleLoader === "undefined" || !ModuleLoader.modules) return false
        const mods = ModuleLoader.modules
        for (var i = 0; i < mods.length; i++) {
            if (mods[i].id === moduleId) return true
        }
        return false
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
                        if (!ps.start(h.instanceId)) {
                            // Process may be in failed state — user explicit invocation should force restart
                            ps.start(h.instanceId, {forceRestart: true})
                        }

                        // Timeout enforcement: if action has a timeout, kill the
                        // process after that many seconds if still running.
                        if (a.timeout && a.timeout > 0) {
                            var _timeoutId = a.id
                            var _timeoutTimer = Qt.createQmlObject("import QtQuick; Timer {}", manager)
                            _timeoutTimer.interval = a.timeout * 1000
                            _timeoutTimer.triggered.connect(function() {
                                var curState = ps.getState(h.instanceId)
                                if (curState === 1 || curState === 2) { // starting or ready
                                    console.warn("[ActionManager] timeout (" + a.timeout + "s) for '" + _timeoutId + "', stopping instance '" + h.instanceId + "'")
                                    ps.stop(h.instanceId)
                                }
                                _timeoutTimer.destroy()
                            })
                            _timeoutTimer.start()
                        }
                    }
                    break

                case "delegate":
                    // Delegate to another registered action by ID
                    if (h.targetId && typeof h.targetId === "string") {
                        return this.invoke(h.targetId, params)
                    }
                    console.error("[ActionManager] invoke '" + a.id + "': delegate handler missing targetId")
                    return {success: false, error: "missing_target"}

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
    /// The `enabled` field reflects both the action flag and module enable state.
    function getActionList() {
        const result = []
        for (var i = 0; i < _order.length; i++) {
            const a = _actions[_order[i]]
            const moduleOk = a.owner === "core" || ModuleLoader.isEnabled(a.owner)
            result.push({
                id: a.id,
                owner: a.owner,
                title: a.title,
                enabled: a.enabled && moduleOk,
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
            command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-restart", "omd-bar"]
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

        // ProcessSupervisor management
        this.register("process_supervisor.cancel", "core", "Cancel supervised process", {
            type: "qml",
            call: function(params) {
                var p = params || {}
                var id = p.instanceId || p.id || ""
                if (!id) return {success: false, error: "missing_instanceId"}
                if (typeof ProcessSupervisor === "undefined" || !ProcessSupervisor)
                    return {success: false, error: "no_supervisor"}
                ProcessSupervisor.stop(id)
                return {success: true}
            }
        }, {description: "Stop a running supervised process by instanceId"})

        this.register("process_supervisor.status", "core", "Process supervisor status", {
            type: "qml",
            call: function(params) {
                if (typeof ProcessSupervisor === "undefined" || !ProcessSupervisor)
                    return {success: false, error: "no_supervisor"}
                var p = params || {}
                var id = p.instanceId || ""
                if (id) {
                    return ProcessSupervisor.query(id) || {error: "not_found"}
                }
                return {processes: ProcessSupervisor.listProcesses()}
            }
        }, {description: "Query process supervisor state for an instance or list all"})

        // Bluetooth — only register if no dedicated bluetooth module exists
        // in the registry. Owner is "bluetooth" for backward compatibility;
        // if a module is added later, the registry module takes priority.
        if (!_moduleExists("bluetooth")) {
            this.register("bluetooth.launch", "bluetooth", "Open Bluetooth manager", {
                type: "process",
                command: [Quickshell.env("OMD_REPO_ROOT") + "/bin/omd-launch-bluetooth"]
            }, {description: "Open the Bluetooth pairing TUI"})
        }

        // === Audio (media control) actions - consumed by Hyprland bindings ===
        this.register("audio.volume-up", "core", "Volume up", {
            type: "process",
            command: ["omd-swayosd-client", "--output-volume", "raise"]
        }, {description: "Raise output volume"})
        this.register("audio.volume-down", "core", "Volume down", {
            type: "process",
            command: ["omd-swayosd-client", "--output-volume", "lower"]
        }, {description: "Lower output volume"})
        this.register("audio.volume-mute-toggle", "core", "Toggle mute", {
            type: "process",
            command: ["omd-swayosd-client", "--output-volume", "mute-toggle"]
        }, {description: "Toggle audio output mute"})
        this.register("audio.input-mute-toggle", "core", "Toggle input mute", {
            type: "process",
            command: ["omd-audio-input-mute"]
        }, {description: "Toggle microphone mute"})
        this.register("audio.volume-up-precise", "core", "Volume up 1%", {
            type: "process",
            command: ["omd-swayosd-client", "--output-volume", "+1"]
        }, {description: "Raise output volume by 1%"})
        this.register("audio.volume-down-precise", "core", "Volume down 1%", {
            type: "process",
            command: ["omd-swayosd-client", "--output-volume", "-1"]
        }, {description: "Lower output volume by 1%"})
        this.register("audio.output-switch", "core", "Switch audio output", {
            type: "process",
            command: ["omd-audio-output-switch"]
        }, {description: "Cycle audio output device"})

        // === Display brightness ===
        this.register("display.brightness-up", "core", "Brightness up", {
            type: "process",
            command: ["omd-brightness-display", "+5%"]
        }, {description: "Increase display brightness by 5%"})
        this.register("display.brightness-down", "core", "Brightness down", {
            type: "process",
            command: ["omd-brightness-display", "5%-"]
        }, {description: "Decrease display brightness by 5%"})
        this.register("display.brightness-max", "core", "Brightness maximum", {
            type: "process",
            command: ["omd-brightness-display", "100%"]
        }, {description: "Set display brightness to 100%"})
        this.register("display.brightness-min", "core", "Brightness minimum", {
            type: "process",
            command: ["omd-brightness-display", "1%"]
        }, {description: "Set display brightness to 1%"})
        this.register("display.brightness-up-precise", "core", "Brightness up 1%", {
            type: "process",
            command: ["omd-brightness-display", "+1%"]
        }, {description: "Increase display brightness by 1%"})
        this.register("display.brightness-down-precise", "core", "Brightness down 1%", {
            type: "process",
            command: ["omd-brightness-display", "1%-"]
        }, {description: "Decrease display brightness by 1%"})

        // === Keyboard backlight ===
        this.register("display.kbd-brightness-up", "core", "Keyboard brightness up", {
            type: "process",
            command: ["omd-brightness-keyboard", "up"]
        }, {description: "Increase keyboard backlight brightness"})
        this.register("display.kbd-brightness-down", "core", "Keyboard brightness down", {
            type: "process",
            command: ["omd-brightness-keyboard", "down"]
        }, {description: "Decrease keyboard backlight brightness"})
        this.register("display.kbd-brightness-cycle", "core", "Keyboard backlight cycle", {
            type: "process",
            command: ["omd-brightness-keyboard", "cycle"]
        }, {description: "Cycle keyboard backlight states"})

        // === Input (touchpad) ===
        this.register("input.touchpad-toggle", "core", "Toggle touchpad", {
            type: "process",
            command: ["omd-toggle-touchpad"]
        }, {description: "Toggle touchpad on/off"})
        this.register("input.touchpad-enable", "core", "Enable touchpad", {
            type: "process",
            command: ["omd-toggle-touchpad", "on"]
        }, {description: "Enable touchpad"})
        this.register("input.touchpad-disable", "core", "Disable touchpad", {
            type: "process",
            command: ["omd-toggle-touchpad", "off"]
        }, {description: "Disable touchpad"})

        // === Display (monitor/lid) ===
        this.register("display.internal-toggle", "core", "Toggle laptop display", {
            type: "process",
            command: ["omd-hyprland-monitor-internal", "toggle"]
        }, {description: "Toggle laptop internal display"})
        this.register("display.internal-mirror-toggle", "core", "Toggle display mirroring", {
            type: "process",
            command: ["omd-hyprland-monitor-internal-mirror", "toggle"]
        }, {description: "Toggle laptop display mirroring"})
        this.register("display.lid-close", "core", "Lid close", {
            type: "shell",
            command: "omd-hw-external-monitors && omd-hyprland-monitor-internal off"
        }, {description: "Handle lid-close: switch to external monitors"})
        this.register("display.lid-open", "core", "Lid open", {
            type: "process",
            command: ["omd-hyprland-monitor-internal", "on"]
        }, {description: "Handle lid-open: enable internal display"})
        this.register("display.color-picker", "core", "Color picker", {
            type: "shell",
            command: "pkill hyprpicker || hyprpicker -a"
        }, {description: "Toggle color picker tool"})
        this.register("display.scaling-cycle", "core", "Cycle monitor scaling", {
            type: "process",
            command: ["omd-hyprland-monitor-scaling-cycle"]
        }, {description: "Cycle through monitor scaling options"})
        this.register("display.scaling-cycle-reverse", "core", "Cycle scaling reverse", {
            type: "process",
            command: ["omd-hyprland-monitor-scaling-cycle", "--reverse"]
        }, {description: "Cycle monitor scaling in reverse order"})

        // === Window management ===
        this.register("window.transparency-toggle", "core", "Toggle transparency", {
            type: "process",
            command: ["omd-hyprland-window-transparency-toggle"]
        }, {description: "Toggle active window transparency"})
        this.register("window.gaps-toggle", "core", "Toggle gaps", {
            type: "process",
            command: ["omd-hyprland-window-gaps-toggle"]
        }, {description: "Toggle window gaps on/off"})
        this.register("window.single-square-aspect-toggle", "core", "Toggle square aspect", {
            type: "process",
            command: ["omd-hyprland-window-single-square-aspect-toggle"]
        }, {description: "Toggle single window square aspect ratio"})
        this.register("window.close-all", "core", "Close all windows", {
            type: "process",
            command: ["omd-hyprland-window-close-all"]
        }, {description: "Close all windows on current workspace"})
        this.register("window.pop-out", "core", "Pop window out", {
            type: "process",
            command: ["omd-hyprland-window-pop"]
        }, {description: "Pop focused window out (float & pin)"})

        // === Workspace ===
        this.register("workspace.layout-toggle", "core", "Toggle layout", {
            type: "process",
            command: ["omd-hyprland-workspace-layout-toggle"]
        }, {description: "Toggle workspace layout between master-stack and default"})
    }


    function _registerFromRegistry() {
        if (typeof ModuleLoader === "undefined") return
        const mods = ModuleLoader.modules
        if (!mods || mods.length === 0) return

        var actions = ModuleLoader.contributedActions
        // Build a map of moduleId -> entry for application modules
        var moduleEntries = ({})
        for (var mi = 0; mi < mods.length; mi++) {
            var m = mods[mi]
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
