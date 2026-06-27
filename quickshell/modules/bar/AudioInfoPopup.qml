pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

PopupWindow {
    id: root
    signal menuClosed

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiPanelAlt: "#091814"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiYellow: "#e8ff82"
    readonly property color tuiBlue: "#7bc7ff"
    readonly property color tuiPurple: "#c792ea"
    readonly property color tuiRed: "#ff6b8b"

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real sinkVolume: sink?.audio.volume ?? 0
    readonly property bool sinkMuted: sink?.audio.muted ?? false
    readonly property real sourceVolume: source?.audio.volume ?? 0
    readonly property bool sourceMuted: source?.audio.muted ?? false
    readonly property list<var> sinkDevices: Audio.outputDevices
    readonly property list<var> sourceDevices: Audio.inputDevices
    readonly property list<var> sinkApps: Audio.outputAppNodes
    readonly property list<var> sourceApps: Audio.inputAppNodes

    function sinkStateLabel() {
        if (sinkMuted)
            return "muted";
        if (!Audio.ready)
            return "unavailable";
        return "active";
    }

    function sourceStateLabel() {
        if (sourceMuted)
            return "muted";
        if (!source)
            return "unavailable";
        return "active";
    }

    function stateTone(muted) {
        return muted ? root.tuiRed : root.tuiGreen;
    }

    implicitWidth: popupBg.implicitWidth + padding * 2
    implicitHeight: popupBg.implicitHeight + padding * 2

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
    }
    Component.onDestruction: {
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()

        StyledRectangularShadow {
            target: popupBg
            opacity: popupBg.opacity
        }

        Rectangle {
            id: popupBg
            readonly property real innerPad: 12
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.padding
            }

            color: root.tuiBg
            radius: Appearance.tiling.dialogRadius
            border.width: Appearance.tiling.borderWidth
            border.color: root.tuiLine
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: 300 + innerPad * 2
            implicitHeight: popupCol.implicitHeight + innerPad * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

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
                            text: root.sinkStateLabel().toUpperCase()
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.stateTone(root.sinkMuted)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    anchors.margins: 14
                    spacing: 14

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

                    MeterBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        value: root.sinkMuted ? 0 : root.sinkVolume * 100
                        accent: root.sinkMuted ? root.tuiRed : root.tuiBlue
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    DetailRow {
                        keyText: "OUTPUT"
                        valueText: root.sink ? Audio.friendlyDeviceName(root.sink) : "--"
                        valueColor: root.tuiBlue
                    }

                    DetailRow {
                        keyText: "O LEVEL"
                        valueText: `${Math.round(root.sinkVolume * 100)}%`
                        valueColor: root.sinkMuted ? root.tuiRed : root.tuiFg
                    }

                    DetailRow {
                        keyText: "O APPS"
                        valueText: `${root.sinkApps.length}`
                        valueColor: root.tuiDim
                    }

                    DetailRow {
                        keyText: "O DEVICES"
                        valueText: `${root.sinkDevices.length}`
                        valueColor: root.tuiDim
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    DetailRow {
                        keyText: "INPUT"
                        valueText: root.source ? Audio.friendlyDeviceName(root.source) : "--"
                        valueColor: root.tuiPurple
                    }

                    DetailRow {
                        keyText: "I LEVEL"
                        valueText: `${Math.round(root.sourceVolume * 100)}%`
                        valueColor: root.sourceMuted ? root.tuiRed : root.tuiFg
                    }

                    DetailRow {
                        keyText: "I APPS"
                        valueText: `${root.sourceApps.length}`
                        valueColor: root.tuiDim
                    }

                    DetailRow {
                        keyText: "I DEVICES"
                        valueText: `${root.sourceDevices.length}`
                        valueColor: root.tuiDim
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    component DetailRow: RowLayout {
        property string keyText: ""
        property string valueText: ""
        property color valueColor: root.tuiFg

        Layout.fillWidth: true
        spacing: 10

        StyledText {
            Layout.preferredWidth: 70
            text: keyText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: root.tuiDim
        }

        StyledText {
            Layout.fillWidth: true
            text: valueText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: valueColor
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    component MeterBar: Row {
        id: meter

        property real value: 0
        property color accent: root.tuiGreen

        spacing: 3
        Repeater {
            model: 14
            Rectangle {
                required property int index
                width: Math.max(8, (meter.width - 39) / 14)
                height: meter.height
                color: index < Math.ceil(Math.max(0, Math.min(100, meter.value)) / 100 * 14) ? meter.accent : root.tuiLine
            }
        }
    }
}