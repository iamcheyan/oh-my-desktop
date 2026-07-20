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
    property bool profilesLoaded: false
    property bool hasPendingChanges: false
    property bool functionRowAvailable: false
    property string functionRowMode: "unsupported"
    property int functionRowValue: -1
    property bool functionRowBusy: false
    property string functionRowError: ""

    readonly property string shareDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/bin`)
    // Sumika Shell config home (user-authored data lives here)
    readonly property string sumikaConfigHome: `${FileUtils.trimFileProtocol(Directories.config)}/sumika-shell`
    // Canonical write path (new location)
    readonly property string dataDir: `${sumikaConfigHome}/keyboard-remap`
    readonly property string profilesPath: `${root.dataDir}/profiles.json`
    // Legacy read fallback (old location, removed in Phase 7)
    readonly property string dataDirLegacy: FileUtils.trimFileProtocol(`${Directories.config}/omd/keyboard-remap`)
    readonly property string profilesPathLegacy: `${dataDirLegacy}/profiles.json`
    readonly property string functionRowHelper: FileUtils.trimFileProtocol(`${Directories.config}/omd/bin/omd-keyboard-function-row`)

    function applyFunctionRowStatus(text) {
        try {
            const data = JSON.parse(text.trim());
            root.functionRowAvailable = data.available === true;
            root.functionRowMode = data.mode || "unsupported";
            root.functionRowValue = Number(data.value ?? -1);
            root.functionRowError = "";
        } catch (error) {
            root.functionRowError = `Could not read Apple function-row state: ${error}`;
        }
    }

    function refreshFunctionRow() {
        if (!functionRowStatusProc.running)
            functionRowStatusProc.running = true;
    }

    function setFunctionRowMode(mode) {
        if (!root.functionRowAvailable || root.functionRowBusy || !["media", "function", "auto"].includes(mode))
            return;
        root.functionRowBusy = true;
        root.functionRowError = "";
        functionRowSetProc.command = [root.functionRowHelper, "set", mode];
        functionRowSetProc.running = true;
    }

    readonly property var keyChoices: [
        "escape", "tab", "space", "backspace", "enter", "delete", "insert",
        "home", "end", "pageup", "pagedown",
        "grave", "minus", "equal",
        "leftshift", "rightshift", "leftcontrol", "rightcontrol", "leftalt", "rightalt", "leftmeta", "rightmeta",
        "capslock", "muhenkan", "henkan", "katakana", "katakanahiragana", "zenkakuhankaku",
        "left", "right", "up", "down",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
        "f13", "f14", "f15", "f16", "f17", "f18", "f19", "f20"
    ]

    readonly property var globalPresetChoices: [
        {
            "id": "alt-win-swap",
            "label": "Swap Left Alt / Win",
            "description": "Applies left Alt <-> left Win.",
            "type": "swap",
            "remaps": [
                { "from": "leftalt", "to": "leftmeta" },
                { "from": "leftmeta", "to": "leftalt" }
            ]
        },
        {
            "id": "ctrl-caps-swap",
            "label": "Swap Ctrl / Caps",
            "description": "Applies left Ctrl <-> Caps Lock.",
            "type": "swap",
            "remaps": [
                { "from": "leftcontrol", "to": "capslock" },
                { "from": "capslock", "to": "leftcontrol" }
            ]
        },
        {
            "id": "grave-esc-swap",
            "label": "Swap Grave / Esc",
            "description": "Swaps the Grave (`) and Escape keys.",
            "type": "swap",
            "remaps": [
                { "from": "grave", "to": "escape" },
                { "from": "escape", "to": "grave" }
            ]
        },
        {
            "id": "caps-esc",
            "label": "Caps to Esc",
            "description": "Makes Caps Lock send Escape.",
            "type": "remap",
            "remaps": [{ "from": "capslock", "to": "escape" }]
        },
        {
            "id": "muhenkan-meta",
            "label": "Muhenkan → Custom",
            "description": "Makes the Muhenkan (無変換) key send a custom target key.",
            "type": "remap",
            "remaps": [{ "from": "muhenkan", "to": "leftmeta" }]
        },
        {
            "id": "kana-left",
            "label": "Katakana/Hiragana to Left",
            "description": "Makes the Katakana/Hiragana key send Left arrow.",
            "type": "remap",
            "remaps": [{ "from": "katakanahiragana", "to": "left" }]
        },
        {
            "id": "rightalt-down",
            "label": "Right Alt to Down",
            "description": "Makes Right Alt send Down arrow.",
            "type": "remap",
            "remaps": [{ "from": "rightalt", "to": "down" }]
        },
        {
            "id": "rightmeta-down",
            "label": "Right Win to Down",
            "description": "Makes Right Super (Win) send Down arrow.",
            "type": "remap",
            "remaps": [{ "from": "rightmeta", "to": "down" }]
        },
        {
            "id": "delete-right",
            "label": "Delete to Right",
            "description": "Makes the Delete key send Right arrow.",
            "type": "remap",
            "remaps": [{ "from": "delete", "to": "right" }]
        },
        {
            "id": "rightctrl-up",
            "label": "Right Ctrl to Up",
            "description": "Makes Right Ctrl send Up arrow.",
            "type": "remap",
            "remaps": [{ "from": "rightcontrol", "to": "up" }]
        }
    ]

    readonly property var selectedProfile: selectedDeviceId !== "" ? (deviceProfiles[selectedDeviceId] ?? null) : null
    readonly property bool selectedEnabled: selectedProfile?.enabled !== false
    readonly property var availableDevices: {
        const merged = [];
        const connectedIds = [];
        for (let i = 0; i < root.devices.length; ++i) {
            const device = root.devices[i];
            connectedIds.push(device.hyprName);
            merged.push(Object.assign({}, device, { connected: true }));
        }
        for (const hyprName of Object.keys(root.deviceProfiles)) {
            if (connectedIds.indexOf(hyprName) >= 0)
                continue;
            const profile = root.deviceProfiles[hyprName];
            merged.push({
                hyprName: hyprName,
                rawName: hyprName,
                displayName: profile.displayName || hyprName,
                keydId: profile.keydId || "",
                layout: "",
                main: false,
                connected: false
            });
        }
        return merged;
    }
    readonly property var selectedDevice: {
        for (let i = 0; i < availableDevices.length; ++i) {
            if (availableDevices[i].hyprName === selectedDeviceId)
                return availableDevices[i];
        }
        return null;
    }
    readonly property bool selectedKeydIdMissing: selectedProfile && !(selectedProfile.keydId ?? "").length

    // ── Preset helpers ──

    function presetChoice(presetId) {
        return root.globalPresetChoices.find(p => p.id === presetId) ?? null;
    }

    function presetSourceKeys(presetId) {
        const preset = root.presetChoice(presetId);
        return (preset?.remaps ?? []).map(r => r.from);
    }

    function presetsConflict(leftId, rightId) {
        if (leftId === rightId)
            return false;
        const left = root.presetSourceKeys(leftId);
        const right = root.presetSourceKeys(rightId);
        for (let i = 0; i < left.length; ++i) {
            if (right.indexOf(left[i]) >= 0)
                return true;
        }
        return false;
    }

    function normalizedPresetIds(ids) {
        let result = [];
        const source = ids ?? [];
        for (let i = 0; i < source.length; ++i) {
            const id = source[i];
            if (!root.presetChoice(id) || result.indexOf(id) >= 0)
                continue;
            result = result.filter(existing => !root.presetsConflict(existing, id));
            result.push(id);
        }
        return result;
    }

    // ── Per-device presets ──

    function devicePresetEnabled(hyprName, presetId) {
        const profile = root.deviceProfiles[hyprName];
        return (profile?.enabledPresets ?? []).indexOf(presetId) >= 0;
    }

    function devicePresetCount(hyprName) {
        const profile = root.deviceProfiles[hyprName];
        if (!profile || profile.enabled === false)
            return 0;
        return (profile.enabledPresets ?? []).length;
    }

    function setDevicePresetEnabled(hyprName, presetId, enabled) {
        if (root.applyInProgress)
            return;
        const profile = root.deviceProfiles[hyprName];
        if (!profile)
            return;
        let current = root.normalizedPresetIds(profile.enabledPresets ?? []);
        const idx = current.indexOf(presetId);
        if (enabled && idx < 0) {
            current = current.filter(id => !root.presetsConflict(id, presetId));
            current.push(presetId);
        } else if (!enabled && idx >= 0) {
            current.splice(idx, 1);
        } else {
            return;
        }
        const next = Object.assign({}, root.deviceProfiles);
        next[hyprName] = Object.assign({}, profile, { enabledPresets: current });
        root.deviceProfiles = next;
        root.hasPendingChanges = true;
        root.lastError = "";
        root.saveProfiles(false);
    }

    // ── Per-device preset overrides (custom target keys) ──

    function presetOverride(hyprName, presetId) {
        const profile = root.deviceProfiles[hyprName];
        const overrides = profile?.presetOverrides ?? {};
        return overrides[presetId] ?? "";
    }

    function setPresetOverride(hyprName, presetId, targetKey) {
        if (root.applyInProgress)
            return;
        const profile = root.deviceProfiles[hyprName];
        if (!profile)
            return;
        const overrides = Object.assign({}, profile.presetOverrides ?? {});
        if (targetKey && targetKey.length > 0) {
            overrides[presetId] = targetKey;
        } else {
            delete overrides[presetId];
        }
        const next = Object.assign({}, root.deviceProfiles);
        next[hyprName] = Object.assign({}, profile, { presetOverrides: overrides });
        root.deviceProfiles = next;
        root.hasPendingChanges = true;
        root.lastError = "";
        root.saveProfiles(false);
    }

    // Returns the effective remaps for a preset on a device,
    // applying any custom target overrides.
    function effectivePresetRemaps(hyprName, presetId) {
        const preset = root.presetChoice(presetId);
        if (!preset)
            return [];
        const override = root.presetOverride(hyprName, presetId);
        return (preset.remaps ?? []).map(r => {
            if (override && override.length > 0 && preset.type === "remap")
                return { from: r.from, to: override };
            return r;
        });
    }

    // ── Lifecycle ──

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.dataDir]);
        root.checkKeyd();
        root.refreshDevices();
        root.loadProfiles();
        root.refreshFunctionRow();
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refreshDevices()
    }

    function checkKeyd() { keydCheckProc.running = true; }
    function refreshDevices() { listProc.running = true; }
    function loadProfiles() { loadProc.running = true; }
    function checkPendingChanges() { pendingCheckProc.running = true; }

    function saveProfiles(runApplyAfter) {
        saveProc.runApplyAfter = saveProc.runApplyAfter || !!runApplyAfter;
        if (saveProc.running) {
            saveProc.saveQueued = true;
            return;
        }
        saveProc.stdinEnabled = true;
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
        root.saveProfiles(true);
    }

    function selectDevice(hyprName) {
        root.selectedDeviceId = hyprName;
        root.ensureProfile(hyprName);
    }

    function ensureProfile(hyprName) {
        if (!hyprName || root.deviceProfiles[hyprName])
            return;
        const profile = root.createEmptyProfile(hyprName);
        const next = Object.assign({}, root.deviceProfiles);
        next[hyprName] = profile;
        root.deviceProfiles = next;
        root.saveProfiles(false);
    }

    function createEmptyProfile(hyprName) {
        let displayName = hyprName;
        let keydId = "";
        for (let i = 0; i < root.devices.length; ++i) {
            if (root.devices[i].hyprName === hyprName) {
                displayName = root.devices[i].displayName || hyprName;
                keydId = root.devices[i].keydId || "";
                break;
            }
        }
        return {
            displayName: displayName,
            hyprName: hyprName,
            keydId: keydId,
            enabled: true,
            enabledPresets: [],
            presetOverrides: {}
        };
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
        root.hasPendingChanges = true;
        root.saveProfiles(false);
    }

    function deleteProfile(hyprName) {
        if (!hyprName)
            return;
        const next = Object.assign({}, root.deviceProfiles);
        delete next[hyprName];
        root.deviceProfiles = next;
        if (root.selectedDeviceId === hyprName)
            root.selectedDeviceId = "";
        root.hasPendingChanges = true;
        root.saveProfiles(false);
    }

    function mergeDevices(detected) {
        let selected = root.selectedDeviceId;
        let mainId = "";
        let firstId = "";
        let firstWithPresetsId = "";
        let anyNew = false;
        for (let i = 0; i < detected.length; ++i) {
            if (!firstId)
                firstId = detected[i].hyprName;
            if (detected[i].main)
                mainId = detected[i].hyprName;
            if (root.ensureProfileSilent(detected[i]))
                anyNew = true;
            if (!firstWithPresetsId && root.devicePresetCount(detected[i].hyprName) > 0)
                firstWithPresetsId = detected[i].hyprName;
        }
        const fallbackId = mainId || firstWithPresetsId || firstId;
        if (!selected && fallbackId)
            selected = fallbackId;
        else if (selected && !root.deviceProfiles[selected] && fallbackId)
            selected = fallbackId;
        root.selectedDeviceId = selected;
        if (anyNew)
            root.saveProfiles(false);
    }

    function ensureProfileSilent(device) {
        const hyprName = device.hyprName;
        if (!hyprName)
            return false;
        if (root.deviceProfiles[hyprName]) {
            const existing = root.deviceProfiles[hyprName];
            if (!existing.keydId && device.keydId) {
                const next = Object.assign({}, root.deviceProfiles);
                next[hyprName] = Object.assign({}, existing, { keydId: device.keydId });
                root.deviceProfiles = next;
                return true;
            }
            return false;
        }
        const next = Object.assign({}, root.deviceProfiles);
        next[hyprName] = {
            displayName: device.displayName || hyprName,
            hyprName: hyprName,
            keydId: device.keydId || "",
            enabled: true,
            enabledPresets: [],
            presetOverrides: {}
        };
        root.deviceProfiles = next;
        return true;
    }

    function openSettings() {
        GlobalStates.barPopupType = "";
        Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "keyremap"]);
    }

    function openPanel() {
        root.openSettings();
    }

    // ── Processes ──

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
        command: ["bash", `${root.shareDir}/omd-keyboard-list`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const detected = JSON.parse(text || "[]");
                    root.devices = detected;
                    if (root.profilesLoaded)
                        root.mergeDevices(detected);
                    else
                        root._pendingDevices = detected;
                } catch (e) {
                    console.error("[KeyboardRemap] device parse error:", e);
                }
            }
        }
    }

    property var _pendingDevices: []

    Process {
        id: loadProc
        command: ["bash", "-c", `if [ -f '${root.profilesPath}' ]; then cat '${root.profilesPath}'; elif [ -f '${root.profilesPathLegacy}' ]; then cat '${root.profilesPathLegacy}'; else echo '{"version":1,"devices":{}}'; fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text || "{}");
                    const rawDevices = data.devices ?? {};
                    let anyDeviceChanged = false;
                    const normalizedDevices = {};
                    for (const hyprName of Object.keys(rawDevices)) {
                        const profile = rawDevices[hyprName];
                        const rawDevicePresets = profile.enabledPresets ?? [];
                        const normDevicePresets = root.normalizedPresetIds(rawDevicePresets);
                        if (JSON.stringify(normDevicePresets) !== JSON.stringify(rawDevicePresets))
                            anyDeviceChanged = true;
                        normalizedDevices[hyprName] = Object.assign({}, profile, { enabledPresets: normDevicePresets });
                    }
                    root.deviceProfiles = normalizedDevices;
                    root.profilesLoaded = true;
                    root.hasPendingChanges = false;
                    if (root._pendingDevices.length > 0) {
                        const pending = root._pendingDevices;
                        root._pendingDevices = [];
                        root.mergeDevices(pending);
                    }
                    if (anyDeviceChanged)
                        root.saveProfiles(false);
                    root.checkPendingChanges();
                } catch (e) {
                    console.error("[KeyboardRemap] profile load error:", e);
                    root.deviceProfiles = {};
                    root.profilesLoaded = true;
                    root.hasPendingChanges = false;
                    root.checkPendingChanges();
                }
            }
        }
    }

    Process {
        id: pendingCheckProc
        command: ["bash", "-c", `'${root.shareDir}/omd-keyboard-render' | cmp -s - /etc/keyd/omd.conf && echo applied || echo pending`]
        stdout: SplitParser {
            onRead: line => {
                root.hasPendingChanges = (line === "pending");
            }
        }
    }

    Process {
        id: saveProc
        property bool runApplyAfter: false
        property bool saveQueued: false
        command: ["bash", "-c", `tmp="$(mktemp '${root.profilesPath}.XXXXXX')" || exit 1; if jq . > "$tmp"; then mv "$tmp" '${root.profilesPath}'; else rm -f "$tmp"; exit 1; fi`]
        stdinEnabled: true
        onRunningChanged: {
            if (saveProc.running) {
                const payload = JSON.stringify({ version: 1, devices: root.deviceProfiles });
                saveProc.write(payload);
                saveProc.stdinEnabled = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.state !== "applying") {
                root.lastError = `Failed to save profiles (jq exit ${code})`;
            }
            if (code === 0 && saveProc.saveQueued) {
                saveProc.saveQueued = false;
                saveProc.stdinEnabled = true;
                saveProc.running = true;
                return;
            }
            saveProc.saveQueued = false;
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
        command: ["bash", `${root.shareDir}/omd-keyboard-apply`]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("ERROR:"))
                    root.lastError = line.replace(/^ERROR:\s*/, "");
            }
        }
        stderr: SplitParser {
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
                root.hasPendingChanges = false;
                root.lastError = "";
            } else {
                root.state = "error";
                if (root.lastError === "")
                    root.lastError = "Apply failed (code " + code + ")";
            }
            root.checkKeyd();
            root.checkPendingChanges();
        }
    }

    Process {
        id: setupProc
        command: ["bash", `${root.shareDir}/omd-keyboard-setup`]
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

    Process {
        id: functionRowStatusProc
        command: [root.functionRowHelper, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.applyFunctionRowStatus(text)
        }
    }

    Process {
        id: functionRowSetProc

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output.length > 0)
                    root.applyFunctionRowStatus(output);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.functionRowError = message;
            }
        }
        onExited: (code, status) => {
            root.functionRowBusy = false;
            if (code !== 0 && root.functionRowError.length === 0)
                root.functionRowError = `Function-row change failed (code ${code})`;
            root.refreshFunctionRow();
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
            root.checkPendingChanges();
            root.refreshFunctionRow();
        }
        function apply(): void {
            root.apply();
        }
    }
}
