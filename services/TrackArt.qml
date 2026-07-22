pragma Singleton
pragma ComponentBehavior: Bound

// Artwork resolution and caching adapted from DankMaterialShell's
// Services/TrackArtService.qml.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string cacheDir: FileUtils.trimFileProtocol(
        `${Directories.genericCache}/omd/media-art`)
    property MprisPlayer activePlayer: MprisController.activePlayer
    property string requestedUrl: ""
    property string resolvedArtUrl: ""
    property string processUrl: ""
    property string processPath: ""
    property bool loading: false

    function djb2Hash(value) {
        if (!value)
            return "";
        let hash = 5381;
        for (let i = 0; i < value.length; i++) {
            hash = ((hash << 5) + hash) + value.charCodeAt(i);
            hash &= 0x7fffffff;
        }
        return hash.toString(16).padStart(8, "0");
    }

    function artworkUrl(player) {
        if (!player)
            return "";

        let url = player.trackArtUrl || "";
        if (url.length > 0)
            return url;

        url = (player.metadata?.["mpris:artUrl"] || "").toString();
        if (url.length > 0)
            return url;

        const pageUrl = (player.metadata?.["xesam:url"] || "").toString();
        if (pageUrl.includes("youtube.com") || pageUrl.includes("youtu.be")) {
            const match = pageUrl.match(/^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=)([^#&?]*).*/);
            if (match && match[2].length === 11)
                return `https://img.youtube.com/vi/${match[2]}/hqdefault.jpg`;
        }

        return "";
    }

    function updateArtwork() {
        const url = root.artworkUrl(root.activePlayer);
        if (url === root.requestedUrl)
            return;

        root.requestedUrl = url;
        root.resolvedArtUrl = "";
        if (!url) {
            root.loading = false;
            return;
        }

        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            root.resolvedArtUrl = url;
            root.loading = false;
            return;
        }

        root.loading = true;
        if (!artProcess.running)
            root.startDownload();
    }

    function startDownload() {
        if (!root.requestedUrl) {
            root.loading = false;
            return;
        }
        root.processUrl = root.requestedUrl;
        root.processPath = `${root.cacheDir}/remote_${root.djb2Hash(root.processUrl)}`;
        const youtube = root.processUrl.includes("img.youtube.com/vi/") ? "1" : "0";
        const script = [
            "set -eu",
            "dest=\"$1\"",
            "url=\"$2\"",
            "youtube=\"$3\"",
            "mkdir -p \"$(dirname \"$dest\")\"",
            "if [ -s \"$dest\" ]; then exit 0; fi",
            "tmp=\"${dest}.tmp.$$\"",
            "trap 'rm -f \"$tmp\"' EXIT",
            "if [ \"$youtube\" = 1 ]; then",
            "    video_id=\"${url#*/vi/}\"",
            "    video_id=\"${video_id%%/*}\"",
            "    curl -fLsS -o \"$tmp\" \"https://img.youtube.com/vi/$video_id/maxresdefault.jpg\" \\",
            "        || curl -fLsS -o \"$tmp\" \"https://img.youtube.com/vi/$video_id/mqdefault.jpg\"",
            "else",
            "    curl -fLsS -o \"$tmp\" \"$url\"",
            "fi",
            "mv \"$tmp\" \"$dest\""
        ].join("\n");
        artProcess.command = [
            "bash", "-c", script,
            "bash", root.processPath, root.processUrl, youtube
        ];
        artProcess.running = true;
    }

    onActivePlayerChanged: root.updateArtwork()

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged(): void { root.updateArtwork(); }
        function onTrackArtUrlChanged(): void { root.updateArtwork(); }
        function onMetadataChanged(): void { root.updateArtwork(); }
    }

    Process {
        id: artProcess
        running: false

        onExited: exitCode => {
            if (root.processUrl === root.requestedUrl) {
                root.resolvedArtUrl = exitCode === 0
                    ? `file://${root.processPath}`
                    : root.processUrl;
                root.loading = false;
            }
            if (root.processUrl !== root.requestedUrl)
                Qt.callLater(() => root.startDownload());
        }
    }

    Component.onCompleted: root.updateArtwork()
}
