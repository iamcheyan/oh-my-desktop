pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root
    signal brightnessChanged()

    // Last monitor that received a brightness change (for OSD pinning).
    property string lastAdjustedScreenName: ""

    Component.onCompleted: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
        screen
    }))

    function getMonitorForScreen(screen: ShellScreen): var {
        if (!screen) return null;
        return monitors.find(m => m.screen.name === screen.name);
    }

    function getFocusedScreen(): var {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function isInternalScreen(screen: ShellScreen): bool {
        if (!screen) return false;
        const n = screen.name;
        return n.startsWith("eDP") || n.startsWith("LVDS") || n.startsWith("DSI") || n.startsWith("DPI");
    }

    /**
     * Adjust brightness for one screen only.
     * - Internal panel: brightnessctl (per-device when possible)
     * - External + DDC: ddcutil on that bus
     * - External without DDC: no-op (do NOT fall back to global hyprsunset gamma —
     *   that would dim every monitor)
     */
    function adjustBrightnessForScreen(screen: ShellScreen, increase: bool): void {
        const monitor = getMonitorForScreen(screen);
        if (!monitor || !screen) return;

        root.lastAdjustedScreenName = screen.name;

        const isInternal = isInternalScreen(screen);
        const hasHardwareControl = isInternal || monitor.isDdc;

        if (!hasHardwareControl) {
            // Cannot control this output's backlight. Leave other monitors alone.
            root.brightnessChanged();
            return;
        }

        // Only touch THIS monitor's brightness — never global gamma here.
        if (increase) {
            monitor.setBrightness(Math.min(1, monitor.brightness + 0.05));
        } else {
            monitor.setBrightness(Math.max(0, monitor.brightness - 0.05));
        }
    }

    function increaseBrightness(): void {
        adjustBrightnessForScreen(getFocusedScreen(), true);
    }

    function decreaseBrightness(): void {
        adjustBrightnessForScreen(getFocusedScreen(), false);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    function initializeMonitor(i: int): void {
        if (i >= monitors.length)
            return;
        monitors[i].initialize();
    }

    function ddcDetectFinished(): void {
        initializeMonitor(0);
    }

    Process {
        id: ddcProc

        command: [FileUtils.trimFileProtocol(`${Directories.home}/.config/omd/bin/omd-ddc-detect`)]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root.ddcMonitors.push({
                        name: lines.find(l => l.startsWith("DRM connector:")).split("-").slice(1).join('-'),
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onExited: root.ddcDetectFinished()
    }

    Process {
        id: setProc
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        property bool isDdc
        property string busNum
        property int rawMaxBrightness: 100
        property real brightness
        property real brightnessMultiplier: 1.0
        property real multipliedBrightness: Math.max(0, Math.min(1, brightness * (Config.options.light.antiFlashbang.enable ? brightnessMultiplier : 1)))
        property bool ready: false
        property bool animateChanges: !monitor.isDdc

        onBrightnessChanged: {
            if (!monitor.ready) return;
            root.lastAdjustedScreenName = monitor.screen?.name ?? root.lastAdjustedScreenName;
            root.brightnessChanged();
        }

        Behavior on multipliedBrightness {
            enabled: false
        }
        onMultipliedBrightnessChanged: {
            if (monitor.animateChanges) syncBrightness();
            else setTimer.restart();
        }

        function initialize() {
            monitor.ready = false;
            const match = root.ddcMonitors.find(m => m.name === screen.name && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            isDdc = !!match;
            busNum = match?.busNum ?? "";
            // Only internal panels share brightnessctl; externals without DDC stay inert.
            if (isDdc) {
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            } else if (root.isInternalScreen(screen)) {
                initProc.command = ["sh", "-c", `echo "a b c $(brightnessctl g) $(brightnessctl m)"`];
            } else {
                // External, no DDC: mark ready with a neutral value; setBrightness is a no-op.
                monitor.rawMaxBrightness = 100;
                monitor.brightness = 1;
                monitor.ready = true;
                initializeMonitor(root.monitors.indexOf(monitor) + 1);
                return;
            }
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const [, , , current, max] = data.split(" ");
                    monitor.rawMaxBrightness = parseInt(max);
                    monitor.brightness = parseInt(current) / monitor.rawMaxBrightness;
                    monitor.ready = true;
                }
            }
            onExited: (exitCode, exitStatus) => {
                initializeMonitor(root.monitors.indexOf(monitor) + 1);
            }
        }

        // We need a delay for DDC monitors because they can be quite slow and might act weird with rapid changes
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 0
            onTriggered: {
                syncBrightness();
            }
        }

        function syncBrightness() {
            const brightnessValue = Math.max(monitor.multipliedBrightness, 0);
            if (isDdc) {
                const rawValueRounded = Math.max(Math.floor(brightnessValue * monitor.rawMaxBrightness), 1);
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", String(rawValueRounded)]);
            } else if (root.isInternalScreen(screen)) {
                // Only the internal panel uses the laptop backlight class.
                const valuePercentNumber = Math.floor(brightnessValue * 100);
                let valuePercent = `${valuePercentNumber}%`;
                if (valuePercentNumber == 0) valuePercent = "1"; // Prevent fully black
                Quickshell.execDetached(["brightnessctl", "--class", "backlight", "s", valuePercent, "--quiet"]);
            }
            // External without DDC: ignore (never call brightnessctl — that would
            // dim the laptop panel while the user is focused on another screen).
        }

        function setBrightness(value: real): void {
            // Skip hardware path for external non-DDC monitors.
            if (!isDdc && !root.isInternalScreen(screen))
                return;
            value = Math.max(0, Math.min(1, value));
            root.lastAdjustedScreenName = screen?.name ?? "";
            monitor.brightness = value;
        }

        function setBrightnessMultiplier(value: real): void {
            monitor.brightnessMultiplier = value;
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    // Anti-flashbang
    property int workspaceAnimationDelay: 500
    property int contentSwitchDelay: 30
    property string screenshotDir: "/tmp/quickshell/brightness/antiflashbang"
    function brightnessMultiplierForLightness(x: real): real {
        // I hand picked some values and fitted an exponential curve for this
        // 6.600135 + 216.360356 * e^(-0.0811129189x)
        // Division by 100 is to normalize to [0, 1]
        return (6.600135 + 216.360356 * Math.pow(Math.E, -0.0811129189 * x)) / 100.0;
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            property string screenName: modelData.name
            property string screenshotPath: `${root.screenshotDir}/screenshot-${screenName}.png`
            Connections {
                enabled: Config.options.light.antiFlashbang.enable && Appearance.m3colors.darkmode
                target: Hyprland
                function onRawEvent(event) {
                    if (["activewindowv2", "windowtitlev2"].includes(event.name)) {
                        screenshotTimer.interval = root.contentSwitchDelay;
                        screenshotTimer.restart();
                    } else if (["workspacev2"].includes(event.name)) {
                        screenshotTimer.interval = root.workspaceAnimationDelay;
                        screenshotTimer.restart();
                    }
                }
            }

            Timer {
                id: screenshotTimer
                interval: 700 // This is what I have for a Hyprland ws anim
                onTriggered: {
                    screenshotProc.running = false;
                    screenshotProc.running = true;
                }
            }

            Process {
                id: screenshotProc
                command: ["bash", "-c",
                    `mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}'`
                    + ` && grim -o '${StringUtils.shellSingleQuoteEscape(screenScope.screenName)}' -`
                    + ` | magick png:- -colorspace Gray -format "%[fx:mean*100]" info:`
                ]
                stdout: StdioCollector {
                    id: lightnessCollector
                    onStreamFinished: {
                        Quickshell.execDetached(["rm", screenScope.screenshotPath]); // Cleanup
                        const lightness = lightnessCollector.text
                        const newMultiplier = root.brightnessMultiplierForLightness(parseFloat(lightness))
                        Brightness.getMonitorForScreen(screenScope.modelData).setBrightnessMultiplier(newMultiplier)
                    }
                }
            }
        }
    }

    // External trigger points

    IpcHandler {
        target: "brightness"

        function increment() {
            root.increaseBrightness();
        }

        function decrement() {
            root.decreaseBrightness();
        }
    }

    GlobalShortcut {
        name: "brightnessIncrease"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    GlobalShortcut {
        name: "brightnessDecrease"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }
}
