pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string helper: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-input-method`
    property bool available: false
    property bool busy: false
    property string inputMethod: ""
    property string schema: ""
    property string language: "unknown"
    property string displayName: "Input method"
    property string variant: ""
    property string lastError: ""
    property string pendingSchema: ""
    property string activeSwitchSchema: ""
    property string queuedSchema: ""
    property string queuedWindowAddress: ""

    readonly property var schemas: [
        { id: "sbzr", badge: "中", title: "Chinese", variant: "Natural input" },
        { id: "sbzr_mix", badge: "混", title: "Chinese", variant: "Mixed input" },
        { id: "easy_en", badge: "A", title: "English", variant: "Easy English" },
        { id: "jaroomaji", badge: "あ", title: "Japanese", variant: "Romaji" }
    ]

    signal osdRequested()

    readonly property string badge: {
        if (root.language === "zh") {
            // Differentiate between natural and mixed Chinese input
            if (root.schema === "sbzr_mix") return "混";
            return "中";
        }
        if (root.language === "ja") return "あ";
        if (root.language === "en") return "A";
        return "?";
    }

    readonly property string summary: root.variant.length > 0
        ? `${root.displayName} · ${root.variant}`
        : root.displayName

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    function selectSchema(schemaId, windowAddress) {
        if (!schemaId || root.schemas.findIndex(item => item.id === schemaId) < 0)
            return;
        root.pendingSchema = schemaId;
        if (root.busy) {
            root.queuedSchema = schemaId;
            root.queuedWindowAddress = windowAddress || "";
            return;
        }
        root.busy = true;
        root.lastError = "";
        root.activeSwitchSchema = schemaId;

        // Rime's D-Bus service operates on Fcitx's most recent input context.
        // Return focus to the application before selecting its schema.
        if (windowAddress && windowAddress.length > 0)
            Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowAddress}"})`);
        switchDelay.restart();
    }

    function cycleSchema(direction) {
        const count = root.schemas.length;
        if (count === 0)
            return;
        const current = root.pendingSchema || root.schema;
        let index = root.schemas.findIndex(item => item.id === current);
        if (index < 0)
            index = direction < 0 ? 0 : -1;
        const nextIndex = (index + (direction < 0 ? -1 : 1) + count) % count;
        root.selectSchema(root.schemas[nextIndex].id, "");
        root.osdRequested();
    }

    function openConfiguration() {
        Quickshell.execDetached([root.helper, "config"]);
    }

    function applyStatus(text) {
        try {
            const data = JSON.parse(text.trim());
            root.available = data.available === true;
            root.inputMethod = data.inputMethod || "";
            root.schema = data.schema || "";
            root.language = data.language || "unknown";
            root.displayName = data.displayName || "Input method";
            root.variant = data.variant || "";
            root.lastError = "";
        } catch (error) {
            root.available = false;
            root.lastError = `${error}`;
        }
    }

    Process {
        id: statusProcess
        command: [root.helper, "status"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Process {
        id: switchProcess

        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.lastError = message;
            }
        }

        onRunningChanged: {
            if (!running) {
                root.busy = false;
                root.activeSwitchSchema = "";
                refreshTimer.restart();
                if (root.queuedSchema.length > 0) {
                    const nextSchema = root.queuedSchema;
                    const nextAddress = root.queuedWindowAddress;
                    root.queuedSchema = "";
                    root.queuedWindowAddress = "";
                    Qt.callLater(() => root.selectSchema(nextSchema, nextAddress));
                } else {
                    root.pendingSchema = "";
                }
            }
        }
    }

    Timer {
        id: switchDelay
        interval: 180
        repeat: false
        onTriggered: {
            switchProcess.command = [root.helper, "set", root.activeSwitchSchema];
            switchProcess.running = true;
        }
    }

    Timer {
        id: refreshTimer
        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
