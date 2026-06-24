import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property real wheelAccum: 0
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property bool hasActivePlayer: activePlayer !== null && activePlayer !== undefined

    Layout.fillHeight: true
    implicitWidth: hasActivePlayer ? rowLayout.implicitWidth : Config.options.bar.rightIconSlotWidth
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            }
        }
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            for (let i = 0; i < Math.abs(r.steps); i++) {
                if (r.steps > 0) Audio.incrementVolume();
                else if (r.steps < 0) Audio.decrementVolume();
            }
            wheel.accepted = true;
        }
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: Config.options.bar.rightModuleSpacing
        anchors.fill: parent

        CosmicIcon {
            id: noMediaIcon
            visible: !root.hasActivePlayer
            Layout.alignment: Qt.AlignVCenter
            name: "apps/multimedia-audio-player-symbolic"
            iconSize: Config.options.bar.rightIconSize
            color: Appearance.colors.colBarText
        }

        ClippedFilledCircularProgress {
            id: mediaCircProg
            visible: root.hasActivePlayer
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            implicitSize: 20
            colPrimary: Appearance.colors.colBarText
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize
                
                CosmicIcon {
                    anchors.centerIn: parent
                    name: activePlayer?.isPlaying ? "actions/media-playback-pause-symbolic" : "actions/media-playback-start-symbolic"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colBarText
                }
            }
        }

        StyledText {
            visible: root.hasActivePlayer
            width: rowLayout.width - (CircularProgress.size + rowLayout.spacing * 2)
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true // Ensures the text takes up available space
            Layout.rightMargin: rowLayout.spacing
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight // Truncates the text on the right
            color: Appearance.colors.colBarText
            text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
        }

    }

}
