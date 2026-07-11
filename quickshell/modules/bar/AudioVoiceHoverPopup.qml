import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

StyledPopup {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real sinkVolume: sink?.audio.volume ?? 0
    readonly property bool sinkMuted: sink?.audio.muted ?? false
    readonly property bool sourceMuted: source?.audio.muted ?? false

    StyledPopupContent {
        id: popupContent
        property var bindingsList: []

        function refreshBindings() {
            readBindingsProc.running = true
        }

        Component.onCompleted: refreshBindings()

        Connections {
            target: Hyprland
            function onRawEvent(event) {
                if (event.name === "configreloaded")
                    popupContent.refreshBindings()
            }
        }

        Process {
            id: readBindingsProc
            command: ["bash", "-c", "cat ~/.config/omd/config/voice_bindings.txt 2>/dev/null || echo -e 'ALT + A\\ncode:472'"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.split("\n")
                    const result = []
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim()
                        if (line && !line.startsWith("#"))
                            result.push(line)
                    }
                    popupContent.bindingsList = result
                }
            }
        }

        StyledPopupValueRow {
            icon: root.sinkMuted ? NerdIconMap.volumeOff : NerdIconMap.volumeHigh
            label: "Volume:"
            value: root.sinkMuted ? "Muted" : `${Math.round(root.sinkVolume * 100)}%`
        }

        StyledPopupValueRow {
            icon: NerdIconMap.graphicEq
            label: "Output:"
            value: root.sink ? Audio.friendlyDeviceName(root.sink) : "--"
        }

        StyledPopupValueRow {
            icon: root.sourceMuted ? NerdIconMap.micOff : NerdIconMap.mic
            label: "Input:"
            value: root.source ? Audio.friendlyDeviceName(root.source) : "--"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }

        StyledPopupValueRow {
            icon: NerdIconMap.mic
            label: "Voice Input:"
            value: {
                if (VoiceInput.state === "idle") return "Ready"
                if (VoiceInput.state === "recording") return "Recording"
                if (VoiceInput.state === "transcribing") return "Transcribing..."
                if (VoiceInput.state === "setup") return "Setup Required"
                if (VoiceInput.state === "error") return "Error"
                return VoiceInput.state
            }
        }

        Repeater {
            model: popupContent.bindingsList
            delegate: StyledPopupValueRow {
                required property int index
                required property var modelData
                icon: NerdIconMap.keyboard
                label: index === 0 ? "Shortcut:" : "Alternative:"
                value: modelData
            }
        }
    }
}