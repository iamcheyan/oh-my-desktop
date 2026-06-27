import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property color tuiBg: TuiStyle.bg
    readonly property color tuiPanel: TuiStyle.panel
    readonly property color tuiFg: TuiStyle.fg
    readonly property color tuiDim: TuiStyle.dim
    readonly property color tuiLine: TuiStyle.line
    readonly property color tuiGreen: TuiStyle.green
    readonly property color tuiBlue: TuiStyle.blue
    readonly property color tuiRed: TuiStyle.red

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real sinkVolume: sink?.audio.volume ?? 0
    readonly property bool sinkMuted: sink?.audio.muted ?? false

    function stateTone(muted) {
        return muted ? root.tuiRed : root.tuiGreen;
    }

    implicitWidth: 300 + Appearance.sizes.elevationMargin * 2
    implicitHeight: popupBg.implicitHeight + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: popupBg
    }

    Rectangle {
        id: popupBg
        readonly property real innerPad: 12
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }

        color: root.tuiBg
        radius: Appearance.tiling.dialogRadius
        border.width: Appearance.tiling.borderWidth
        border.color: root.tuiLine
        clip: true

        implicitWidth: 300 + innerPad * 2
        implicitHeight: popupCol.implicitHeight + innerPad * 2

        ColumnLayout {
            id: popupCol
            anchors {
                fill: parent
                margins: popupBg.innerPad
            }
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: root.tuiPanel
                border.width: 1
                border.color: root.tuiBlue

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    StyledText {
                        text: "AUDIO"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.tuiBlue
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    StyledText {
                        text: root.sinkMuted ? "MUTED" : "ACTIVE"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: root.stateTone(root.sinkMuted)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 12

                CosmicIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: root.sinkMuted ? "status/audio-volume-muted-symbolic" : "status/audio-volume-high-symbolic"
                    iconSize: 24
                    color: root.stateTone(root.sinkMuted)
                }

                StyledText {
                    text: `${Math.round(root.sinkVolume * 100)}%`
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: root.sinkMuted ? root.tuiRed : root.tuiFg
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: root.sinkMuted ? "MUTE" : "ON"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: root.stateTone(root.sinkMuted)
                }
            }

            TuiMeterBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                Layout.topMargin: 10
                Layout.bottomMargin: 14
                value: root.sinkMuted ? 0 : root.sinkVolume * 100
                accent: root.sinkMuted ? root.tuiRed : root.tuiBlue
            }
        }
    }

}