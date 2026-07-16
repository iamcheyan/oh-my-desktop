pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property string cliphistBinary: "cliphist"
    property real pasteDelay: 0.05
    property string pressPasteCommand: "YDOTOOL_SOCKET=/tmp/.ydotool_socket ydotool key -d 1 29:1 47:1 47:0 29:0"
    property real scoreThreshold: 0.2
    property int maxEntries: 40
    property bool loaded: false
    property list<string> entries: []
    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))

    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function entryPayload(entry) {
        return `${entry ?? ""}`.replace(/^\s*\S+\s+/, "")
    }

    function entryHasVisibleContent(entry) {
        if (entryIsImage(entry))
            return true
        const invisible = /[\s\u0000-\u001f\u007f-\u009f\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180f\u200b-\u200f\u202a-\u202e\u2060-\u206f\u2800\u3000\u3164\ufe00-\ufe0f\ufeff\uffa0]/g
        return entryPayload(entry).replace(invisible, "").length > 0
    }

    function filterEntries(values) {
        const seen = new Set()
        const filtered = []
        for (let i = 0; i < values.length; i++) {
            const entry = values[i]
            const payload = entryPayload(entry)
            if (!entryHasVisibleContent(entry)) continue
            if (payload.indexOf("/tmp/omd-clip-") !== -1) continue
            if (seen.has(payload)) continue
            seen.add(payload)
            filtered.push(entry)
            if (filtered.length >= root.maxEntries) break
        }
        return filtered
    }

    function refresh() {
        root.loaded = true
        readProc.buffer = []
        readProc.running = true
    }

    function ensureLoaded() {
        root.refresh()
    }

    function setDialogVisible(visible: bool) {
        if (visible)
            root.ensureLoaded()
    }

    function copy(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy`]);
        }
    }

    function paste(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep 0.1 && ${root.pressPasteCommand}`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy && sleep 0.1 && ${root.pressPasteCommand}`]);
        }
    }

    // Save image entry to a /tmp file, copy its path (+ trailing space) to clipboard, then simulate paste
    function pasteImagePath(entry) {
        const ts = Date.now();
        const tmpPath = `/tmp/omd-clip-${ts}.png`;
        if (root.cliphistBinary.includes("cliphist"))
            Quickshell.execDetached(["bash", "-c",
                `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode > "${tmpPath}" && printf '%s ' "${tmpPath}" | wl-copy && sleep 0.1 && ${root.pressPasteCommand} && notify-send -t 2000 '📋 已复制路径' "${tmpPath}"`
            ]);
        else {
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c",
                `${root.cliphistBinary} decode ${entryNumber} > "${tmpPath}" && printf '%s ' "${tmpPath}" | wl-copy && sleep 0.1 && ${root.pressPasteCommand} && notify-send -t 2000 '📋 已复制路径' "${tmpPath}"`
            ]);
        }
    }

    function superpaste(count, isImage = false) {
        // Find entries
        const targetEntries = entries.filter(entry => {
            if (!isImage) return true;
            return entryIsImage(entry);
        }).slice(0, count)
        const pasteCommands = [...targetEntries].reverse().map(entry => `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep ${root.pasteDelay} && ${root.pressPasteCommand}`)
        // Act
        Quickshell.execDetached(["bash", "-c", pasteCommands.join(` && sleep ${root.pasteDelay} && `)]);
    }

    Process {
        id: deleteProc
        property string pendingEntry: ""
        property string pendingEntryNum: ""
        command: ["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(deleteProc.pendingEntry)}' | ${root.cliphistBinary} delete && rm -f '${Directories.cliphistDecode}/${deleteProc.pendingEntryNum}'`]
        function deleteEntry(entry) {
            deleteProc.pendingEntry = entry;
            const match = entry.match(/^(\d+)\t/);
            deleteProc.pendingEntryNum = match ? match[1] : "";
            deleteProc.running = true;
        }
        onExited: (exitCode, exitStatus) => {
            deleteProc.pendingEntry = "";
            deleteProc.pendingEntryNum = "";
            root.refresh();
        }
    }

    function deleteEntry(entry) {
        deleteProc.deleteEntry(entry);
    }

    Process {
        id: wipeProc
        command: ["bash", "-c", `${root.cliphistBinary} wipe && rm -rf '${Directories.cliphistDecode}'/*`]
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function wipe() {
        wipeProc.running = true;
    }

    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            delayedUpdateTimer.restart()
        }
    }

    Timer {
        id: delayedUpdateTimer
        interval: Config.options.hacks.arbitraryRaceConditionDelay
        repeat: false
        onTriggered: {
            root.refresh()
        }
    }

    Process {
        id: readProc
        property list<string> buffer: []

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.entries = root.filterEntries(readProc.buffer)
            } else {
                console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
        }
    }

    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }
}
