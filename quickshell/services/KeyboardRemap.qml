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
    property string capturedFromKey: ""
    property string capturedFromLabel: ""
    property string capturedFromCode: ""
    property bool captureWindowOpen: false
    property bool captureReading: false
    property var pendingCapture: null
    property string pendingPreset: ""
    property bool hasPendingChanges: false
    property bool reopenSettingsAfterCapture: false
    property var globalSettings: ({ enabledPresets: [] })

    readonly property string shareDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/bin`)
    readonly property string scriptsDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/scripts`)
    readonly property string dataDir: FileUtils.trimFileProtocol(`${Directories.config}/omd/keyboard-remap`)
    readonly property string profilesPath: `${root.dataDir}/profiles.json`

    readonly property var keyChoices: [
        "capslock", "escape", "grave", "tab", "space", "backspace", "enter", "delete", "insert",
        "home", "end", "pageup", "pagedown",
        "muhenkan", "henkan", "katakana", "katakanahiragana", "zenkakuhankaku",
        "leftshift", "rightshift", "leftcontrol", "rightcontrol", "leftalt", "rightalt", "leftmeta", "rightmeta",
        "left", "right", "up", "down",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
        "f13", "f14", "f15", "f16", "f17", "f18", "f19", "f20", "f21", "f22", "f23", "f24"
    ]

    readonly property var presets: ({
        "caps-esc": {
            "label": "Caps to Esc",
            "remaps": [{ "from": "capslock", "to": "escape" }]
        },
        "ctrl-caps-swap": {
            "label": "Ctrl <-> Caps",
            "remaps": [
                { "from": "leftcontrol", "to": "capslock" },
                { "from": "capslock", "to": "leftcontrol" }
            ]
        },
        "mac-meta": {
            "label": "Ctrl/Alt -> Meta",
            "remaps": [
                { "from": "leftcontrol", "to": "leftmeta" },
                { "from": "leftalt", "to": "leftmeta" }
            ]
        }
    })

    readonly property var globalPresetChoices: [
        {
            "id": "alt-win-swap",
            "label": "Swap Alt / Win",
            "description": "Applies left and right Alt <-> Win across every enabled keyboard.",
            "remaps": [
                { "from": "leftalt", "to": "leftmeta" },
                { "from": "leftmeta", "to": "leftalt" },
                { "from": "rightalt", "to": "rightmeta" },
                { "from": "rightmeta", "to": "rightalt" }
            ]
        },
        {
            "id": "ctrl-caps-swap",
            "label": "Swap Ctrl / Caps",
            "description": "Applies left Ctrl <-> Caps Lock across every enabled keyboard.",
            "remaps": [
                { "from": "leftcontrol", "to": "capslock" },
                { "from": "capslock", "to": "leftcontrol" }
            ]
        },
        {
            "id": "caps-esc",
            "label": "Caps to Esc",
            "description": "Makes Caps Lock send Escape across every enabled keyboard.",
            "remaps": [{ "from": "capslock", "to": "escape" }]
        }
    ]

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
    readonly property bool selectedKeydIdMissing: selectedProfile && !(selectedProfile.keydId ?? "").length

    function remapCount(hyprName) {
        const profile = root.deviceProfiles[hyprName];
        return profile ? (profile.remaps ?? []).length : 0;
    }

    function globalPresetEnabled(presetId) {
        return (root.globalSettings.enabledPresets ?? []).indexOf(presetId) >= 0;
    }

    function activeGlobalPresetCount() {
        return (root.globalSettings.enabledPresets ?? []).length;
    }

    function presetChoice(presetId) {
        return root.globalPresetChoices.find(p => p.id === presetId) ?? null;
    }

    function globalRemapsForEnabledPresets() {
        let rows = [];
        const enabled = root.globalSettings.enabledPresets ?? [];
        for (let i = 0; i < enabled.length; ++i) {
            const preset = root.presetChoice(enabled[i]);
            if (preset)
                rows = rows.concat(preset.remaps ?? []);
        }
        return rows;
    }

    function keysUsedByRemaps(rows) {
        const keys = [];
        const remaps = rows ?? [];
        for (let i = 0; i < remaps.length; ++i) {
            if (remaps[i].from && keys.indexOf(remaps[i].from) < 0)
                keys.push(remaps[i].from);
            if (remaps[i].to && keys.indexOf(remaps[i].to) < 0)
                keys.push(remaps[i].to);
        }
        return keys;
    }

    function remapKeysIntersect(leftRows, rightRows) {
        const left = root.keysUsedByRemaps(leftRows);
        const right = root.keysUsedByRemaps(rightRows);
        for (let i = 0; i < left.length; ++i) {
            if (right.indexOf(left[i]) >= 0)
                return true;
        }
        return false;
    }

    function globalRemapsForProfile(hyprName) {
        const profile = root.deviceProfiles[hyprName];
        const local = profile?.remaps ?? [];
        let rows = [];
        const enabled = root.globalSettings.enabledPresets ?? [];
        for (let i = 0; i < enabled.length; ++i) {
            const preset = root.presetChoice(enabled[i]);
            const presetRows = preset?.remaps ?? [];
            if (preset && !root.remapKeysIntersect(presetRows, local))
                rows = rows.concat(presetRows);
        }
        return rows;
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

    function normalizedGlobalPresetIds(ids) {
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

    function effectiveRemapsForProfile(hyprName) {
        const profile = root.deviceProfiles[hyprName];
        if (!profile || profile.enabled === false)
            return [];
        const merged = {};
        const globals = root.globalRemapsForProfile(hyprName);
        for (let i = 0; i < globals.length; ++i)
            merged[globals[i].from] = { from: globals[i].from, to: globals[i].to, source: "global" };
        const local = profile.remaps ?? [];
        for (let j = 0; j < local.length; ++j)
            merged[local[j].from] = { from: local[j].from, to: local[j].to, source: "local" };
        return Object.keys(merged).sort().map(k => merged[k]);
    }

    function globalOverrideCountForProfile(hyprName) {
        const profile = root.deviceProfiles[hyprName];
        if (!profile)
            return 0;
        const localSources = {};
        const local = profile.remaps ?? [];
        for (let i = 0; i < local.length; ++i)
            localSources[local[i].from] = true;
        const globals = root.globalRemapsForProfile(hyprName);
        let count = 0;
        for (let j = 0; j < globals.length; ++j) {
            if (localSources[globals[j].from])
                count++;
        }
        return count;
    }

    function hasMinilaLikeSelectedDevice() {
        const name = `${root.selectedProfile?.displayName ?? ""} ${root.selectedDeviceId}`.toLowerCase();
        return name.indexOf("minila") >= 0;
    }

    function setGlobalPresetEnabled(presetId, enabled) {
        if (root.applyInProgress)
            return;
        let current = root.normalizedGlobalPresetIds(root.globalSettings.enabledPresets);
        const idx = current.indexOf(presetId);
        if (enabled && idx < 0) {
            current = current.filter(id => !root.presetsConflict(id, presetId));
            current.push(presetId);
        } else if (!enabled && idx >= 0) {
            current.splice(idx, 1);
        } else {
            return;
        }
        root.globalSettings = Object.assign({}, root.globalSettings, { enabledPresets: current });
        root.hasPendingChanges = true;
        root.lastError = "";
        root.saveProfiles(false);
    }

    function remapTargetFor(fromKey) {
        const from = normalizeKeyName(fromKey);
        if (!from)
            return "";
        const remap = root.selectedRemaps.find(r => r.from === from);
        return remap?.to ?? "";
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.dataDir]);
        root.checkKeyd();
        root.refreshDevices();
        root.loadProfiles();
    }

    Timer {
        interval: 10000
        repeat: true
        running: GlobalStates.barPopupType === "keyremap"
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

    function checkPendingChanges() {
        pendingCheckProc.running = true;
    }

    function saveProfiles(runApplyAfter) {
        saveProc.stdinEnabled = true;
        saveProc.runApplyAfter = !!runApplyAfter;
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
            remaps: []
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

    function setDisplayName(name) {
        if (root.selectedDeviceId === "")
            return;
        const profile = root.deviceProfiles[root.selectedDeviceId];
        if (!profile)
            return;
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { displayName: name });
        root.deviceProfiles = next;
        root.hasPendingChanges = true;
        root.saveProfiles(false);
    }

    function startCapture() {
        root.pendingCapture = null;
        root.capturedFromKey = "";
        root.capturedFromLabel = "";
        root.capturedFromCode = "";
        root.lastError = "";
        root.captureWindowOpen = true;
        root.reopenSettingsAfterCapture = GlobalStates.barDialogOpen && GlobalStates.barDialogType === "keyremap";
        if (root.reopenSettingsAfterCapture)
            GlobalStates.barDialogOpen = false;
        captureWaitTimer.elapsed = 0;
        launchCaptureTimer.restart();
    }

    Timer {
        id: launchCaptureTimer
        interval: 250
        repeat: false
        onTriggered: {
            // Launch after the settings dialog has been unmapped, otherwise the
            // layer-shell settings window can race the GTK capture window.
            Quickshell.execDetached([`${root.scriptsDir}/key-test-launcher`, "--remap-source"]);
            captureWaitTimer.restart();
        }
    }

    // Poll every 800ms: check if key-test process is still alive by PID.
    // When it exits, read the state file once and auto-fill the source key.
    Timer {
        id: captureWaitTimer
        interval: 800
        repeat: true
        property int elapsed: 0
        onTriggered: {
            elapsed += interval;
            captureCheckProc.running = true;
            // Safety timeout: 2 minutes
            if (elapsed > 120000) {
                captureWaitTimer.stop();
                root.captureWindowOpen = false;
                root.restoreSettingsAfterCapture();
            }
        }
    }

    function restoreSettingsAfterCapture() {
        if (!root.reopenSettingsAfterCapture)
            return;
        root.reopenSettingsAfterCapture = false;
        root.openSettings();
    }

    Process {
        id: captureCheckProc
        // Check the lock file written by key-test. When it's gone, the
        // capture window has closed — read the state file and auto-fill.
        command: ["bash", "-c", "test -f ~/.local/state/omd/key-capture.lock && echo running || echo done"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "done" && root.captureWindowOpen) {
                    captureWaitTimer.stop();
                    captureWaitTimer.elapsed = 0;
                    root.captureWindowOpen = false;
                    root.captureReading = true;
                    readCaptureProc.running = true;
                }
            }
        }
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
        root.restoreSettingsAfterCapture();
    }

    function clearCapturedKey() {
        root.capturedFromKey = "";
        root.capturedFromLabel = "";
        root.capturedFromCode = "";
        root.pendingCapture = null;
        root.captureWindowOpen = false;
        root.reopenSettingsAfterCapture = false;
    }

    function saveRemap(toKey) {
        if (root.selectedDeviceId === "" || !root.capturedFromKey || !toKey)
            return;
        if (root.addRemap(root.capturedFromKey, toKey, true)) {
            root.clearCapturedKey();
        }
    }

    function addRemap(fromKey, toKey, saveAfter = true) {
        if (root.selectedDeviceId === "" || !fromKey || !toKey)
            return false;
        const from = normalizeKeyName(fromKey);
        const to = normalizeKeyName(toKey);
        if (!from || !to) {
            root.lastError = "Unknown key name in remap";
            return false;
        }
        if (from === to) {
            root.lastError = `Cannot remap a key to itself: ${from}`;
            return false;
        }
        root.ensureProfile(root.selectedDeviceId);
        const profile = root.deviceProfiles[root.selectedDeviceId];
        const remaps = (profile.remaps ?? []).slice();
        const existingTo = remaps.find(r => r.from === from)?.to;
        if (existingTo === to) {
            root.lastError = "";
            return true;
        }
        const idx = remaps.findIndex(r => r.from === from);
        const row = { from: from, to: to };
        if (idx >= 0)
            remaps[idx] = row;
        else
            remaps.push(row);
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { remaps: remaps });
        root.deviceProfiles = next;
        root.hasPendingChanges = true;
        if (saveAfter)
            root.saveProfiles(false);
        return true;
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

    function startEditRemap(fromKey) {
        const existingTarget = root.remapTargetFor(fromKey);
        root.capturedFromKey = fromKey;
        root.capturedFromLabel = fromKey;
        root.capturedFromCode = "";
        root.pendingCapture = null;
        root.lastError = "";
        return existingTarget;
    }

    function applyPreset(presetId) {
        const preset = root.presets[presetId];
        if (!preset || root.selectedDeviceId === "")
            return;
        root.pendingPreset = "";
        root.ensureProfile(root.selectedDeviceId);
        const profile = root.deviceProfiles[root.selectedDeviceId];
        const next = Object.assign({}, root.deviceProfiles);
        next[root.selectedDeviceId] = Object.assign({}, profile, { remaps: preset.remaps.slice() });
        root.deviceProfiles = next;
        root.hasPendingChanges = true;
        root.saveProfiles(false);
    }

    function cancelPreset() {
        root.pendingPreset = "";
    }

    function mergeDevices(detected) {
        let selected = root.selectedDeviceId;
        let mainId = "";
        let firstId = "";
        let firstWithRemapsId = "";
        let anyNew = false;
        for (let i = 0; i < detected.length; ++i) {
            if (!firstId)
                firstId = detected[i].hyprName;
            if (detected[i].main)
                mainId = detected[i].hyprName;
            if (root.ensureProfileSilent(detected[i]))
                anyNew = true;
            if (!firstWithRemapsId && root.remapCount(detected[i].hyprName) > 0)
                firstWithRemapsId = detected[i].hyprName;
        }
        const fallbackId = mainId || firstWithRemapsId || firstId;
        if (!selected && fallbackId)
            selected = fallbackId;
        else if (selected && !detected.some(d => d.hyprName === selected) && fallbackId)
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
            remaps: []
        };
        root.deviceProfiles = next;
        return true;
    }

    function openSettings() {
        GlobalStates.barPopupType = "";
        GlobalStates.barDialogType = "keyremap";
        GlobalStates.barDialogOpen = true;
    }

    function openPanel() {
        root.openSettings();
    }

    function normalizeKeyName(name) {
        if (!name)
            return "";
        const n = String(name).trim().toLowerCase();
        if (n === "esc")
            return "escape";
        return n;
    }

    Process {
        id: readCaptureProc
        command: ["python3", `${root.scriptsDir}/keyremap-capture-read`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.captureReading = false
                root.captureWindowOpen = false
                try {
                    const data = JSON.parse(text || "{}")
                    if (data.ok && data.keyd) {
                        // Auto-accept: fill the source key directly, no manual confirm step.
                        root.capturedFromKey = data.keyd
                        root.capturedFromLabel = data.raw || data.keyd
                        root.capturedFromCode = data.keycode !== undefined && data.keycode !== null
                            ? String(data.keycode) : ""
                        root.pendingCapture = null
                        root.lastError = ""
                    } else {
                        root.pendingCapture = data.raw ? data : null
                        root.lastError = data.error || "Failed to read captured key"
                    }
                } catch (e) {
                    root.pendingCapture = null
                    root.lastError = "Failed to parse captured key"
                }
                root.restoreSettingsAfterCapture()
            }
        }
        onExited: (code, status) => {
            root.captureReading = false
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
        command: ["bash", "-c", `if [ -f '${root.profilesPath}' ]; then cat '${root.profilesPath}'; else echo '{"version":1,"devices":{}}'; fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text || "{}");
                    root.deviceProfiles = data.devices ?? {};
                    const loadedGlobal = data.global ?? { enabledPresets: [] };
                    const normalizedPresets = root.normalizedGlobalPresetIds(loadedGlobal.enabledPresets);
                    const globalChanged = JSON.stringify(normalizedPresets) !== JSON.stringify(loadedGlobal.enabledPresets ?? []);
                    root.globalSettings = Object.assign({}, loadedGlobal, { enabledPresets: normalizedPresets });
                    root.profilesLoaded = true;
                    root.hasPendingChanges = false;
                    if (root._pendingDevices.length > 0) {
                        const pending = root._pendingDevices;
                        root._pendingDevices = [];
                        root.mergeDevices(pending);
                    }
                    if (globalChanged)
                        root.saveProfiles(false);
                    root.checkPendingChanges();
                } catch (e) {
                    console.error("[KeyboardRemap] profile load error:", e);
                    root.deviceProfiles = {};
                    root.globalSettings = { enabledPresets: [] };
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
        command: ["bash", "-c", `tmp="$(mktemp '${root.profilesPath}.XXXXXX')" || exit 1; if jq . > "$tmp"; then mv "$tmp" '${root.profilesPath}'; else rm -f "$tmp"; exit 1; fi`]
        stdinEnabled: true
        onRunningChanged: {
            if (saveProc.running) {
                const payload = JSON.stringify({ version: 1, global: root.globalSettings, devices: root.deviceProfiles });
                saveProc.write(payload);
                saveProc.stdinEnabled = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.state !== "applying") {
                root.lastError = `Failed to save profiles (jq exit ${code})`;
            }
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
        }
        function apply(): void {
            root.apply();
        }
    }
}
