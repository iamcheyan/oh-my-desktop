import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

StyledPopup {
    id: root

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
                if (event.name === "configreloaded") {
                    popupContent.refreshBindings()
                }
            }
        }

        Process {
            id: readBindingsProc
            command: ["bash", "-c", "cat ~/.config/omarchy/voice_bindings.txt 2>/dev/null || echo -e 'ALT + A\\ncode:472'"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.split("\n")
                    var result = []
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim()
                        if (line && !line.startsWith("#")) {
                            result.push(line)
                        }
                    }
                    popupContent.bindingsList = result
                }
            }
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
