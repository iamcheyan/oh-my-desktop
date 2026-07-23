// MPRIS media player controls — loads as a popup section inside the audio popup.
// Shown when an active MPRIS player is detected; hidden otherwise.
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool showControls: activePlayer !== null
    readonly property bool hasTrackArt: showControls && TrackArt.resolvedArtUrl.length > 0
    readonly property string trackTitle: {
        const t = StringUtils.cleanMusicTitle(activePlayer?.trackTitle || "")
        return t.length > 0 ? t : "Untitled"
    }
    readonly property string trackArtist: {
        const artist = activePlayer?.trackArtist || ""
        return artist === "Unknown Artist" ? "" : artist
    }
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property string playerName: MprisController.playerIdentity(activePlayer)
    readonly property string mediaSubtitle: {
        if (root.trackArtist.length > 0)
            return root.trackArtist
        if (root.playerName.length > 0)
            return root.playerName
        return root.isPlaying ? "Playing" : "Paused"
    }

    Layout.fillWidth: true
    implicitHeight: showControls ? 72 : 0
    visible: showControls

    function focusPlayer() {
        Qt.callLater(() => MprisController.raiseActivePlayer())
    }

    Rectangle {
        anchors.fill: parent
        visible: root.showControls
        color: "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 20
                rightMargin: 16
            }
            spacing: 12

            // ── Left: album art thumbnail or volume icon ────────────
            Item {
                Layout.preferredWidth: root.hasTrackArt ? 40 : 26
                Layout.preferredHeight: root.hasTrackArt ? 40 : 26
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    visible: root.hasTrackArt
                    radius: 8
                    color: TuiStyle.surfaceSubtle
                    border.width: 1
                    border.color: TuiStyle.line
                    clip: true

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: TrackArt.resolvedArtUrl
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: artImage.status !== Image.Ready
                        text: "album"
                        iconSize: 22
                        color: TuiStyle.dim
                    }

                    // Play pulse dot
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 2
                        width: 8
                        height: 8
                        radius: 4
                        color: root.isPlaying ? TuiStyle.accent : TuiStyle.dim
                        border.width: 1
                        border.color: TuiStyle.bg

                        SequentialAnimation on opacity {
                            running: root.isPlaying && root.hasTrackArt
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.35; duration: 900 }
                            NumberAnimation { from: 0.35; to: 1.0; duration: 900 }
                        }
                    }
                }

                // Fallback: simple play icon when no art
                NerdIcon {
                    anchors.centerIn: parent
                    visible: !root.hasTrackArt
                    iconSize: 26
                    text: NerdIconMap.play
                    color: TuiStyle.fg
                }
            }

            // ── Center: track title + artist ────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: titleMouse.containsMouse ? TuiStyle.accent : TuiStyle.fg
                    elide: Text.ElideRight

                    MouseArea {
                        id: titleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusPlayer()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.mediaSubtitle
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Normal
                    color: TuiStyle.dim
                    elide: Text.ElideRight
                }
            }

            // ── Right: transport controls ───────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                // Prev
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    opacity: root.activePlayer?.canGoPrevious ? 1 : 0.3

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        iconSize: 18
                        color: TuiStyle.fg
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.activePlayer?.canGoPrevious ?? false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.previousOrRewind()
                    }
                }

                // Play/Pause
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: playMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.selection
                    border.width: 1
                    border.color: TuiStyle.accent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "pause" : "play_arrow"
                        iconSize: 17
                        color: TuiStyle.accent
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activePlayer?.togglePlaying()
                    }
                }

                // Next
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    opacity: root.activePlayer?.canGoNext ? 1 : 0.3

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_next"
                        iconSize: 18
                        color: TuiStyle.fg
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.activePlayer?.canGoNext ?? false
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activePlayer?.next()
                    }
                }
            }
        }

        // Bottom separator line
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }
    }
}
