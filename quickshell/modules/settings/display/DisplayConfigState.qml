import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var outputs: []
    property var drafts: ({})
    property string errorText: ""
    property bool refreshing: false
    property bool applying: false
    property int revision: 0

    readonly property var visibleOutputs: (revision, outputs.filter(output => output.connected !== false && !draftFor(output.name).disabled))
    readonly property bool hasPendingChanges: (revision, pendingOutputNames().length > 0)

    signal applied(string message)

    function refresh() {
        if (refreshing)
            return;
        refreshing = true;
        errorText = "";
        monitorProc.running = true;
    }

    function normalizeMode(mode, output) {
        if (!mode || String(mode).length === 0)
            return `${output.width}x${output.height}@${Number(output.refreshRate || 60).toFixed(2)}Hz`;
        return String(mode).replace(" ", "").replace("@", "@");
    }

    function formatModeLabel(mode) {
        const parsed = parseMode(mode);
        if (!parsed)
            return mode || "Auto";
        return `${parsed.w} x ${parsed.h} @ ${Math.round(parsed.hz)}Hz`;
    }

    function parseMode(mode) {
        const match = String(mode || "").match(/^(\d+)x(\d+)@([\d.]+)Hz?$/i);
        if (!match)
            return null;
        return {
            w: parseInt(match[1]),
            h: parseInt(match[2]),
            hz: parseFloat(match[3])
        };
    }

    function scaleLabel(scale) {
        const value = Number(scale || 1);
        return `${Math.round(value * 100)}%`;
    }

    function transformLabel(transform) {
        const labels = {
            0: "Normal",
            1: "90 deg",
            2: "180 deg",
            3: "270 deg",
            4: "Flipped",
            5: "Flipped 90 deg",
            6: "Flipped 180 deg",
            7: "Flipped 270 deg"
        };
        return labels[Number(transform || 0)] || "Normal";
    }

    function draftFor(name) {
        if (!name)
            return {};
        if (drafts[name] !== undefined)
            return drafts[name];
        const output = outputByName(name);
        if (!output)
            return {};
        return makeDraft(output);
    }

    function makeDraft(output) {
        return {
            name: output.name,
            mode: normalizeMode(output.currentMode, output),
            x: Number(output.x || 0),
            y: Number(output.y || 0),
            scale: Number(output.scale || 1),
            transform: Number(output.transform || 0),
            disabled: output.disabled === true
        };
    }

    function setDraftValue(name, key, value) {
        const next = Object.assign({}, drafts);
        const draft = Object.assign({}, draftFor(name));
        draft[key] = value;
        next[name] = draft;
        drafts = next;
        revision++;
    }

    function updatePosition(name, x, y) {
        setDraftValue(name, "x", Math.round(x));
        setDraftValue(name, "y", Math.round(y));
    }

    function outputByName(name) {
        for (const output of outputs) {
            if (output.name === name)
                return output;
        }
        return null;
    }

    function displayName(output) {
        if (!output)
            return "Unknown display";
        if (output.description && output.description.length > 0)
            return output.description;
        if (output.make || output.model)
            return `${output.make || ""} ${output.model || ""}`.trim();
        return output.name || "Display";
    }

    function physicalSize(output) {
        const draft = draftFor(output.name);
        const mode = parseMode(draft.mode) || parseMode(output.currentMode);
        return {
            w: mode ? mode.w : Number(output.width || 1920),
            h: mode ? mode.h : Number(output.height || 1080)
        };
    }

    function logicalSize(output) {
        const size = physicalSize(output);
        const draft = draftFor(output.name);
        const scale = Math.max(0.25, Number(draft.scale || output.scale || 1));
        const transform = Number(draft.transform || 0);
        const rotated = transform === 1 || transform === 3 || transform === 5 || transform === 7;
        const w = rotated ? size.h : size.w;
        const h = rotated ? size.w : size.h;
        return {
            w: Math.round(w / scale),
            h: Math.round(h / scale)
        };
    }

    function bounds() {
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;

        for (const output of visibleOutputs) {
            const draft = draftFor(output.name);
            const size = logicalSize(output);
            minX = Math.min(minX, Number(draft.x || 0));
            minY = Math.min(minY, Number(draft.y || 0));
            maxX = Math.max(maxX, Number(draft.x || 0) + size.w);
            maxY = Math.max(maxY, Number(draft.y || 0) + size.h);
        }

        if (minX === Infinity)
            return { minX: 0, minY: 0, width: 1920, height: 1080 };
        return { minX: minX, minY: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) };
    }

    function checkOverlap(testName, testX, testY, testW, testH) {
        for (const output of visibleOutputs) {
            if (output.name === testName)
                continue;
            const draft = draftFor(output.name);
            const size = logicalSize(output);
            const x = Number(draft.x || 0);
            const y = Number(draft.y || 0);
            if (testX < x + size.w && testX + testW > x && testY < y + size.h && testY + testH > y)
                return true;
        }
        return false;
    }

    function snapToEdges(testName, posX, posY, testW, testH) {
        const threshold = 80;
        let bestX = posX;
        let bestY = posY;
        let bestDistance = threshold + 1;

        function candidate(x, y) {
            const distance = Math.abs(x - posX) + Math.abs(y - posY);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestX = x;
                bestY = y;
            }
        }

        for (const output of visibleOutputs) {
            if (output.name === testName)
                continue;
            const draft = draftFor(output.name);
            const size = logicalSize(output);
            const x = Number(draft.x || 0);
            const y = Number(draft.y || 0);
            candidate(x + size.w, y);
            candidate(x - testW, y);
            candidate(x, y + size.h);
            candidate(x, y - testH);
            candidate(x + size.w, y + size.h - testH);
            candidate(x - testW, y + size.h - testH);
        }

        return Qt.point(bestX, bestY);
    }

    function outputChanged(output) {
        const draft = draftFor(output.name);
        const base = makeDraft(output);
        return draft.mode !== base.mode
            || Number(draft.x) !== Number(base.x)
            || Number(draft.y) !== Number(base.y)
            || Math.abs(Number(draft.scale) - Number(base.scale)) > 0.001
            || Number(draft.transform) !== Number(base.transform)
            || Boolean(draft.disabled) !== Boolean(base.disabled);
    }

    function pendingOutputNames() {
        const names = [];
        for (const output of outputs) {
            if (outputChanged(output))
                names.push(output.name);
        }
        return names;
    }

    function resetDrafts() {
        const next = {};
        for (const output of outputs)
            next[output.name] = makeDraft(output);
        drafts = next;
        revision++;
    }

    function quote(value) {
        return String(value || "").replace(/'/g, "'\\''");
    }

    function monitorKeyword(output) {
        const draft = draftFor(output.name);
        if (draft.disabled)
            return `${output.name},disable`;
        const mode = String(draft.mode || "preferred").replace(/Hz$/i, "");
        return `${output.name},${mode},${Math.round(Number(draft.x || 0))}x${Math.round(Number(draft.y || 0))},${Number(draft.scale || 1).toFixed(2)},transform,${Number(draft.transform || 0)}`;
    }

    function applyOutput(name) {
        const output = outputByName(name);
        if (!output)
            return;
        applying = true;
        applyProc.command = ["bash", "-lc", `hyprctl keyword monitor '${quote(monitorKeyword(output))}'`];
        applyProc.running = true;
    }

    function applyAll() {
        const changed = pendingOutputNames();
        if (changed.length === 0)
            return;
        const commands = [];
        for (const name of changed) {
            const output = outputByName(name);
            if (output)
                commands.push(`hyprctl keyword monitor '${quote(monitorKeyword(output))}'`);
        }
        applying = true;
        applyProc.command = ["bash", "-lc", commands.join(" && ")];
        applyProc.running = true;
    }

    function identify() {
        Quickshell.execDetached(["bash", "-lc", "notify-send 'OMD Displays' \"$(hyprctl monitors | awk '/Monitor /{print $2; next} / at /{print; next} /description:/{print}')\""]);
    }

    function parseOutputs(text) {
        const raw = String(text || "").trim();
        if (raw.length === 0) {
            errorText = "hyprctl returned no monitor data.";
            return [];
        }
        if (!raw.startsWith("[") && !raw.startsWith("{")) {
            errorText = raw;
            return [];
        }
        try {
            const parsed = JSON.parse(raw);
            const list = Array.isArray(parsed) ? parsed : [];
            return list.map(item => {
                const modes = Array.isArray(item.availableModes) ? item.availableModes : [];
                const currentMode = `${item.width || 1920}x${item.height || 1080}@${Number(item.refreshRate || 60).toFixed(2)}Hz`;
                if (!modes.includes(currentMode))
                    modes.unshift(currentMode);
                return {
                    name: item.name || "unknown",
                    id: item.id || 0,
                    description: item.description || "",
                    make: item.make || "",
                    model: item.model || "",
                    serial: item.serial || "",
                    width: Number(item.width || 1920),
                    height: Number(item.height || 1080),
                    refreshRate: Number(item.refreshRate || 60),
                    currentMode,
                    modes,
                    x: Number(item.x || 0),
                    y: Number(item.y || 0),
                    scale: Number(item.scale || 1),
                    transform: Number(item.transform || 0),
                    focused: item.focused === true,
                    disabled: item.disabled === true,
                    connected: item.disabled !== true
                };
            }).sort((a, b) => a.x === b.x ? a.y - b.y : a.x - b.x);
        } catch (e) {
            errorText = `Failed to parse hyprctl monitors: ${e}`;
            return [];
        }
    }

    Process {
        id: monitorProc
        command: ["bash", "-lc", "hyprctl -j monitors all 2>/dev/null || hyprctl -j monitors 2>/dev/null"]
        stdout: StdioCollector {
            id: monitorCollector
            onStreamFinished: {
                root.outputs = root.parseOutputs(monitorCollector.text);
                root.resetDrafts();
                root.refreshing = false;
            }
        }
        stderr: StdioCollector {
            id: monitorErrCollector
            onStreamFinished: {
                if (monitorErrCollector.text.trim().length > 0)
                    root.errorText = monitorErrCollector.text.trim();
            }
        }
        onExited: (exitCode) => {
            root.refreshing = false;
            if (exitCode !== 0 && root.outputs.length === 0)
                root.errorText = "hyprctl monitors is not available in this session.";
        }
    }

    Process {
        id: applyProc
        command: ["true"]
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: applyErrCollector
            onStreamFinished: {
                if (applyErrCollector.text.trim().length > 0)
                    root.errorText = applyErrCollector.text.trim();
            }
        }
        onExited: (exitCode) => {
            root.applying = false;
            if (exitCode === 0) {
                root.applied("Display configuration applied");
                refreshDelay.restart();
            } else {
                root.errorText = "Failed to apply display configuration.";
            }
        }
    }

    Timer {
        id: refreshDelay
        interval: 450
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
