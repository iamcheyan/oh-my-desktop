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
    property bool identifying: false
    property bool userEdited: false
    property int revision: 0

    readonly property var visibleOutputs: (revision, outputs.filter(output => output.connected !== false && !draftFor(output.name).disabled))
    readonly property bool hasPendingChanges: userEdited

    signal applied(string message)

    function refresh() {
        if (refreshing)
            return;
        refreshing = true;
        errorText = "";
        monitorProc.running = true;
    }

    function normalizeMode(mode, output) {
        if (!mode || String(mode).trim().length === 0)
            return `${output.width}x${output.height}@${Number(output.refreshRate || 60).toFixed(3)}Hz`;
        const parsed = parseMode(mode);
        if (!parsed)
            return String(mode).trim().replace(/\s+/g, "");
        // Preserve the compositor's millihertz precision for apply requests.
        // The visible label remains rounded by formatModeLabel().
        return `${parsed.w}x${parsed.h}@${Number(parsed.hz).toFixed(3)}Hz`;
    }

    function formatModeLabel(mode) {
        const parsed = parseMode(mode);
        if (!parsed)
            return mode || "Auto";
        const warning = parsed.hz < 50 ? " - low refresh" : "";
        return `${parsed.w} x ${parsed.h} @ ${Math.round(parsed.hz)}Hz${warning}`;
    }

    function parseMode(mode) {
        const match = String(mode || "").match(/(\d+)\s*x\s*(\d+)\s*@\s*([\d.]+)\s*(?:Hz)?/i);
        if (!match)
            return null;
        return {
            w: parseInt(match[1]),
            h: parseInt(match[2]),
            hz: parseFloat(match[3])
        };
    }

    function modeIsLowRefresh(mode) {
        const parsed = parseMode(mode);
        return parsed ? parsed.hz < 50 : false;
    }

    function sortedModes(modes, currentMode) {
        const seen = {};
        const unique = [];
        const source = [];
        if (currentMode && String(currentMode).length > 0)
            source.push(currentMode);
        for (const mode of modes || [])
            source.push(mode);

        for (const mode of source) {
            const normalized = normalizeMode(mode, { width: 1920, height: 1080, refreshRate: 60 });
            if (seen[normalized])
                continue;
            seen[normalized] = true;
            unique.push(normalized);
        }

        return unique.sort((left, right) => {
            const a = parseMode(left);
            const b = parseMode(right);
            if (!a || !b)
                return String(left).localeCompare(String(right));

            const areaDiff = (b.w * b.h) - (a.w * a.h);
            if (areaDiff !== 0)
                return areaDiff;

            const hzDiff = b.hz - a.hz;
            if (Math.abs(hzDiff) > 0.5)
                return hzDiff;

            return b.hz - a.hz;
        });
    }

    function scaleLabel(scale) {
        const value = Number(scale || 1);
        return `${Math.round(value * 100)}%`;
    }

    function scaleChoices(currentScale) {
        const choices = [];
        for (let percentage = 100; percentage <= 400; percentage += 25)
            choices.push(percentage / 100);
        return choices;
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
        const actualScale = Number(output.scale || 1);
        const savedPreset = Number(output.scalePreset);
        return {
            name: output.name,
            mode: normalizeMode(output.currentMode, output),
            x: Number(output.x || 0),
            y: Number(output.y || 0),
            scale: actualScale,
            // Keep the user-facing 25% preset separate from the clean scale
            // that Hyprland can actually apply for this output mode.
            scalePreset: Number.isFinite(savedPreset)
                ? savedPreset
                : Math.max(1, Math.min(4, Math.round(actualScale * 4) / 4)),
            transform: Number(output.transform || 0),
            disabled: output.disabled === true
        };
    }

    function setScalePreset(name, preset, effectiveScale) {
        const next = Object.assign({}, drafts);
        const draft = Object.assign({}, draftFor(name));
        draft.scalePreset = Number(preset);
        draft.scale = Number(effectiveScale);
        next[name] = draft;
        drafts = next;
        userEdited = true;
        revision++;
        normalizeLayout(name);
    }

    function setDraftValue(name, key, value) {
        const next = Object.assign({}, drafts);
        const draft = Object.assign({}, draftFor(name));
        draft[key] = value;
        next[name] = draft;
        drafts = next;
        userEdited = true;
        revision++;
        if (["mode", "scale", "transform", "disabled", "x", "y"].includes(key))
            normalizeLayout(name);
    }

    function updatePosition(name, x, y) {
        const next = Object.assign({}, drafts);
        const draft = Object.assign({}, draftFor(name));
        draft.x = Math.round(x);
        draft.y = Math.round(y);
        next[name] = draft;
        drafts = next;
        userEdited = true;
        revision++;
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
            // Match Hyprland's CMonitor::m_size calculation exactly.
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

    function rectanglesOverlap(left, right) {
        return left.x < right.x + right.w
            && left.x + left.w > right.x
            && left.y < right.y + right.h
            && left.y + left.h > right.y;
    }

    function checkOverlap(testName, testX, testY, testW, testH) {
        const test = { x: testX, y: testY, w: testW, h: testH };
        for (const output of visibleOutputs) {
            if (output.name === testName)
                continue;
            const draft = draftFor(output.name);
            const size = logicalSize(output);
            const other = { x: Number(draft.x || 0), y: Number(draft.y || 0), w: size.w, h: size.h };
            if (rectanglesOverlap(test, other))
                return true;
        }
        return false;
    }

    function attachmentCandidates(testRect, referenceRect) {
        function clamp(value, minimum, maximum) {
            return Math.max(minimum, Math.min(maximum, value));
        }

        function alignments(raw, referenceStart, referenceLength, testLength) {
            const minimum = referenceStart - testLength + 1;
            const maximum = referenceStart + referenceLength - 1;
            return [
                Math.round(clamp(raw, minimum, maximum)),
                Math.round(referenceStart),
                Math.round(referenceStart + referenceLength - testLength),
                Math.round(referenceStart + (referenceLength - testLength) / 2)
            ];
        }

        const result = [];
        const seen = {};
        function add(x, y) {
            const key = `${Math.round(x)},${Math.round(y)}`;
            if (seen[key])
                return;
            seen[key] = true;
            result.push({ x: Math.round(x), y: Math.round(y), w: testRect.w, h: testRect.h });
        }

        for (const y of alignments(testRect.y, referenceRect.y, referenceRect.h, testRect.h)) {
            add(referenceRect.x - testRect.w, y);
            add(referenceRect.x + referenceRect.w, y);
        }
        for (const x of alignments(testRect.x, referenceRect.x, referenceRect.w, testRect.w)) {
            add(x, referenceRect.y - testRect.h);
            add(x, referenceRect.y + referenceRect.h);
        }
        return result;
    }

    function snapToEdges(testName, posX, posY, testW, testH) {
        const test = { x: posX, y: posY, w: testW, h: testH };
        const others = [];
        for (const output of visibleOutputs) {
            if (output.name === testName)
                continue;
            const draft = draftFor(output.name);
            const size = logicalSize(output);
            others.push({
                name: output.name,
                x: Number(draft.x || 0),
                y: Number(draft.y || 0),
                w: size.w,
                h: size.h
            });
        }

        let best = null;
        let bestDistance = Infinity;
        for (const reference of others) {
            for (const candidate of attachmentCandidates(test, reference)) {
                let overlaps = false;
                for (const other of others) {
                    if (rectanglesOverlap(candidate, other)) {
                        overlaps = true;
                        break;
                    }
                }
                if (overlaps)
                    continue;
                const dx = candidate.x - posX;
                const dy = candidate.y - posY;
                const distance = dx * dx + dy * dy;
                if (distance < bestDistance) {
                    bestDistance = distance;
                    best = candidate;
                }
            }
        }
        return best ? Qt.point(best.x, best.y) : Qt.point(posX, posY);
    }

    function normalizeLayout(anchorName) {
        const active = visibleOutputs.slice();
        if (active.length < 2)
            return;

        let anchor = active.find(output => output.name === anchorName);
        if (!anchor)
            anchor = active.find(output => output.focused) || active[0];

        const positions = {};
        const anchorDraft = draftFor(anchor.name);
        const anchorSize = logicalSize(anchor);
        positions[anchor.name] = {
            name: anchor.name,
            x: Number(anchorDraft.x || 0),
            y: Number(anchorDraft.y || 0),
            w: anchorSize.w,
            h: anchorSize.h
        };

        const placed = [anchor.name];
        const remaining = active.filter(output => output.name !== anchor.name);
        while (remaining.length > 0) {
            let best = null;
            let bestDistance = Infinity;

            for (let outputIndex = 0; outputIndex < remaining.length; outputIndex++) {
                const output = remaining[outputIndex];
                const draft = draftFor(output.name);
                const size = logicalSize(output);
                const original = {
                    x: Number(draft.x || 0),
                    y: Number(draft.y || 0),
                    w: size.w,
                    h: size.h
                };

                for (const referenceName of placed) {
                    const reference = positions[referenceName];
                    for (const candidate of attachmentCandidates(original, reference)) {
                        let overlaps = false;
                        for (const placedName of placed) {
                            if (rectanglesOverlap(candidate, positions[placedName])) {
                                overlaps = true;
                                break;
                            }
                        }
                        if (overlaps)
                            continue;
                        const dx = candidate.x - original.x;
                        const dy = candidate.y - original.y;
                        const distance = dx * dx + dy * dy;
                        if (distance < bestDistance) {
                            bestDistance = distance;
                            best = { outputIndex, output, candidate };
                        }
                    }
                }
            }

            if (!best)
                break;
            positions[best.output.name] = Object.assign({ name: best.output.name }, best.candidate);
            placed.push(best.output.name);
            remaining.splice(best.outputIndex, 1);
        }

        if (placed.length !== active.length)
            return;
        const next = Object.assign({}, drafts);
        for (const name of placed) {
            const draft = Object.assign({}, next[name] || draftFor(name));
            draft.x = Math.round(positions[name].x);
            draft.y = Math.round(positions[name].y);
            next[name] = draft;
        }
        drafts = next;
        revision++;
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
        userEdited = false;
        revision++;
        const focused = outputs.find(output => output.focused);
        normalizeLayout(focused ? focused.name : (outputs[0] ? outputs[0].name : ""));
    }

    function monitorSpec(output) {
        const draft = draftFor(output.name);
        return {
            output: output.name,
            mode: String(draft.mode || "preferred").replace(/Hz$/i, ""),
            x: Math.round(Number(draft.x || 0)),
            y: Math.round(Number(draft.y || 0)),
            scale: Number(draft.scale || 1),
            scalePreset: Number(draft.scalePreset || draft.scale || 1),
            transform: Number(draft.transform || 0),
            disabled: Boolean(draft.disabled)
        };
    }

    function monitorSpecs() {
        const specs = [];
        for (const output of outputs)
            specs.push(monitorSpec(output));
        return specs;
    }

    function acceptAppliedDrafts() {
        outputs = outputs.map(output => {
            const draft = draftFor(output.name);
            const mode = parseMode(draft.mode);
            return Object.assign({}, output, {
                currentMode: normalizeMode(draft.mode, output),
                width: mode ? mode.w : output.width,
                height: mode ? mode.h : output.height,
                refreshRate: mode ? mode.hz : output.refreshRate,
                x: Math.round(Number(draft.x || 0)),
                y: Math.round(Number(draft.y || 0)),
                scale: Number(draft.scale || 1),
                scalePreset: Number(draft.scalePreset || draft.scale || 1),
                transform: Number(draft.transform || 0),
                disabled: Boolean(draft.disabled),
                connected: !Boolean(draft.disabled)
            });
        });
        revision++;
    }

    function applyCommand() {
        return [
            Quickshell.env("HOME") + "/.config/omd/bin/omd-display-config",
            "apply",
            JSON.stringify(monitorSpecs())
        ];
    }

    function applyOutput(name) {
        const output = outputByName(name);
        if (!output)
            return;
        applying = true;
        errorText = "";
        applyProc.command = applyCommand();
        applyProc.running = true;
    }

    function applyAll() {
        if (!userEdited)
            return;
        const changed = pendingOutputNames();
        const focused = outputs.find(output => output.focused);
        normalizeLayout(changed.length > 0 ? changed[0] : (focused ? focused.name : ""));
        applying = true;
        errorText = "";
        applyProc.command = applyCommand();
        applyProc.running = true;
    }

    function identify() {
        identifying = true;
        identifyTimer.restart();
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
                // omd-display-config exposes wlr-output-management data as
                // `currentMode`/`modes`. Keep the Hyprland field as a fallback
                // so this adapter also accepts direct hyprctl monitor data.
                const fallbackMode = `${item.width || 1920}x${item.height || 1080}@${Number(item.refreshRate || 60).toFixed(3)}Hz`;
                const currentMode = normalizeMode(item.currentMode || fallbackMode, item);
                const advertisedModes = Array.isArray(item.modes)
                    ? item.modes
                    : (Array.isArray(item.availableModes) ? item.availableModes : []);
                const modes = sortedModes(advertisedModes, currentMode);
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
                    scalePreset: Number(item.scalePreset || item.scale || 1),
                    transform: Number(item.transform || 0),
                    focused: item.focused === true,
                    disabled: item.disabled === true,
                    connected: item.disabled !== true
                };
            }).sort((a, b) => a.x === b.x ? a.y - b.y : a.x - b.x);
        } catch (e) {
            errorText = `Failed to parse display data: ${e}`;
            return [];
        }
    }

    Process {
        id: monitorProc
        command: [Quickshell.env("HOME") + "/.config/omd/bin/omd-display-config", "get"]
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
                root.errorText = "Display management is not available in this session.";
        }
    }

    Process {
        id: applyProc
        command: ["true"]
        stdout: StdioCollector {
            id: applyOutCollector
        }
        stderr: StdioCollector {
            id: applyErrCollector
            onStreamFinished: {
                if (applyErrCollector.text.trim().length > 0)
                    root.errorText = applyErrCollector.text.trim();
            }
        }
        onExited: (exitCode) => {
            root.applying = false;
            const stdoutText = applyOutCollector.text.trim();
            const stdoutLines = stdoutText.split(/\n+/).map(line => line.trim()).filter(line => line.length > 0);
            const stdoutOk = stdoutLines.length === 0 || stdoutLines.every(line => line === "ok");
            if (!stdoutOk)
                root.errorText = stdoutText;
            if (exitCode === 0 && root.errorText.length === 0) {
                // The backend verifies every requested value before exiting,
                // so the applied drafts are now the comparison baseline.
                root.acceptAppliedDrafts();
                root.userEdited = false;
                root.applied("Display configuration applied");
                refreshDelay.restart();
                reloadShellDelay.restart();
            } else {
                if (root.errorText.length === 0)
                    root.errorText = "Failed to apply display configuration.";
            }
        }
    }

    Timer {
        id: identifyTimer
        interval: 3200
        repeat: false
        onTriggered: root.identifying = false
    }

    Timer {
        id: refreshDelay
        interval: 450
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: reloadShellDelay
        interval: 900
        repeat: false
        onTriggered: Quickshell.execDetached([
            "/bin/sh",
            Quickshell.env("HOME") + "/.config/omd/scripts/reload-quickshell",
            "--quickshell-only"
        ])
    }

    Component.onCompleted: refresh()
}
