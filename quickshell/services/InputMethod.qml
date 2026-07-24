pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string helper: (function() {
        const root = FileUtils.trimFileProtocol(Directories.root)
        const imDir = root + "/quickshell/modules/input-method"
        if (FileUtils.exists(imDir))
            return imDir + "/bin/omd-input-method"
        console.warn("[InputMethod] input-method module not in core, input method agent unavailable")
        return ""
    })()
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

    property var schemas: []

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
            root.schemas = data.schemas || [];
            root.lastError = "";
        } catch (error) {
            root.available = false;
            root.lastError = `${error}`;
        }
    }

    Process {
        id: statusProcess
        command: [root.helper, "status"]
        running: ModuleLoader.isEnabled("input-method")

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
        running: ModuleLoader.isEnabled("input-method")
        repeat: true
        onTriggered: root.refresh()
    }
}
