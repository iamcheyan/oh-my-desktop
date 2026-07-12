import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth
    property real wheelAccum: 0

    readonly property string voiceState: VoiceInput.state
    readonly property bool isRecording: voiceState === "recording"
    readonly property bool isTranscribing: voiceState === "transcribing"
    readonly property bool isSetup: voiceState === "setup"
    readonly property bool isError: voiceState === "error"
    readonly property bool usingVoiceUi: isRecording || isTranscribing || isSetup || isError
    readonly property bool isActive: isRecording || isTranscribing || isSetup

    readonly property color colorIdle: Appearance.colors.colBarText
    readonly property color colorRecording: "#F5C542"
    readonly property color colorTranscribing: "#5B9BD5"
    readonly property color colorError: "#FF3B30"

    readonly property color iconColor: {
        if (!root.usingVoiceUi) return root.colorIdle
        if (root.isError) return root.colorError
        if (root.isRecording) return root.colorRecording
        if (root.isTranscribing) return root.colorTranscribing
        if (root.isSetup) return root.colorRecording
        return root.colorIdle
    }

    readonly property string volumeIcon: {
        if (Audio.sink?.audio?.muted) return NerdIconMap.volumeOff
        const vol = Audio.sink?.audio?.volume ?? 0
        if (vol > 0.66) return NerdIconMap.volumeHigh
        if (vol > 0.33) return NerdIconMap.volumeMedium
        return NerdIconMap.volumeLow
    }

    readonly property string iconText: {
        if (!root.usingVoiceUi) return root.volumeIcon
        if (root.isTranscribing) return NerdIconMap.hourglass
        return NerdIconMap.mic
    }

    RippleButton {
        id: actionButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full

        colBackground: "transparent"
        colBackgroundHover: "#18ffffff"
        colRipple: "transparent"
        colBackgroundToggled: "#30ffffff"
        colBackgroundToggledHover: "#40ffffff"
        colRippleToggled: "transparent"
        toggled: !root.usingVoiceUi && GlobalStates.barPopupType === "audio"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            if (root.usingVoiceUi)
                VoiceInput.toggle()
            else {
                const opening = GlobalStates.barPopupType !== "audio"
                GlobalStates.barPopupEphemeral = false
                GlobalStates.barPopupType = opening ? "audio" : ""
            }
        }
    }

    Rectangle {
        id: pulseRing
        anchors.centerIn: actionButton
        width: actionButton.width
        height: actionButton.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.isRecording ? root.colorRecording
            : root.isTranscribing ? root.colorTranscribing
            : root.colorRecording
        visible: root.isActive
        opacity: 0.75

        SequentialAnimation on scale {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.65; duration: 750; easing.type: Easing.OutCubic }
            NumberAnimation { from: 1.65; to: 1.0; duration: 0 }
        }
        SequentialAnimation on opacity {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { from: 0.75; to: 0; duration: 750; easing.type: Easing.OutCubic }
            NumberAnimation { from: 0; to: 0.75; duration: 0 }
        }
    }

    BarNerdIcon {
        id: icon
        anchors.centerIn: actionButton
        iconSize: root.isTranscribing
            ? Config.options.bar.rightIconSize * 0.72
            : Config.options.bar.rightIconSize
        text: root.iconText
        color: root.iconColor

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    SequentialAnimation {
        id: recordingBlink
        running: root.isRecording && !root.isError
        loops: Animation.Infinite
        NumberAnimation { target: icon; property: "opacity"; from: 1.0; to: 0.3; duration: 500 }
        NumberAnimation { target: icon; property: "opacity"; from: 0.3; to: 1.0; duration: 500 }
        onStopped: icon.opacity = 1.0
    }

    SequentialAnimation {
        id: errorBlink
        running: false
        loops: 2
        NumberAnimation { target: icon; property: "opacity"; from: 1.0; to: 0.0; duration: 80 }
        NumberAnimation { target: icon; property: "opacity"; from: 0.0; to: 1.0; duration: 80 }
        NumberAnimation { target: icon; property: "opacity"; from: 1.0; to: 0.0; duration: 80 }
        NumberAnimation { target: icon; property: "opacity"; from: 0.0; to: 1.0; duration: 80 }
        onStopped: icon.opacity = 1.0
    }

    SequentialAnimation {
        id: rotateAnim
        running: root.isTranscribing
        loops: Animation.Infinite
        NumberAnimation {
            target: icon
            property: "rotation"
            from: 0
            to: 180
            duration: 2000
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: 300 }
        PropertyAction {
            target: icon
            property: "rotation"
            value: 0
        }
        onStopped: icon.rotation = 0
    }

    onIsErrorChanged: {
        if (root.isError)
            errorBlink.start()
    }

    MouseArea {
        z: 20
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
            root.wheelAccum = r.accum
            for (let i = 0; i < Math.abs(r.steps); i++) {
                if (r.steps > 0)
                    Audio.incrementVolume()
                else if (r.steps < 0)
                    Audio.decrementVolume()
            }
            wheel.accepted = true
            if (!root.usingVoiceUi) {
                GlobalStates.barPopupEphemeral = false
                GlobalStates.barPopupType = "audio"
            }
        }
    }
}
