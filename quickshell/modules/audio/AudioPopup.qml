// AudioPopup.qml — Audio controls popup with volume, devices, and media player.
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.bar
import qs.core.runtime
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
    id: audioPanel
    width: parent?.width ?? implicitWidth
    implicitWidth: audioColumn.implicitWidth
    implicitHeight: audioColumn.implicitHeight

    property real wheelAccum: 0
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real sinkVolume: sink?.audio.volume ?? 0
    readonly property real sourceVolume: source?.audio.volume ?? 0
    readonly property bool sinkMuted: sink?.audio.muted ?? false
    readonly property bool sourceMuted: source?.audio.muted ?? false
    readonly property MprisPlayer activePlayer: ServiceManager.mpris.activePlayer
    // Media controls show whenever a player is active. (An earlier gate on
    // ModuleLoader.isEnabled("mpris") was always true — no such module id
    // exists — permanently hiding the media strip.)
    readonly property bool showMediaControls: activePlayer !== null
    readonly property bool hasTrackArt: showMediaControls && TrackArt.resolvedArtUrl.length > 0
    readonly property string trackTitle: {
        const t = StringUtils.cleanMusicTitle(activePlayer?.trackTitle || "")
        return t.length > 0 ? t : "Untitled"
    }
    readonly property string trackArtist: {
        const artist = activePlayer?.trackArtist || ""
        return artist === "Unknown Artist" ? "" : artist
    }
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property string playerName: ServiceManager.mpris.playerIdentity(activePlayer)
    readonly property bool chromiumPlayer: {
        const identity = (activePlayer?.identity || "").toLowerCase()
        return identity.includes("chrome") || identity.includes("chromium")
    }
    readonly property bool usePlayerVolume: !!activePlayer
        && activePlayer.volumeSupported
        && !chromiumPlayer
    readonly property bool mediaMuted: usePlayerVolume
        ? activePlayer.volume <= 0.001
        : sinkMuted
    property real mediaRestoreVolume: 1
    readonly property string mediaSubtitle: {
        if (audioPanel.trackArtist.length > 0)
            return audioPanel.trackArtist
        if (audioPanel.playerName.length > 0)
            return audioPanel.playerName
        return audioPanel.isPlaying ? "Playing" : "Paused"
    }

    function pinOpen() { GlobalStates.barPopupEphemeral = false; }
    function setSinkVolume(value) { audioPanel.pinOpen(); ServiceManager.audio.setSinkVolume(value); }
    function setSourceVolume(value) { audioPanel.pinOpen(); ServiceManager.audio.setSourceVolume(value); }
    function mediaPrev() {
        audioPanel.pinOpen()
        ServiceManager.mpris.previousOrRewind()
    }
    function mediaToggle() {
        audioPanel.pinOpen()
        activePlayer?.togglePlaying()
    }
    function mediaNext() {
        audioPanel.pinOpen()
        activePlayer?.next()
    }
    function toggleMediaMute() {
        audioPanel.pinOpen()
        if (!audioPanel.usePlayerVolume) {
            ServiceManager.audio.toggleMute()
            return
        }
        const volume = audioPanel.activePlayer.volume
        if (volume > 0.001) {
            audioPanel.mediaRestoreVolume = volume
            audioPanel.activePlayer.volume = 0
        } else {
            audioPanel.activePlayer.volume = Math.max(0.01, audioPanel.mediaRestoreVolume)
        }
    }
    function focusMediaPlayer() {
        GlobalStates.barPopupType = ""
        GlobalStates.barPopupEphemeral = false
        Qt.callLater(() => ServiceManager.mpris.raiseActivePlayer())
    }

    ColumnLayout {
        id: audioColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ── Combined Header (Volume & Media Player) ─────────────────
        Item {
            id: audioHeader
            Layout.fillWidth: true
            implicitHeight: 72

            RowLayout {
                id: headerRow
                anchors {
                    fill: parent
                    leftMargin: 20
                    rightMargin: 16
                }
                spacing: 12

                // Left Side: Album Art (if media playing and has art) or Volume Icon (if not)
                Item {
                    Layout.preferredWidth: audioPanel.hasTrackArt ? 40 : 26
                    Layout.preferredHeight: audioPanel.hasTrackArt ? 40 : 26
                    Layout.alignment: Qt.AlignVCenter

                    // Case A: Media Artwork (only visible when media playing and has art)
                    Rectangle {
                        anchors.fill: parent
                        visible: audioPanel.hasTrackArt
                        radius: 8
                        color: TuiStyle.surfaceSubtle
                        border.width: 1
                        border.color: TuiStyle.line
                        clip: true

                        Image {
                            id: headerArtworkImage
                            anchors.fill: parent
                            source: TrackArt.resolvedArtUrl
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: headerArtworkImage.status !== Image.Ready
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
                            color: audioPanel.isPlaying ? TuiStyle.accent : TuiStyle.dim
                            border.width: 1
                            border.color: TuiStyle.bg

                            SequentialAnimation on opacity {
                                running: audioPanel.isPlaying && audioPanel.hasTrackArt
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.35; duration: 900 }
                                NumberAnimation { from: 0.35; to: 1.0; duration: 900 }
                            }
                        }
                    }

                    // Case B: Simple Volume Icon (visible when no media playing OR has no art)
                    NerdIcon {
                        anchors.centerIn: parent
                        visible: !audioPanel.hasTrackArt
                        iconSize: 26
                        text: audioPanel.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
                        color: TuiStyle.fg
                    }
                }

                // Center: Text Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    // Title: Song Title (if media playing) or "Volume" (if not)
                    StyledText {
                        Layout.fillWidth: true
                        text: audioPanel.showMediaControls ? audioPanel.trackTitle : "Volume"
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.normal + (audioPanel.showMediaControls ? 0 : 1)
                        font.weight: Font.Medium
                        color: (audioPanel.showMediaControls && headerTitleMouse.containsMouse) ? TuiStyle.accent : TuiStyle.fg
                        elide: Text.ElideRight

                        MouseArea {
                            id: headerTitleMouse
                            anchors.fill: parent
                            enabled: audioPanel.showMediaControls
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: audioPanel.focusMediaPlayer()
                        }
                    }

                    // Subtitle: Artist + Volume (if media playing) or Volume + Mute details (if not)
                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (audioPanel.showMediaControls) {
                                const volStr = `${Math.round(audioPanel.sinkVolume * 100)}%`
                                const extra = audioPanel.sinkMuted ? " (Muted)" : ""
                                return (audioPanel.mediaSubtitle ? `${audioPanel.mediaSubtitle}  ·  ` : "") + `Vol ${volStr}${extra}`
                            } else {
                                return `Volume ${Math.round(audioPanel.sinkVolume * 100)}%` +
                                    (audioPanel.sinkMuted ? " (Muted)" : "") +
                                    (audioPanel.sourceMuted ? "  ·  Mic muted" : "")
                            }
                        }
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Normal
                        color: TuiStyle.dim
                        elide: Text.ElideRight
                    }
                }

                // Right Side: Media Controls + Settings Gear
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    // Media Controls (only shown when media playing)
                    RowLayout {
                        visible: audioPanel.showMediaControls
                        spacing: 0

                        // Prev
                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            opacity: audioPanel.activePlayer?.canGoPrevious ? 1 : 0.3

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 18
                                color: TuiStyle.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: audioPanel.activePlayer?.canGoPrevious ?? false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: audioPanel.mediaPrev()
                            }
                        }

                        // Play/Pause (compact circular button)
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: headerPlayMouse.containsMouse ? TuiStyle.controlHover : TuiStyle.selection
                            border.width: 1
                            border.color: TuiStyle.accent

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: audioPanel.isPlaying ? "pause" : "play_arrow"
                                iconSize: 17
                                color: TuiStyle.accent
                            }
                            MouseArea {
                                id: headerPlayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: audioPanel.mediaToggle()
                            }
                        }

                        // Next
                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            opacity: audioPanel.activePlayer?.canGoNext ? 1 : 0.3

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 18
                                color: TuiStyle.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: audioPanel.activePlayer?.canGoNext ?? false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: audioPanel.mediaNext()
                            }
                        }
                    }

                    // Settings Gear (always shown)
                    PopupActionButton {
                        icon: "settings"
                        onClicked: {
                            GlobalStates.barPopupType = ""
                            GlobalStates.barPopupEphemeral = false
                            Quickshell.execDetached(["env", "GDK_SCALE=1", "GDK_DPI_SCALE=0.5", "pavucontrol"])
                        }
                    }
                }
            }

            // Bottom Divider
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: TuiStyle.line
                opacity: TuiStyle.dividerOpacity
            }
        }

        PopupSliderRow {
            icon: audioPanel.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
            value: audioPanel.sinkVolume
            muted: audioPanel.sinkMuted
            onMoved: value => audioPanel.setSinkVolume(value)
            onIconClicked: { audioPanel.pinOpen(); ServiceManager.audio.toggleMute() }
        }

        PopupSliderRow {
            icon: audioPanel.sourceMuted ? NerdIconMap.micOff : NerdIconMap.mic
            value: audioPanel.sourceVolume
            muted: audioPanel.sourceMuted
            onMoved: value => audioPanel.setSourceVolume(value)
            onIconClicked: { audioPanel.pinOpen(); ServiceManager.audio.toggleMicMute() }
        }

        // Thin divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }

        // ── Output devices ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 16
                Layout.topMargin: 10
                Layout.bottomMargin: 4
                text: "Output"
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: TuiStyle.dim
            }

            Repeater {
                model: ServiceManager.audio.typedSinks
                delegate: MouseArea {
                    id: sinkRow
                    required property var modelData
                    readonly property var node: modelData
                    readonly property bool isActive: {
                        const cur = ServiceManager.audio.sink;
                        if (!cur || !node)
                            return false;
                        if (cur.name && node.name && cur.name === node.name)
                            return true;
                        return ServiceManager.audio.nodeObjectId(cur) === ServiceManager.audio.nodeObjectId(node)
                            && ServiceManager.audio.nodeObjectId(node).length > 0;
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    implicitHeight: 40
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        audioPanel.pinOpen();
                        if (node)
                            ServiceManager.audio.setDefaultSink(node);
                        else if (modelData?.name)
                            ServiceManager.audio.setDefaultSinkByName(modelData.name);
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: sinkRow.isActive
                            ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                            : (sinkRow.pressed
                                ? TuiStyle.selection
                                : (sinkRow.containsMouse ? TuiStyle.surfaceHover : "transparent"))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 16
                            spacing: 8

                            MaterialSymbol {
                                text: sinkRow.isActive ? "check" : "volume_up"
                                iconSize: 16
                                color: sinkRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                Layout.preferredWidth: 20
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: ServiceManager.audio.friendlyDeviceName(sinkRow.node)
                                color: sinkRow.isActive ? TuiStyle.accent : TuiStyle.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: sinkRow.isActive ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 16
                Layout.preferredHeight: 36
                verticalAlignment: Text.AlignVCenter
                visible: ServiceManager.audio.typedSinks.length === 0
                text: "No output devices"
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.dim
            }
        }

        // ── Input devices ──────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 16
                Layout.topMargin: 8
                Layout.bottomMargin: 4
                text: "Input"
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: TuiStyle.dim
            }

            Repeater {
                model: ServiceManager.audio.typedSources
                delegate: MouseArea {
                    id: sourceRow
                    required property var modelData
                    readonly property var node: modelData
                    readonly property bool isActive: {
                        const cur = ServiceManager.audio.source;
                        if (!cur || !node)
                            return false;
                        if (cur.name && node.name && cur.name === node.name)
                            return true;
                        return ServiceManager.audio.nodeObjectId(cur) === ServiceManager.audio.nodeObjectId(node)
                            && ServiceManager.audio.nodeObjectId(node).length > 0;
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    implicitHeight: 40
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        audioPanel.pinOpen();
                        if (node)
                            ServiceManager.audio.setDefaultSource(node);
                        else if (modelData?.name)
                            ServiceManager.audio.setDefaultSourceByName(modelData.name);
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: sourceRow.isActive
                            ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                            : (sourceRow.pressed
                                ? TuiStyle.selection
                                : (sourceRow.containsMouse ? TuiStyle.surfaceHover : "transparent"))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 16
                            spacing: 8

                            MaterialSymbol {
                                text: sourceRow.isActive ? "check" : "mic"
                                iconSize: 16
                                color: sourceRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                Layout.preferredWidth: 20
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: ServiceManager.audio.friendlyDeviceName(sourceRow.node)
                                color: sourceRow.isActive ? TuiStyle.accent : TuiStyle.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: sourceRow.isActive ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 16
                Layout.preferredHeight: 36
                Layout.bottomMargin: 8
                verticalAlignment: Text.AlignVCenter
                visible: ServiceManager.audio.typedSources.length === 0
                text: "No input devices"
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.dim
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                visible: ServiceManager.audio.typedSources.length > 0
            }
        }

    }

    // Prefer WheelHandler over a full-panel MouseArea so device rows
    // never compete with a sibling for pointer events.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            GlobalStates.barPopupEphemeral = false;
            const r = WheelUtils.getSteps(event.angleDelta.y, audioPanel.wheelAccum)
            audioPanel.wheelAccum = r.accum
            for (let i = 0; i < Math.abs(r.steps); i++) {
                if (r.steps > 0) ServiceManager.audio.incrementVolume()
                else if (r.steps < 0) ServiceManager.audio.decrementVolume()
            }
            event.accepted = true
        }
    }
}
