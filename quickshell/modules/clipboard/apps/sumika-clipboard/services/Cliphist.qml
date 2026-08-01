pragma Singleton
pragma ComponentBehavior: Bound

import "../modules/clipboard/widgets"
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string cliphistBinary: "cliphist"
    property string pasteCommand: "SUMIKA_PASTE_SOURCE=clipboard SUMIKA_PASTE_DELAY=0.05 sumika-paste-at-cursor"
    property string pasteHelper: "sumika-clipboard-paste"
    property int maxEntries: 40
    property list<string> entries: []
    property string lastPasteEntry: ""
    property double lastPasteAt: 0
    readonly property var reEntryPrefix: /^\s*\S+\s+/
    readonly property var reImageEntry: /^\d+\t\[\[.*binary data.*\]\]/i

    readonly property var reInvisibleChars: /[\s\u0000-\u001f\u007f-\u009f\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180f\u200b-\u200f\u202a-\u202e\u2060-\u206f\u2800\u3000\u3164\ufe00-\ufe0f\ufeff\uffa0]/g
    readonly property var reEntryNumber: /^(\d+)\t/
    readonly property var preparedEntries: entries.map(a => {
        const payload = a.replace(reEntryPrefix, "")
        // Image entries carry only binary metadata ("[[ binary data 29 KiB
        // png 1034x288 ]]"); indexing that would let digit queries like
        // "1234" match via the dimensions. Expose only the "image" keyword.
        const name = root.entryIsImage(a) ? "image" : payload
        return { name: Fuzzy.prepare(name), entry: a }
    })

    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => r.obj.entry);
    }

    function entryIsImage(entry) {
        return root.reImageEntry.test(`${entry ?? ""}`)
    }

    function entryPayload(entry) {
        return `${entry ?? ""}`.replace(root.reEntryPrefix, "")
    }

    function entryHasVisibleContent(entry) {
        if (entryIsImage(entry))
            return true
        return entryPayload(entry).replace(root.reInvisibleChars, "").length > 0
    }

    function filterEntries(values) {
        const seen = new Set()
        const filtered = []
        for (let i = 0; i < values.length; i++) {
            const entry = values[i]
            const payload = entryPayload(entry)
            if (!entryHasVisibleContent(entry)) continue
            if (payload.indexOf("/tmp/sumika-clip-") !== -1) continue
            // Filter stale probe strings left by external debugging sessions
            // (e.g. __sumika_clip_text_hold_...__). These are not real
            // clipboard content; they were written to the Wayland clipboard
            // by diagnostic tools and captured by the watcher. Drop them.
            if (payload.indexOf("__sumika_") !== -1) continue
            if (seen.has(payload)) continue
            seen.add(payload)
            filtered.push(entry)
            if (filtered.length >= root.maxEntries) break
        }
        return filtered
    }

    function refresh() {
        if (readProc.running) {
            readProc.refreshPending = true
            return
        }
        readProc.buffer = []
        readProc.running = true
    }

    // Remove decoded image cache files that are no longer referenced by
    // the current entry set (keeps only what cliphist list reports).
    function pruneImageCache() {
        if (root.entries.length === 0)
            return
        const referenced = new Set()
        for (let i = 0; i < root.entries.length; ++i) {
            if (root.entryIsImage(root.entries[i])) {
                const m = `${root.entries[i]}`.match(/^(\d+)\t/)
                if (m)
                    referenced.add(m[1])
            }
        }
        const dir = ClipboardStyle.cliphistDecode
        const keepPattern = [...referenced].join("|")
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p '${dir}'; for f in "${dir}"/*; do [ -f "$f" ] || continue; n=$(basename "$f"); if printf '%s\\n' "$n" | grep -Eq '^(${keepPattern})$'; then :; else rm -f "$f"; fi; done`])
    }

    function ensureLoaded() {
        root.refresh()
    }

    function setDialogVisible(visible: bool) {
        if (visible)
            root.ensureLoaded()
    }

    function claimPaste(entry) {
        const now = Date.now()
        if (entry === root.lastPasteEntry && now - root.lastPasteAt < 900)
            return false
        root.lastPasteEntry = entry
        root.lastPasteAt = now
        return true
    }

    function paste(entry) {
        if (!root.claimPaste(entry))
            return;
        Quickshell.execDetached(["bash", "-c", `payload=$(mktemp); trap 'rm -f "$payload"' EXIT; printf '${ClipboardStyle.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode > "$payload" && [ -s "$payload" ] && wl-copy < "$payload" && ${root.pasteCommand} --file "$payload" auto`]);
    }

    function pasteImagePath(entry) {
        if (!root.claimPaste(entry))
            return;
        Quickshell.execDetached([root.pasteHelper, "--entry", entry, "--path"]);
    }

    // Smart paste: like paste(), but when the entry is an image AND the
    // focused window is a terminal (kitty / alacritty / foot / wezterm / ...),
    // paste the image as a /tmp file PATH instead — terminals can't render
    // image data, but most CLI tools accept a path argument. So clicking an
    // image in the clipboard manager pastes it as a path in a terminal
    // without needing the dedicated "paste as path" (⇲) button.
    function pasteSmart(entry) {
        if (!root.entryIsImage(entry)) {
            root.paste(entry);
            return;
        }
        if (!root.claimPaste(entry))
            return;
        Quickshell.execDetached([root.pasteHelper, "--entry", entry, "--smart"]);
    }

    Process {
        id: deleteProc
        property string pendingEntry: ""
        property string pendingEntryNum: ""
        command: ["bash", "-c", `echo '${ClipboardStyle.shellSingleQuoteEscape(deleteProc.pendingEntry)}' | ${root.cliphistBinary} delete && rm -f '${ClipboardStyle.cliphistDecode}/${deleteProc.pendingEntryNum}'`]
        function deleteEntry(entry) {
            deleteProc.pendingEntry = entry;
            const match = root.reEntryNumber.exec(entry);
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
        command: ["bash", "-c", `${root.cliphistBinary} wipe && rm -rf '${ClipboardStyle.cliphistDecode}'/*`]
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function wipe() {
        wipeProc.running = true;
    }

    Process {
        id: readProc
        property list<string> buffer: []
        property bool refreshPending: false

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.entries = root.filterEntries(readProc.buffer)
                root.pruneImageCache()
            } else {
                console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
            if (readProc.refreshPending) {
                readProc.refreshPending = false
                Qt.callLater(() => root.refresh())
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
