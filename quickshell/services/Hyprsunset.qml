pragma Singleton

import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Simple hyprsunset service with automatic mode.
 * In theory we don't need this because hyprsunset has a config file, but it somehow doesn't work.
 * It should also be possible to control it via hyprctl, but it doesn't work consistently either so we're just killing and launching.
 */
Singleton {
    id: root
    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25

    property string from: Config.options?.light?.night?.from ?? "19:00" 
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic: Config.options?.light?.night?.automatic && (Config?.ready ?? true)
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property int defaultColorTemperature: 6000
    property int gamma: 100
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool temperatureActive: false

    // Hyprland sessions control the resident hyprsunset process over IPC
    // (hyprctl hyprsunset …). wlroots compositors (labwc, sway) have no such
    // IPC; hyprsunset's CLI is driven directly instead (restart the process
    // with --temperature/--gamma, kill it to restore defaults). Note this
    // best-effort path only works if the DRM driver exposes a gamma LUT —
    // e.g. the Asahi (apple-drm) driver does not, so night mode stays a
    // Hyprland-only feature there.
    readonly property bool hyprlandSession: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    property int fromHour: Number(from.split(":")[0])
    property int fromMinute: Number(from.split(":")[1])
    property int toHour: Number(to.split(":")[0])
    property int toMinute: Number(to.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()
    function ensureState() {
        // console.log("[Hyprsunset] Ensuring state:", root.shouldBeOn, "Automatic mode:", root.automatic);
        if (!root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    function startHyprsunset() {
        Quickshell.execDetached(["bash", "-c", `pidof hyprsunset || hyprsunset`]);
    }

    // Hyprland path: control the resident process over IPC.
    function applyHyprctl(args) {
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset ${args}`]);
    }

    // wlroots path: no IPC, restart hyprsunset with the full desired state
    // (temperature + gamma) as CLI args. Killing first also makes "off"
    // deterministic: a dead process restores the compositor's default gamma.
    function applyHyprsunsetCli() {
        const temp = root.temperatureActive ? root.colorTemperature : root.defaultColorTemperature;
        Quickshell.execDetached(["bash", "-c",
            `pkill -x hyprsunset 2>/dev/null; hyprsunset --temperature ${temp} --gamma ${root.gamma} >/dev/null 2>&1 &`]);
    }

    function applyArgs(args) {
        if (root.hyprlandSession)
            root.applyHyprctl(args);
        else
            root.applyHyprsunsetCli();
    }

    function load() {
        root.startHyprsunset();
        root.ensureState();
    }

    Timer {
        id: updateHyprsunset
        interval: 100
        repeat: false
        onTriggered: {
            root.ensureState();
            root.setGamma(root.gamma);
        }
    }

    function enableTemperature() {
        root.temperatureActive = true;

        // console.log("[Hyprsunset] Enabling");
        root.startHyprsunset();
        root.applyArgs(`temperature ${root.colorTemperature}`);
    }

    function disableTemperature() {
        root.temperatureActive = false;
        // console.log("[Hyprsunset] Disabling");
        if (!root.hyprlandSession) {
            // wlroots: no IPC — killing the process restores default gamma.
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset 2>/dev/null"]);
            return;
        }
        root.applyArgs(`temperature ${root.defaultColorTemperature}`);
    }

    // Debounce gamma application so dragging a slider doesn't spawn a
    // pidof + hyprsunset + hyprctl process on every drag step.
    Timer {
        id: gammaApplyTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.applyArgs(`gamma ${root.gamma}`);
        }
    }

    function setGamma(gamma) {
        root.gamma = Math.max(root.gammaLowerLimit, Math.min(100, gamma));

        root.gammaChangeAttempt();

        // hyprsunset is ensured running by enableTemperature; don't re-check
        // pidof on every gamma change.
        gammaApplyTimer.restart();
    }

    function fetchState() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        running: root.hyprlandSession
        command: ["bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const output = stateCollector.text.trim();
                if (output.length == 0 || output.startsWith("Couldn't"))
                    root.temperatureActive = false;
                else
                    root.temperatureActive = (output != root.defaultColorTemperature); // 6000 is the default when off
                // console.log("[Hyprsunset] Fetched state:", output, "->", root.temperatureActive);
            }
        }
    }

    function toggleTemperature(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.temperatureActive;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    // Change temp
    Timer {
        id: tempApplyTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!root.temperatureActive) return;
            root.applyArgs(`temperature ${Config.options.light.night.colorTemperature}`);
        }
    }
    Connections {
        target: Config.options.light.night
        function onColorTemperatureChanged() {
            tempApplyTimer.restart();
        }
    }
}