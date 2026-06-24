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
    readonly property bool hasActivePlayer: activePlayer !== null && activePlayer !== undefined
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property real trackPosition: activePlayer?.position ?? 0
    readonly property real trackLength: activePlayer?.length ?? 0

    Layout.fillHeight: true
    implicitWidth: Config.options.bar.centerIconSize
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                if (root.hasActivePlayer) {
                    MprisController.togglePlaying();
                } else {
                    GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
                }
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

        spacing: Config.options.bar.centerModuleSpacing
        anchors.centerIn: parent

        CosmicIcon {
            id: noMediaIcon
            visible: !root.hasActivePlayer
            Layout.alignment: Qt.AlignVCenter
            name: "apps/multimedia-audio-player-symbolic"
            iconSize: Config.options.bar.centerIconSize
            color: Appearance.colors.colBarText
        }

        ClippedFilledCircularProgress {
            id: mediaCircProg
            visible: root.hasActivePlayer
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: root.trackLength > 0 ? root.trackPosition / root.trackLength : 0
            implicitSize: Config.options.bar.centerIconSize
            colPrimary: Appearance.colors.colBarText
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize

                CosmicIcon {
                    anchors.centerIn: parent
                    name: root.isPlaying ? "actions/media-playback-pause-symbolic" : "actions/media-playback-start-symbolic"
                    iconSize: Config.options.bar.centerIconSize - 4
                    color: Appearance.colors.colBarText
                }
            }
        }

    }

    MediaHoverPopup {
        id: mediaHoverPopup
        hoverTarget: mouseArea
    }
}