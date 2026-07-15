pragma Singleton
pragma ComponentBehavior: Bound

// From https://git.outfoxxed.me/outfoxxed/nixnew (redistribution OK)
// Extended for reliable browser media control + state sync in the bar popup.

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * Active MPRIS player helper.
 *
 * Browser media often appears twice (native Firefox/Chromium bus +
 * plasma-browser-integration). Controlling the wrong one makes play/pause
 * appear broken and state fail to track the tab. We prefer the native
 * browser bus for control, keep plasma only as fallback, and poll
 * playback state so the UI stays in sync with in-page controls.
 */
Singleton {
    id: root

    property MprisPlayer trackedPlayer: null
    property var activeTrack
    signal trackChanged(reverse: bool)
    property bool __reverse: false

    // Polled mirror of playback — bindings to player.isPlaying alone often
    // lag or miss D-Bus updates from browsers.
    property bool displayPlaying: false
    property string displayTitle: ""
    property string displayArtist: ""
    property string displayPlayerName: ""

    readonly property list<MprisPlayer> allPlayers: Mpris.players.values
    readonly property list<MprisPlayer> players: Mpris.players.values.filter(p => root.isListedPlayer(p))
    readonly property MprisPlayer activePlayer: trackedPlayer ?? (players.length > 0 ? players[0] : null)

    function isPlayerctld(player) {
        return (player?.dbusName || "").startsWith("org.mpris.MediaPlayer2.playerctld")
    }

    function isPlasmaBrowser(player) {
        return (player?.dbusName || "").startsWith("org.mpris.MediaPlayer2.plasma-browser-integration")
    }

    function isNativeBrowser(player) {
        const n = player?.dbusName || ""
        return n.startsWith("org.mpris.MediaPlayer2.firefox")
            || n.startsWith("org.mpris.MediaPlayer2.chromium")
            || n.startsWith("org.mpris.MediaPlayer2.chrome")
            || n.startsWith("org.mpris.MediaPlayer2.brave")
            || n.startsWith("org.mpris.MediaPlayer2.vivaldi")
            || n.startsWith("org.mpris.MediaPlayer2.microsoft-edge")
    }

    // Shown in UI lists / selection (drop playerctld only).
    function isListedPlayer(player) {
        if (!player)
            return false
        if (root.isPlayerctld(player))
            return false
        // Prefer hiding plasma duplicate when a native browser bus exists.
        if (root.isPlasmaBrowser(player) && root.allPlayers.some(p => root.isNativeBrowser(p)))
            return false
        return true
    }

    function playerRank(player) {
        if (!player)
            return -1000
        let score = 0
        if (player.isPlaying)
            score += 200
        // Native browser control is far more reliable than plasma mirror.
        if (root.isNativeBrowser(player))
            score += 80
        if (root.isPlasmaBrowser(player))
            score += 20
        if ((player.trackTitle || "").length > 0)
            score += 10
        if ((player.trackArtUrl || "").length > 0)
            score += 5
        if (player.canControl)
            score += 5
        return score
    }

    function pickBestPlayer() {
        const list = root.allPlayers.filter(p => p && !root.isPlayerctld(p))
        if (list.length === 0)
            return null
        let best = list[0]
        let bestScore = root.playerRank(best)
        for (let i = 1; i < list.length; i++) {
            const s = root.playerRank(list[i])
            if (s > bestScore) {
                best = list[i]
                bestScore = s
            }
        }
        return best
    }

    function ensureTrackedPlayer() {
        const best = root.pickBestPlayer()
        if (!best) {
            if (root.trackedPlayer !== null)
                root.trackedPlayer = null
            return
        }
        // Always follow a currently-playing player if ours is idle.
        if (!root.trackedPlayer) {
            root.trackedPlayer = best
            return
        }
        // Drop dead / playerctld refs.
        if (root.isPlayerctld(root.trackedPlayer)) {
            root.trackedPlayer = best
            return
        }
        const cur = root.playerRank(root.trackedPlayer)
        const nxt = root.playerRank(best)
        if (best !== root.trackedPlayer && nxt > cur)
            root.trackedPlayer = best
    }

    function playerIdentity(player) {
        if (!player)
            return ""
        const id = player.identity || player.desktopEntry || ""
        if (id.length > 0)
            return id
        return (player.dbusName || "").replace("org.mpris.MediaPlayer2.", "")
    }

    function refreshDisplay() {
        root.ensureTrackedPlayer()
        const p = root.activePlayer
        root.displayPlaying = !!(p && p.isPlaying)
        const rawTitle = p?.trackTitle || ""
        root.displayTitle = rawTitle.length > 0 ? rawTitle : ""
        const artist = p?.trackArtist || ""
        root.displayArtist = (artist.length > 0 && artist !== "Unknown Artist") ? artist : ""
        root.displayPlayerName = root.playerIdentity(p)
        if (p)
            root.updateTrack()
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: root.refreshDisplay()
            Component.onDestruction: root.refreshDisplay()

            function onIsPlayingChanged() {
                if (modelData.isPlaying && !root.isPlayerctld(modelData))
                    root.trackedPlayer = modelData
                root.refreshDisplay()
            }
            function onPlaybackStateChanged() {
                if (modelData.isPlaying && !root.isPlayerctld(modelData))
                    root.trackedPlayer = modelData
                root.refreshDisplay()
            }
            function onTrackTitleChanged() { root.refreshDisplay() }
            function onTrackArtistChanged() { root.refreshDisplay() }
            function onTrackArtUrlChanged() { root.refreshDisplay() }
            function onMetadataChanged() { root.refreshDisplay() }
        }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onIsPlayingChanged() { root.refreshDisplay() }
        function onPlaybackStateChanged() { root.refreshDisplay() }
        function onTrackTitleChanged() { root.refreshDisplay() }
        function onPostTrackChanged() { root.refreshDisplay() }
    }

    onActivePlayerChanged: root.refreshDisplay()

    // Browsers often omit PropertyChanged for PlaybackStatus; poll as backup.
    Timer {
        interval: 400
        repeat: true
        running: true
        onTriggered: root.refreshDisplay()
    }

    function updateTrack() {
        const p = root.activePlayer
        root.activeTrack = {
            uniqueId: p?.uniqueId ?? 0,
            artUrl: p?.trackArtUrl ?? "",
            title: p?.trackTitle || "",
            artist: p?.trackArtist || "",
            album: p?.trackAlbum || "",
        }
        root.trackChanged(root.__reverse)
        root.__reverse = false
    }

    property bool isPlaying: root.displayPlaying
    property bool canTogglePlaying: {
        const p = root.activePlayer
        if (!p)
            return false
        return !!(p.canTogglePlaying || p.canPlay || p.canPause || p.canControl)
    }

    /**
     * Play/pause the real controlling player. For browser media, hit both the
     * native bus and plasma-browser-integration so UI + tab stay consistent.
     */
    function togglePlaying() {
        root.ensureTrackedPlayer()
        const primary = root.activePlayer
        if (!primary)
            return

        const wantPause = !!primary.isPlaying

        // Collect related players: primary + browser mirrors.
        const targets = []
        const pushUnique = (p) => {
            if (!p || targets.indexOf(p) >= 0)
                return
            targets.push(p)
        }
        pushUnique(primary)
        for (const p of root.allPlayers) {
            if (root.isPlayerctld(p))
                continue
            if (root.isNativeBrowser(p) || root.isPlasmaBrowser(p))
                pushUnique(p)
        }

        for (const p of targets) {
            try {
                if (wantPause) {
                    if (p.canPause)
                        p.pause()
                    else if (p.canTogglePlaying)
                        p.togglePlaying()
                    else
                        p.isPlaying = false
                } else {
                    if (p.canPlay)
                        p.play()
                    else if (p.canTogglePlaying)
                        p.togglePlaying()
                    else
                        p.isPlaying = true
                }
            } catch (e) {
                // keep going on other targets
            }
        }

        // Optimistic UI; poll will correct within 400ms.
        root.displayPlaying = !wantPause

        // Fallback: playerctl, if Quickshell calls no-op on this player.
        fallbackPlayerctl.command = [
            "bash", "-c",
            wantPause
                ? "playerctl pause 2>/dev/null || true"
                : "playerctl play 2>/dev/null || true"
        ]
        fallbackPlayerctl.running = true
    }

    Process {
        id: fallbackPlayerctl
        running: false
        onExited: root.refreshDisplay()
    }

    property bool canGoPrevious: root.activePlayer?.canGoPrevious ?? false
    function previous() {
        const p = root.activePlayer
        if (p?.canGoPrevious)
            p.previous()
        else
            Quickshell.execDetached(["bash", "-c", "playerctl previous 2>/dev/null || true"])
        root.refreshDisplay()
    }

    property bool canGoNext: root.activePlayer?.canGoNext ?? false
    function next() {
        const p = root.activePlayer
        if (p?.canGoNext)
            p.next()
        else
            Quickshell.execDetached(["bash", "-c", "playerctl next 2>/dev/null || true"])
        root.refreshDisplay()
    }

    property bool canSeek: !!(root.activePlayer?.canSeek)
    function seekToRatio(ratio) {
        // Seek removed from UI; keep API for callers.
        const p = root.activePlayer
        if (!p)
            return false
        const len = Number(p.length) || 0
        if (len <= 0)
            return false
        const r = Math.max(0, Math.min(1, Number(ratio) || 0))
        const target = r * (len > 86400 ? len / 1000000 : len)
        try {
            p.position = target
            return true
        } catch (e) {
            return false
        }
    }

    property bool canChangeVolume: root.activePlayer && root.activePlayer.volumeSupported && root.activePlayer.canControl
    property bool loopSupported: root.activePlayer && root.activePlayer.loopSupported && root.activePlayer.canControl
    property var loopState: root.activePlayer?.loopState ?? MprisLoopState.None
    function setLoopState(loopState: var) {
        if (root.loopSupported)
            root.activePlayer.loopState = loopState
    }
    property bool shuffleSupported: root.activePlayer && root.activePlayer.shuffleSupported && root.activePlayer.canControl
    property bool hasShuffle: root.activePlayer?.shuffle ?? false
    function setShuffle(shuffle: bool) {
        if (root.shuffleSupported)
            root.activePlayer.shuffle = shuffle
    }

    function setActivePlayer(player: MprisPlayer) {
        root.trackedPlayer = player ?? root.pickBestPlayer()
        root.refreshDisplay()
    }

    Component.onCompleted: root.refreshDisplay()

    IpcHandler {
        target: "mpris"
        function pauseAll(): void {
            for (const player of Mpris.players.values) {
                if (player.canPause)
                    player.pause()
            }
            root.refreshDisplay()
        }
        function playPause(): void { root.togglePlaying() }
        function previous(): void { root.previous() }
        function next(): void { root.next() }
    }
}
