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

    readonly property string badge: {
        if (root.language === "zh") return "中";
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
        if (root.busy)
            return;
        root.busy = true;
        root.lastError = "";
        root.pendingSchema = schemaId;

        // Rime's D-Bus service operates on Fcitx's most recent input context.
        // Return focus to the application before selecting its schema.
        if (windowAddress && windowAddress.length > 0)
            Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowAddress}"})`);
        switchDelay.restart();
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
                root.pendingSchema = "";
                refreshTimer.restart();
            }
        }
    }

    Timer {
        id: switchDelay
        interval: 180
        repeat: false
        onTriggered: {
            switchProcess.command = [root.helper, "set", root.pendingSchema];
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
