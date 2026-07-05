pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string state: "init"
    property bool keydReady: false
    property string lastError: ""
    property var devices: []
    property var deviceProfiles: ({})
    property string selectedDeviceId: ""
    property bool applyInProgress: false
    property string capturedFromKey: ""
    property string capturedFromLabel: ""
    property string capturedFromCode: ""
    property bool captureWindowOpen: false
    property bool captureReading: false
    property var pendingCapture: null

    readonly property string shareDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/share/bin`)
    readonly property string scriptsDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/scripts`)
    readonly property string dataDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/keyboard-remap`)
    readonly property string profilesPath: `${root.dataDir}/profiles.json`

    readonly property var keyChoices: [
        "capslock", "esc", "escape", "grave", "tab", "space", "backspace", "enter", "delete", "insert",
        "home", "end", "pageup", "pagedown",
        "muhenkan", "henkan", "katakana", "katakanahiragana", "zenkakuhankaku",
        "leftshift", "rightshift", "leftcontrol", "rightcontrol", "leftalt", "rightalt", "leftmeta", "rightmeta",
        "left", "right", "up", "down",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12"
    ]

    readonly property var presets: ({
        "caps-esc": {
            "label": "Caps → Esc",
            "remaps": [{ "from": "capslock", "to": "escape" }]
        },
        "ctrl-caps-swap": {
            "label": "Ctrl ↔ Caps",
            "remaps": [
                { "from": "leftcontrol", "to": "capslock" },
                { "from": "capslock", "to": "leftcontrol" }
            ]
        },
        "mac-meta": {
            "label": "Ctrl/Alt → Meta",
            "remaps": [
                { "from": "leftcontrol", "to": "leftmeta" },
                { "from": "leftalt", "to": "leftmeta" }
            ]
        }
    })

    readonly property var selectedProfile: selectedDeviceId !== "" ? (deviceProfiles[selectedDeviceId] ?? null) : null
    readonly property var selectedRemaps: selectedProfile?.remaps ?? []
    readonly property bool selectedEnabled: selectedProfile?.enabled !== false
    readonly property var selectedDevice: {
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].hyprName === selectedDeviceId)
                return devices[i];
        }
        return null;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.dataDir]);
        root.checkKeyd();
        root.loadProfiles();
        root.refreshDevices();
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refreshDevices()
    }

    function checkKeyd() {
        keydCheckProc.running = true;
    }

    function refreshDevices() {
        listProc.running = true;
    }

    function loadProfiles() {
        loadProc.running = true;
    }

    function saveProfiles() {
        saveProc.running = true;
    }

    function setup() {
        if (root.state === "applying")
            return;
        root.lastError = "";
        setupProc.running = true;
    }

    function apply() {
        if (root.applyInProgress)
            return;
        root.applyInProgress = true;
        root.lastError = "";
        root.state = "applying";
        saveProc.runApplyAfter = true;
        saveProc.running = true;
    }

    function selectDevice(hyprName) {
        root.selectedDeviceId = hyprName;
        root.ensureProfile(hyprName);
    }

    function ensureProfile(hyprName) {
        if (!hyprName || root.deviceProfiles[hyprName])
            return;
        let displayName = hyprName;
        let keydId = "";
        for (let i = 0; i < root.devices.length; ++i) {
            if (root.devices[i].hyprName === hyprName) {
                displayName = root.devices[i].displayName || hyprName;
                keydId = root.devices[i].keydId || "";
                break;
            }
        }
        const next = Object.assign({}, root.deviceProfiles);
        next[hyprName] = {
            displayName: displayName,
            hyprName: hyprName,
            keydId: keydId,
            enabled: true,
            remaps: []
        };
        root.deviceProfiles = next;
        root.saveProfiles();
    }

    function setProfileEnabled(enabled) {
        if (root.selectedDeviceId === "")
            return;
        const profile = root.deviceProfiles[root.selectedDeviceId];
        if (!profile)
            return;
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { enabled: enabled });
        root.deviceProfiles = next;
        root.saveProfiles();
    }

    function setDisplayName(name) {
        if (root.selectedDeviceId === "")
            return;
        const profile = root.deviceProfiles[root.selectedDeviceId];
        if (!profile)
            return;
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { displayName: name });
        root.deviceProfiles = next;
        root.saveProfiles();
    }

    function startCapture() {
        root.pendingCapture = null;
        root.capturedFromKey = "";
        root.capturedFromLabel = "";
        root.capturedFromCode = "";
        root.lastError = "";
        root.captureWindowOpen = true;
        Quickshell.execDetached([`${root.scriptsDir}/key-test`, "--remap"]);
    }

    function confirmCapture() {
        if (root.captureReading)
            return;
        root.lastError = "";
        root.captureReading = true;
        readCaptureProc.running = true;
    }

    function acceptPendingCapture() {
        if (!root.pendingCapture || !root.pendingCapture.keyd)
            return;
        root.capturedFromKey = root.pendingCapture.keyd;
        root.capturedFromLabel = root.pendingCapture.raw || root.pendingCapture.keyd;
        root.capturedFromCode = root.pendingCapture.keycode !== undefined && root.pendingCapture.keycode !== null
            ? String(root.pendingCapture.keycode)
            : "";
        root.pendingCapture = null;
        root.captureWindowOpen = false;
        root.lastError = "";
    }

    function rejectPendingCapture() {
        root.pendingCapture = null;
        root.captureWindowOpen = false;
    }

    function clearCapturedKey() {
        root.capturedFromKey = "";
        root.capturedFromLabel = "";
        root.capturedFromCode = "";
        root.pendingCapture = null;
        root.captureWindowOpen = false;
    }

    function saveRemap(toKey) {
        if (root.selectedDeviceId === "" || !root.capturedFromKey || !toKey)
            return;
        root.addRemap(root.capturedFromKey, toKey);
        root.clearCapturedKey();
        root.apply();
    }

    function addRemap(fromKey, toKey) {
        if (root.selectedDeviceId === "" || !fromKey || !toKey)
            return;
        root.ensureProfile(root.selectedDeviceId);
        const profile = root.deviceProfiles[root.selectedDeviceId];
        const remaps = (profile.remaps ?? []).slice();
        const idx = remaps.findIndex(r => r.from === fromKey);
        if (idx >= 0)
            remaps[idx] = { from: fromKey, to: toKey };
        else
            remaps.push({ from: fromKey, to: toKey });
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { remaps: remaps });
        root.deviceProfiles = next;
        root.saveProfiles();
    }

    function removeRemap(fromKey) {
        if (root.selectedDeviceId === "")
            return;
        const profile = root.deviceProfiles[root.selectedDeviceId];
        if (!profile)
            return;
        const remaps = (profile.remaps ?? []).filter(r => r.from !== fromKey);
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { remaps: remaps });
        root.deviceProfiles = next;
        root.saveProfiles();
    }

    function applyPreset(presetId) {
        const preset = root.presets[presetId];
        if (!preset || root.selectedDeviceId === "")
            return;
        root.ensureProfile(root.selectedDeviceId);
        const profile = root.deviceProfiles[root.selectedDeviceId];
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { remaps: preset.remaps.slice() });
        root.deviceProfiles = next;
        root.saveProfiles();
    }

    function mergeDevices(detected) {
        let selected = root.selectedDeviceId;
        let mainId = "";
        for (let i = 0; i < detected.length; ++i) {
            if (detected[i].main)
                mainId = detected[i].hyprName;
            root.ensureProfileSilent(detected[i]);
        }
        if (!selected && mainId)
            selected = mainId;
        else if (selected && !detected.some(d => d.hyprName === selected) && mainId)
            selected = mainId;
        root.selectedDeviceId = selected;
    }

    function ensureProfileSilent(device) {
        const hyprName = device.hyprName;
        if (!hyprName)
            return;
        if (root.deviceProfiles[hyprName]) {
            const existing = root.deviceProfiles[hyprName];
            if (!existing.keydId && device.keydId) {
                const next = Object.assign({}, root.deviceProfiles);
                next[hyprName] = Object.assign({}, existing, { keydId: device.keydId });
                root.deviceProfiles = next;
            }
            return;
        }
        const next = Object.assign({}, root.deviceProfiles);
        next[hyprName] = {
            displayName: device.displayName || hyprName,
            hyprName: hyprName,
            keydId: device.keydId || "",
            enabled: true,
            remaps: []
        };
        root.deviceProfiles = next;
    }

    function openSettings() {
        GlobalStates.barPopupType = "";
        GlobalStates.barDialogType = "keyremap";
        GlobalStates.barDialogOpen = true;
    }

    function openPanel() {
        root.openSettings();
    }

    Process {
        id: readCaptureProc
        command: ["bash", `${root.scriptsDir}/keyremap-capture-read`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.captureReading = false;
                root.captureWindowOpen = false;
                try {
                    const data = JSON.parse(text || "{}");
                    if (data.ok && data.keyd) {
                        root.pendingCapture = data;
                        root.lastError = "";
                    } else {
                        root.pendingCapture = data.raw ? data : null;
                        root.lastError = data.error || "Failed to read captured key";
                    }
                } catch (e) {
                    root.pendingCapture = null;
                    root.lastError = "Failed to parse captured key";
                }
            }
        }
        onExited: (code, status) => {
            root.captureReading = false;
        }
    }

    Process {
        id: keydCheckProc
        command: ["bash", "-c", "systemctl is-active keyd >/dev/null 2>&1 && echo ready || (command -v keyd >/dev/null 2>&1 && echo installed || echo missing)"]
        stdout: SplitParser {
            onRead: line => {
                root.keydReady = (line === "ready");
                if (line === "missing")
                    root.state = "setup";
                else if (root.state === "init" || root.state === "setup")
                    root.state = root.keydReady ? "ready" : "setup";
            }
        }
    }

    Process {
        id: listProc
        command: ["bash", `${root.shareDir}/omarchy-keyboard-list`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const detected = JSON.parse(text || "[]");
                    root.devices = detected;
                    root.mergeDevices(detected);
                } catch (e) {
                    console.error("[KeyboardRemap] device parse error:", e);
                }
            }
        }
    }

    Process {
        id: loadProc
        command: ["bash", "-c", `if [ -f '${root.profilesPath}' ]; then cat '${root.profilesPath}'; else echo '{"version":1,"devices":{}}'; fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text || "{}");
                    root.deviceProfiles = data.devices ?? {};
                } catch (e) {
                    console.error("[KeyboardRemap] profile load error:", e);
                    root.deviceProfiles = {};
                }
            }
        }
    }

    Process {
        id: saveProc
        property bool runApplyAfter: false
        property string payload: JSON.stringify({ version: 1, devices: root.deviceProfiles })
        command: ["bash", "-c", `printf '%s' '${StringUtils.shellSingleQuoteEscape(saveProc.payload)}' | jq . > '${root.profilesPath}'`]
        onRunningChanged: {
            if (saveProc.running)
                saveProc.payload = JSON.stringify({ version: 1, devices: root.deviceProfiles });
        }
        onExited: (code, status) => {
            if (!saveProc.runApplyAfter)
                return;
            saveProc.runApplyAfter = false;
            if (code === 0) {
                applyProc.running = true;
            } else {
                root.applyInProgress = false;
                root.state = "error";
                root.lastError = "Failed to save profiles";
            }
        }
    }

    Process {
        id: applyProc
        command: ["bash", `${root.shareDir}/omarchy-keyboard-apply`]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("ERROR:"))
                    root.lastError = line.replace(/^ERROR:\s*/, "");
            }
        }
        onExited: (code, status) => {
            root.applyInProgress = false;
            if (code === 0) {
                root.state = "ready";
                root.keydReady = true;
                root.lastError = "";
            } else {
                root.state = "error";
                if (root.lastError === "")
                    root.lastError = "Apply failed (code " + code + ")";
            }
            root.checkKeyd();
        }
    }

    Process {
        id: setupProc
        command: ["bash", `${root.shareDir}/omarchy-keyboard-setup`]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("ERROR:"))
                    root.lastError = line.replace(/^ERROR:\s*/, "");
            }
        }
        onExited: (code, status) => {
            if (code === 0) {
                root.keydReady = true;
                root.state = "ready";
                root.lastError = "";
            } else {
                root.state = "setup";
                if (root.lastError === "")
                    root.lastError = "keyd setup required";
            }
            root.checkKeyd();
        }
    }

    IpcHandler {
        target: "keyremap"

        function toggle(): void {
            root.openSettings();
        }
        function refresh(): void {
            root.refreshDevices();
            root.loadProfiles();
            root.checkKeyd();
        }
        function apply(): void {
            root.apply();
        }
    }
}