pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Manages the lifecycle of external module processes.
///
/// Each supervised process is identified by a unique `instanceId`
/// (typically `<moduleId>` or `<moduleId>:<variant>`).
///
/// States:
///   stopped   — not running, not scheduled to start
///   starting  — launched, waiting for readiness
///   ready     — process is running and healthy
///   failed    — startup timeout or crash-loop exhausted
///   stopping  — graceful shutdown in progress
///
/// Process records are exposed via listProcesses() for diagnostics.
Singleton {
    id: supervisor

    // ── State constants ──
    readonly property int Stopped: 0
    readonly property int Starting: 1
    readonly property int Ready: 2
    readonly property int Failed: 3
    readonly property int Stopping: 4

    readonly property var _stateNames: ({"0":"stopped","1":"starting","2":"ready","3":"failed","4":"stopping"})

    // ── Internal registry ──
    // Key: instanceId (string)
    // Value: {
    //   instanceId, moduleId, state, command (array),
    //   pid: number, startTime: number, exitCode: number,
    //   restartCount: number, restartLimit: number,
    //   lastError: string, logDir: string,
    //   readyTimeout: number, readyTimer: Timer|null,
    //   backoffTimer: Timer|null, backoffAttempts: number,
    //   process: Process|null,
    //   createdAt: number
    // }
    property var _records: ({})

    // ── Logging ──
    readonly property string _logDir: {
        const stateHome = Quickshell.env("SUMIKA_SHELL_STATE_HOME")
            || Quickshell.env("XDG_STATE_HOME")
            || (Quickshell.env("HOME") + "/.local/state")
        return stateHome + "/sumika-shell/logs"
    }

    // ── Public API ──

    /// Register an application plugin for supervision.
    /// Does NOT start it — call start(instanceId).
    /// @param {string} moduleId - Module identifier (e.g. "clipboard")
    /// @param {string} instanceId - Unique instance identifier (defaults to moduleId)
    /// @param {string[]} command - argv array (NO shell string)
    /// @param {object} options - Optional: {readyTimeout, restartLimit, logTag, cwd, env}
    /// @returns {string} instanceId
    function register(moduleId, instanceId, command, options) {
        const id = instanceId || moduleId
        if (!id || typeof id !== "string" || id.length === 0) {
            console.error("[ProcessSupervisor] register: invalid instanceId")
            return ""
        }
        if (_records[id] !== undefined) {
            console.warn("[ProcessSupervisor] register: '" + id + "' already registered")
            return id
        }
        if (!Array.isArray(command) || command.length === 0) {
            console.error("[ProcessSupervisor] register: '" + id + "' command must be a non-empty array")
            return ""
        }

        const opts = options || {}
        const record = {
            instanceId: id,
            moduleId: moduleId || id,
            state: Stopped,
            command: command,
            commandDisplay: command.join(" "),
            cwd: opts.cwd || "",
            env: opts.env || null,
            pid: -1,
            startTime: 0,
            exitCode: null,
            restartCount: 0,
            restartLimit: opts.restartLimit || 5,
            lastError: "",
            readyTimeout: opts.readyTimeout || 15,
            readyTimer: null,
            backoffTimer: null,
            backoffAttempts: 0,
            logTag: opts.logTag || id,
            process: null,
            createdAt: Date.now(),
            logFile: null  // lazy: set on first start
        }

        _records[id] = record
        console.log("[ProcessSupervisor] registered '" + id + "': " + record.commandDisplay)
        return id
    }

    /// Unregister a supervised process. Stops it first if running.
    function unregister(instanceId) {
        const rec = _records[instanceId]
        if (!rec) return false
        if (rec.state !== Stopped && rec.state !== Failed) {
            stop(instanceId)
        }
        delete _records[instanceId]
        console.log("[ProcessSupervisor] unregistered '" + instanceId + "'")
        return true
    }

    /// Start the process. If already running, return existing — singleton semantics.
    /// If in failed state, reset state and retry.
    /// @param {string} instanceId
    /// @param {object} options - Optional: {forceRestart: bool}
    /// @returns {bool} true if start was initiated
    function start(instanceId, options) {
        const rec = _records[instanceId]
        if (!rec) {
            console.error("[ProcessSupervisor] start: unknown instance '" + instanceId + "'")
            return false
        }

        // Singleton: already running
        if (rec.state === Ready || rec.state === Starting) {
            console.log("[ProcessSupervisor] start: '" + instanceId + "' already " + _stateNames[rec.state])
            return true
        }

        // If failed and force restart, reset
        if (rec.state === Failed) {
            if (options && options.forceRestart) {
                rec.restartCount = 0
                rec.backoffAttempts = 0
                rec.lastError = ""
            } else {
                console.warn("[ProcessSupervisor] start: '" + instanceId + "' is in failed state, use forceRestart to retry")
                return false
            }
        }

        // Check restart limit
        if (rec.restartCount >= rec.restartLimit) {
            console.error("[ProcessSupervisor] start: '" + instanceId + "' restart limit (" + rec.restartLimit + ") reached")
            rec.state = Failed
            rec.lastError = "restart_limit_reached"
            _notifyStateChange(rec)
            return false
        }

        _launch(rec)
        return true
    }

    /// Stop the process gracefully, with optional timeout before SIGKILL.
    function stop(instanceId, timeoutMs) {
        const rec = _records[instanceId]
        if (!rec) return false
        if (rec.state === Stopped || rec.state === Stopping) return true
        if (rec.state === Failed) {
            rec.state = Stopped
            _notifyStateChange(rec)
            return true
        }

        rec.state = Stopping
        _notifyStateChange(rec)
        _cancelTimers(rec)

        if (rec.process) {
            // For Quickshell-hosted processes, terminate via IPC
            // For external, rely on process termination
            rec.process.running = false
            if (timeoutMs && timeoutMs > 0) {
                const killTimer = Qt.createQmlObject("import QtQuick; Timer {}", supervisor)
                killTimer.interval = timeoutMs
                killTimer.onTriggered = function() {
                    rec.lastError = "stop_timeout"
                    rec.state = Stopped
                    _notifyStateChange(rec)
                    killTimer.destroy()
                }
                killTimer.start()
            }
        }

        rec.state = Stopped
        _notifyStateChange(rec)
        return true
    }

    /// Get the current state of a process.
    function getState(instanceId) {
        const rec = _records[instanceId]
        if (!rec) return Stopped
        return rec.state
    }

    /// Get the current state name as a string.
    function getStateName(instanceId) {
        return _stateNames[getState(instanceId)] || "unknown"
    }

    /// Query a process record (read-only copy).
    function query(instanceId) {
        const rec = _records[instanceId]
        if (!rec) return null
        return {
            instanceId: rec.instanceId,
            moduleId: rec.moduleId,
            state: rec.state,
            stateName: _stateNames[rec.state],
            command: rec.commandDisplay,
            cwd: rec.cwd,
            pid: rec.pid,
            startTime: rec.startTime,
            exitCode: rec.exitCode,
            restartCount: rec.restartCount,
            restartLimit: rec.restartLimit,
            lastError: rec.lastError,
            uptime: rec.startTime > 0 ? Date.now() - rec.startTime : 0,
            logDir: rec.logDir
        }
    }

    /// List all supervised process records.
    function listProcesses() {
        const result = []
        const keys = Object.keys(_records)
        for (var i = 0; i < keys.length; i++) {
            result.push(query(keys[i]))
        }
        return result
    }

    /// Health check: returns arrays of {instanceId, state, stateName, ...}
    function healthCheck() {
        const healthy = []
        const unhealthy = []
        const keys = Object.keys(_records)
        for (var i = 0; i < keys.length; i++) {
            const rec = _records[keys[i]]
            const info = query(keys[i])
            if (rec.state === Ready || rec.state === Starting) {
                healthy.push(info)
            } else {
                unhealthy.push(info)
            }
        }
        return {healthy: healthy, unhealthy: unhealthy}
    }

    // ── Internal ──

    function _launch(rec) {
        // Ensure log dir exists
        _ensureLogDir()

        rec.state = Starting
        rec.startTime = Date.now()
        rec.pid = -1
        rec.exitCode = null
        rec.restartCount++
        rec.lastError = ""
        rec.logDir = _logDir + "/" + rec.instanceId

        console.log("[ProcessSupervisor] starting '" + rec.instanceId + "': " + rec.commandDisplay)

        // Create a Process QML object dynamically
        const stdoutPath = rec.logDir + ".out"
        const stderrPath = rec.logDir + ".err"

        // Build Process QML text
        var qmlText = 'import Quickshell.Io; Process {\n'
        qmlText += '    command: ' + JSON.stringify(rec.command) + '\n'
        if (rec.cwd) {
            qmlText += '    , workingDirectory: ' + JSON.stringify(rec.cwd) + '\n'
        }
        qmlText += '    , running: true\n'
        qmlText += '    , stdout: StdioCollector {\n'
        qmlText += '        onStreamFinished: {\n'
        qmlText += '            File.append(' + JSON.stringify(stdoutPath) + ', this.text)\n'
        qmlText += '        }\n'
        qmlText += '    }\n'
        qmlText += '    , stderr: StdioCollector {\n'
        qmlText += '        onStreamFinished: {\n'
        qmlText += '            File.append(' + JSON.stringify(stderrPath) + ', this.text)\n'
        qmlText += '        }\n'
        qmlText += '    }\n'
        qmlText += '    , onExited: function(exitCode, exitStatus) {\n'
        qmlText += '        supervisor._onExited(' + JSON.stringify(rec.instanceId) + ', exitCode, exitStatus)\n'
        qmlText += '    }\n'
        qmlText += '}'

        // Clean up any previous Process object
        if (rec.process) {
            try { rec.process.destroy() } catch (e) { /* ignore */ }
        }

        try {
            const proc = Qt.createQmlObject(qmlText, supervisor, "proc_" + rec.instanceId)
            rec.process = proc

            // We can't get PID directly from Process, but we track start state

            // Set up ready timeout
            if (rec.readyTimeout > 0) {
                const readyTimer = Qt.createQmlObject("import QtQuick; Timer {}", supervisor)
                readyTimer.interval = rec.readyTimeout * 1000
                readyTimer.onTriggered = function() {
                    if (rec.state === Starting) {
                        console.warn("[ProcessSupervisor] ready timeout for '" + rec.instanceId + "' (" + rec.readyTimeout + "s)")
                        rec.lastError = "ready_timeout"
                        rec.state = Failed
                        _notifyStateChange(rec)
                        _scheduleRestart(rec)
                    }
                    readyTimer.destroy()
                }
                rec.readyTimer = readyTimer
                rec.readyTimer.start()
            }

            _notifyStateChange(rec)
        } catch (e) {
            console.error("[ProcessSupervisor] failed to launch '" + rec.instanceId + "': " + e)
            rec.state = Failed
            rec.lastError = String(e)
            _notifyStateChange(rec)
            _scheduleRestart(rec)
        }
    }

    function _onExited(instanceId, exitCode, exitStatus) {
        const rec = _records[instanceId]
        if (!rec) return

        const wasReady = rec.state === Ready
        rec.pid = -1
        rec.exitCode = exitCode
        rec.process = null  // Process object destroyed automatically on exit

        console.log("[ProcessSupervisor] '" + instanceId + "' exited with code " + exitCode + " (was " + _stateNames[rec.state] + ")")

        if (rec.state === Stopping) {
            rec.state = Stopped
            _notifyStateChange(rec)
            return
        }

        if (rec.state === Starting || rec.state === Ready) {
            if (exitCode !== 0 && exitCode !== null) {
                rec.lastError = "exit_code_" + exitCode
            }
            rec.state = Failed
            _notifyStateChange(rec)
            _scheduleRestart(rec)
        }
    }

    function _scheduleRestart(rec) {
        if (rec.restartCount >= rec.restartLimit) {
            console.error("[ProcessSupervisor] '" + rec.instanceId + "' restart limit (" + rec.restartLimit + ") reached after " + rec.restartCount + " attempts")
            rec.state = Failed
            rec.lastError = "restart_limit_reached"
            _notifyStateChange(rec)
            return
        }

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s...
        const backoffMs = Math.min(1000 * Math.pow(2, rec.backoffAttempts), 30000)
        rec.backoffAttempts++
        console.log("[ProcessSupervisor] scheduling restart for '" + rec.instanceId + "' in " + backoffMs + "ms (attempt " + rec.backoffAttempts + ")")

        if (rec.backoffTimer) {
            try { rec.backoffTimer.stop(); rec.backoffTimer.destroy() } catch (e) { /* ignore */ }
        }

        const timer = Qt.createQmlObject("import QtQuick; Timer {}", supervisor)
        timer.interval = backoffMs
        timer.onTriggered = function() {
            if (rec.state === Failed) {
                _launch(rec)
            }
            timer.destroy()
        }
        rec.backoffTimer = timer
        rec.backoffTimer.start()
    }

    function _cancelTimers(rec) {
        if (rec.readyTimer) {
            try { rec.readyTimer.stop(); rec.readyTimer.destroy() } catch (e) { /* ignore */ }
            rec.readyTimer = null
        }
        if (rec.backoffTimer) {
            try { rec.backoffTimer.stop(); rec.backoffTimer.destroy() } catch (e) { /* ignore */ }
            rec.backoffTimer = null
        }
    }

    function _notifyStateChange(rec) {
        // TODO: emit signal when we add signal support
        // For now, just log state transitions
        console.log("[ProcessSupervisor] '" + rec.instanceId + "' -> " + _stateNames[rec.state]
            + (rec.lastError ? " (" + rec.lastError + ")" : ""))
    }

    function _ensureLogDir() {
        // File operations in QML are limited — the StdioCollector writes happen
        // via File.append() on stream finish. The dir is created lazily.
        // For now, we log to files that are created by File.append().
    }

    /// Mark a process as ready (called by the module's startup signal or health check).
    function reportReady(instanceId) {
        const rec = _records[instanceId]
        if (!rec) return false
        if (rec.state !== Starting) {
            console.warn("[ProcessSupervisor] reportReady: '" + instanceId + "' is not in starting state (state=" + _stateNames[rec.state] + ")")
            return false
        }

        rec.state = Ready
        if (rec.readyTimer) {
            try { rec.readyTimer.stop(); rec.readyTimer.destroy() } catch (e) { /* ignore */ }
            rec.readyTimer = null
        }

        console.log("[ProcessSupervisor] '" + instanceId + "' is ready (startup: " + (Date.now() - rec.startTime) + "ms)")
        _notifyStateChange(rec)
        return true
    }

    /// Report a process failure (called by health check when process is unresponsive).
    function reportFailure(instanceId, error) {
        const rec = _records[instanceId]
        if (!rec) return false

        rec.state = Failed
        rec.lastError = error || "health_check_failed"
        _cancelTimers(rec)

        console.warn("[ProcessSupervisor] '" + instanceId + "' reported failure: " + rec.lastError)
        _notifyStateChange(rec)
        _scheduleRestart(rec)
        return true
    }
}
