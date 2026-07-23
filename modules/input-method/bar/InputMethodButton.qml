import qs
import qs.services
import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

BarModuleButton {
    id: root

    // Voice input state
    readonly property string voiceState: VoiceInput.state
    readonly property bool isRecording: voiceState === "recording"
    readonly property bool isTranscribing: voiceState === "transcribing"
    readonly property bool isSetup: voiceState === "setup"
    readonly property bool isError: voiceState === "error"
    readonly property bool usingVoiceUi: isRecording || isTranscribing || isSetup || isError

    icon: {
        if (!root.usingVoiceUi) return NerdIconMap.keyboard
        if (root.isTranscribing) return NerdIconMap.hourglass
        return NerdIconMap.mic
    }

    iconColor: {
        if (!root.usingVoiceUi) return Appearance.colors.colBarText
        if (root.isError) return "#FF3B30"
        if (root.isRecording) return "#F5C542"
        if (root.isTranscribing) return "#5B9BD5"
        if (root.isSetup) return "#F5C542"
        return Appearance.colors.colBarText
    }

    active: GlobalStates.barPopupType === "inputMethod"
    visible: root.usingVoiceUi || (Config.options.inputMethod.enabled && Services.InputMethod.available)

    onClicked: {
        if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
        if (root.usingVoiceUi) {
            VoiceInput.toggle();
        } else {
            Services.InputMethod.refresh();
            GlobalStates.barPopupType = GlobalStates.barPopupType === "inputMethod" ? "" : "inputMethod";
        }
    }
}
