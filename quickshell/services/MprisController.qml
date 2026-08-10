pragma Singleton
pragma ComponentBehavior: Bound

// Active-player lifecycle adapted from DankMaterialShell's
// quickshell/Services/MprisController.qml.

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> availablePlayers: Mpris.players.values

    property MprisPlayer activePlayer: null
    property real activePlayerStableLength: 0

    Connections {
        target: root.activePlayer

        function onTrackTitleChanged(): void {
            root.activePlayerStableLength = root.stableLength(root.activePlayer);
            root.resolveActivePlayer();
        }

        function onTrackArtistChanged(): void {
            root.resolveActivePlayer();
        }

        function onLengthChanged(): void {
            const length = root.stableLength(root.activePlayer);
            if (length > 0)
                root.activePlayerStableLength = length;
        }

        function onPlaybackStateChanged(): void {
            root.resolveActivePlayer();
        }
    }

    onActivePlayerChanged: {
        root.activePlayerStableLength = root.stableLength(root.activePlayer);
    }

    onAvailablePlayersChanged: root.resolveActivePlayer()
    Component.onCompleted: root.resolveActivePlayer()

    Instantiator {
        model: root.availablePlayers

        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onDestruction: root.resolveActivePlayer()

            function onIsPlayingChanged(): void {
                root.resolveActivePlayer();
            }

            function onPlaybackStateChanged(): void {
                root.resolveActivePlayer();
            }
        }
    }

    function stableLength(player: MprisPlayer): real {
        return player && player.lengthSupported && player.length > 1
            ? player.length
            : 0;
    }

    // Sumika's compact player has no stopped-state controls. A stopped session is
    // therefore unavailable even if a browser retains old metadata.
    function isIdle(player: MprisPlayer): bool {
        return !player || player.playbackState === MprisPlaybackState.Stopped;
    }

    function isFirefoxYoutubeHoverPreview(player: MprisPlayer): bool {
        if (!player)
            return false;
        const identity = (player.identity || "").toLowerCase();
        if (!identity.includes("firefox"))
            return false;
        const url = (player.metadata?.["xesam:url"] || "").toString();
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url);
    }

    function isUsable(player: MprisPlayer): bool {
        return !!player
            && !root.isIdle(player)
            && !root.isFirefoxYoutubeHoverPreview(player);
    }

    function resolveActivePlayer(): void {
        // Match DankMaterialShell: a genuinely playing session always wins.
        const playing = root.availablePlayers.find(player =>
            player.isPlaying && !root.isFirefoxYoutubeHoverPreview(player));
        if (playing) {
            if (root.activePlayer !== playing)
                root.activePlayer = playing;
            return;
        }

        // Paused media stays selected so the same player can be resumed.
        if (root.activePlayer
                && root.availablePlayers.indexOf(root.activePlayer) >= 0
                && root.isUsable(root.activePlayer))
            return;

        // If the active session stopped or disappeared, fall back only to a
        // paused, controllable session. Otherwise the media strip is removed.
        const paused = root.availablePlayers.find(player =>
            player.playbackState === MprisPlaybackState.Paused
                && player.canControl
                && !root.isFirefoxYoutubeHoverPreview(player));
        root.activePlayer = paused ?? null;
    }

    function setActivePlayer(player: MprisPlayer): void {
        root.activePlayer = root.isUsable(player) ? player : null;
    }

    function playerIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        return player.identity
            || player.desktopEntry
            || (player.dbusName || "").replace("org.mpris.MediaPlayer2.", "");
    }

    function togglePlaying(): void {
        // Deliberately call the selected MPRIS object directly, matching DMS.
        // Do not broadcast to mirrors and do not mutate UI state optimistically.
        root.activePlayer?.togglePlaying();
    }

    function raiseActivePlayer(): void {
        if (!root.activePlayer)
            return;
        if (root.activePlayer.canRaise) {
            root.activePlayer.raise();
            return;
        }

        // Some browser MPRIS implementations do not advertise Raise even
        // though their window is present. Focus it through Hyprland without
        // launching a second instance.
        const pattern = root.activePlayer.desktopEntry
            || root.activePlayer.identity
            || "";
        if (pattern.length > 0)
            Quickshell.execDetached(["sumika-launch-or-focus", pattern, "true"]);
    }

    function previousOrRewind(): void {
        if (!root.activePlayer)
            return;
        if (root.activePlayer.position > 8 && root.activePlayer.canSeek)
            root.activePlayer.position = 0.1;
        else if (root.activePlayer.canGoPrevious)
            root.activePlayer.previous();
    }

    IpcHandler {
        target: "mpris"

        function pauseAll(): void {
            for (const player of root.availablePlayers) {
                if (player.canPause)
                    player.pause();
            }
        }

        function playPause(): void {
            root.togglePlaying();
        }

        function previous(): void {
            root.previousOrRewind();
        }

        function next(): void {
            root.activePlayer?.next();
        }
    }
}
