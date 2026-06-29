import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

StyledPopup {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasActivePlayer: activePlayer !== null && activePlayer !== undefined
    readonly property string title: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string artist: activePlayer?.trackArtist ?? ""
    readonly property string album: activePlayer?.trackAlbum ?? ""
    readonly property string playerName: activePlayer?.identity ?? ""
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property real position: activePlayer?.position ?? 0
    readonly property real length: activePlayer?.length ?? 0
    readonly property var loopState: MprisController.loopState
    readonly property bool hasShuffle: MprisController.hasShuffle
    readonly property bool canGoNext: MprisController.canGoNext
    readonly property bool canGoPrevious: MprisController.canGoPrevious

    StyledPopupContent {
        contentSpacing: 6

        StyledPopupHeaderRow {
            icon: root.isPlaying ? NerdIconMap.pause : NerdIconMap.play
            label: root.isPlaying ? Translation.tr("Playing") : Translation.tr("Paused")
        }

        // Track title
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            color: TuiStyle.fg
            font {
                weight: Font.Bold
                pixelSize: Appearance.font.pixelSize.normal
            }
            text: root.title
            elide: Text.ElideRight
            Layout.maximumWidth: 240
        }

        // Artist
        StyledText {
            visible: root.artist.length > 0
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            color: TuiStyle.fg
            font.pixelSize: Appearance.font.pixelSize.smaller
            text: root.artist
            elide: Text.ElideRight
            Layout.maximumWidth: 240
        }

        // Album
        RowLayout {
            visible: root.album.length > 0
            Layout.fillWidth: true
            spacing: 6

            NerdIcon {
                color: TuiStyle.accent
                iconSize: Appearance.font.pixelSize.small
                text: NerdIconMap.album
            }
            StyledText {
                text: Translation.tr("Album:")
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: TuiStyle.fg
                text: root.album
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        // Player
        RowLayout {
            visible: root.playerName.length > 0
            Layout.fillWidth: true
            spacing: 6

            NerdIcon {
                color: TuiStyle.accent
                iconSize: Appearance.font.pixelSize.small
                text: NerdIconMap.graphicEq
            }
            StyledText {
                text: Translation.tr("Player:")
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: TuiStyle.fg
                text: root.playerName
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        // Position
        RowLayout {
            visible: root.hasActivePlayer && root.length > 0
            Layout.fillWidth: true
            spacing: 6

            NerdIcon {
                color: TuiStyle.accent
                iconSize: Appearance.font.pixelSize.small
                text: NerdIconMap.timer
            }
            StyledText {
                text: Translation.tr("Position:")
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: TuiStyle.fg
                text: `${StringUtils.friendlyTimeForSeconds(root.position)} / ${StringUtils.friendlyTimeForSeconds(root.length)}`
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        // Loop state
        RowLayout {
            visible: root.hasActivePlayer
            Layout.fillWidth: true
            spacing: 6

            NerdIcon {
                color: TuiStyle.accent
                iconSize: Appearance.font.pixelSize.small
                text: NerdIconMap.repeat
            }
            StyledText {
                text: Translation.tr("Loop:")
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: TuiStyle.fg
                text: {
                    switch (root.loopState) {
                        case MprisLoopState.None:
                            return Translation.tr("Off");
                        case MprisLoopState.Track:
                            return Translation.tr("Track");
                        case MprisLoopState.Playlist:
                            return Translation.tr("Playlist");
                        default:
                            return Translation.tr("Off");
                    }
                }
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        // Shuffle
        RowLayout {
            visible: root.hasActivePlayer
            Layout.fillWidth: true
            spacing: 6

            NerdIcon {
                color: TuiStyle.accent
                iconSize: Appearance.font.pixelSize.small
                text: NerdIconMap.shuffle
            }
            StyledText {
                text: Translation.tr("Shuffle:")
                color: TuiStyle.fg
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: TuiStyle.fg
                text: root.hasShuffle ? Translation.tr("On") : Translation.tr("Off")
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        // No active player hint
        StyledText {
            visible: !root.hasActivePlayer
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            color: TuiStyle.fg
            font.pixelSize: Appearance.font.pixelSize.small
            text: Translation.tr("Make sure your player has MPRIS support")
        }
    }
}
