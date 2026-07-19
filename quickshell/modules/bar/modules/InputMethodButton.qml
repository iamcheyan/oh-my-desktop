import qs
import qs.services
import qs.services as Services
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    // Voice input state
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

    readonly property string iconText: {
        if (!root.usingVoiceUi) return NerdIconMap.keyboard
        if (root.isTranscribing) return NerdIconMap.hourglass
        return NerdIconMap.mic
    }

    RippleButton {
        id: button
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Config.options.bar.rightIconSlotWidth / 2
        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: GlobalStates.barPopupType === "inputMethod"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200)
                return;
            if (root.usingVoiceUi) {
                VoiceInput.toggle();
            } else {
                Services.InputMethod.refresh();
                GlobalStates.barPopupType = GlobalStates.barPopupType === "inputMethod"
                    ? ""
                    : "inputMethod";
            }
        }
    }

    // Pulse ring for recording/transcribing
    Rectangle {
        id: pulseRing
        anchors.centerIn: button
        width: button.width
        height: button.height
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
        anchors.centerIn: button
        iconSize: root.isTranscribing
            ? Config.options.bar.rightIconSize * 0.72
            : Config.options.bar.rightIconSize
        text: root.iconText
        color: root.iconColor

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Recording blink animation
    SequentialAnimation {
        id: recordingBlink
        running: false
        loops: 2
        NumberAnimation { target: icon; property: "opacity"; from: 1.0; to: 0.3; duration: 500 }
        NumberAnimation { target: icon; property: "opacity"; from: 0.3; to: 1.0; duration: 500 }
        onStopped: icon.opacity = 1.0
    }

    // Transcribing rotation animation
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
            recordingBlink.start();
    }

    // Badge - only show when not using voice UI
    Rectangle {
        anchors.right: button.right
        anchors.bottom: button.bottom
        anchors.rightMargin: 1
        anchors.bottomMargin: 1
        width: 13
        height: 13
        radius: 3
        color: TuiStyle.bg
        visible: !root.usingVoiceUi

        StyledText {
            anchors.centerIn: parent
            text: Services.InputMethod.badge || "?"
            color: TuiStyle.accent
            font.family: Appearance.font.family.main
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }
    }
}
