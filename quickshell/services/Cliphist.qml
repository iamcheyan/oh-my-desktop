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
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property real scoreThreshold: 0.2
    property list<string> entries: []
    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))

    Component.onCompleted: {
        // Preload entries on shell startup so clipboard dialog opens instantly
        root.refresh();
    }
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

    function refresh() {
        readProc.buffer = []
        readProc.running = true
    }

    function precacheImages() {
        const imageEntries = entries.filter(e => entryIsImage(e));
        if (imageEntries.length === 0) return;
        // Batch all image decodes into a single process to avoid spawning many bash processes
        const commands = [];
        for (let i = 0; i < imageEntries.length; i++) {
            const entry = imageEntries[i];
            const match = entry.match(/^(\d+)\t/);
            if (!match) continue;
            const entryNum = match[1];
            const filePath = `${Directories.cliphistDecode}/${entryNum}`;
            const escapedEntry = StringUtils.shellSingleQuoteEscape(entry);
            // Skip if file exists and is a valid image, otherwise decode fresh
            commands.push(`file '${filePath}' | grep -qi 'image\\|png\\|jpeg\\|bmp\\|webp\\|gif' || printf '${escapedEntry}' | ${root.cliphistBinary} decode > '${filePath}'`);
        }
        if (commands.length > 0) {
            precacheProc.command = ["bash", "-c", commands.join(" & ")];
            precacheProc.running = true;
        }
    }

    Process {
        id: precacheProc
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
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && wl-paste`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy; ${root.pressPasteCommand}`]);
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
                root.entries = readProc.buffer
                root.precacheImages()
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
