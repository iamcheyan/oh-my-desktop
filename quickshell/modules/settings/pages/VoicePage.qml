import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PageBody {
    id: page

    required property var settingsRoot
    readonly property string omdRoot: `${FileUtils.trimFileProtocol(Directories.config)}/omd`
    property var voicePageBindings: []

    SettingsCard {
        title: "Voice Engine"
        subtitle: VoiceInput.state === "setup" ? "Needs setup" : VoiceInput.daemonRunning ? "Daemon running" : "Daemon idle"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            SettingsStatusPill { label: VoiceInput.state === "idle" ? "ready" : VoiceInput.state; active: VoiceInput.state === "idle" }
            SettingsStatusPill { label: VoiceInput.modelSizeMB > 0 ? `${VoiceInput.modelSizeMB} MB model` : "no model"; active: VoiceInput.modelSizeMB > 0; warning: VoiceInput.modelSizeMB === 0 }
            SettingsStatusPill { label: VoiceInput.daemonRunning ? "daemon up" : "daemon down"; active: VoiceInput.daemonRunning }
        }

        SettingsRow {
            label: "Engine state"
            value: VoiceInput.state
        }
        SettingsRow {
            label: "Last result"
            description: VoiceInput.lastTranscription.length > 0 ? VoiceInput.lastTranscription.slice(0, 100) : "--"
        }
        SettingsRow {
            visible: VoiceInput.lastError.length > 0
            label: "Last error"
            description: VoiceInput.lastError
        }

        ButtonRow {
            SettingsButton {
                label: VoiceInput.state === "recording" ? "Stop" : VoiceInput.state === "transcribing" ? "Transcribing…" : "Record"
                iconName: "keyboard_voice"
                enabledState: VoiceInput.state === "idle" || VoiceInput.state === "recording"
                active: VoiceInput.state === "recording"
                onClicked: VoiceInput.toggle()
            }
            SettingsButton {
                label: VoiceInput.state === "setup" ? "Setup" : "Recheck"
                iconName: "download"
                onClicked: {
                    if (VoiceInput.state === "setup")
                        VoiceInput.setup()
                    else
                        VoiceInput.checkState()
                }
            }
        }
    }

    SettingsCard {
        title: "Keybindings"
        subtitle: voicePageBindings.length > 0 ? `${voicePageBindings.length} active` : "No bindings"

        Repeater {
            model: voicePageBindings
            delegate: SettingsRow {
                required property var modelData
                iconName: "keyboard"
                label: modelData
            }
        }

        ButtonRow {
            SettingsButton {
                label: "Configure"
                iconName: "open_in_new"
                onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-bind-tui`]) }
            }
            SettingsButton {
                label: "Capture Key"
                iconName: "open_in_new"
                onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached([`${omdRoot}/scripts/key-test-launcher`, "--hotkey"]) }
            }
        }

    }

    Process {
        id: voiceBindingsProc
        command: ["bash", "-c", "cat ~/.config/omd/config/voice_bindings.txt 2>/dev/null || echo ''"]
        running: true
        stdout: StdioCollector {
            id: voiceBindingsCollector
            onStreamFinished: {
                const text = voiceBindingsCollector.text.trim()
                voicePageBindings = text.length > 0
                    ? text.split("\n").filter(l => l.length > 0 && !l.startsWith("#"))
                    : []
            }
        }
    }

    SettingsCard {
        title: "Test & Diagnostics"
        subtitle: "Verify recording and troubleshoot"

        ButtonRow {
            SettingsButton {
                label: "Quick Test"
                iconName: "mic"
                enabledState: VoiceInput.state === "idle"
                onClicked: VoiceInput.testRecording()
            }
            SettingsButton {
                label: "TUI Test"
                iconName: "open_in_new"
                onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-test-tui`]) }
            }
        }
        ButtonRow {
            SettingsButton {
                label: "Diagnose"
                iconName: "open_in_new"
                onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-diagnose`]) }
            }
            SettingsButton {
                label: "Clear History"
                iconName: "clear_all"
                onClicked: VoiceInput.clearHistory()
            }
        }
    }

    SettingsCard {
        title: "History"
        subtitle: `${VoiceInput.history.length} entries`
        visible: VoiceInput.history.length > 0

        Repeater {
            model: VoiceInput.history.slice(0, 8)
            delegate: SettingsRow {
                required property var modelData
                iconName: "history"
                label: modelData.text ? modelData.text.slice(0, 80) : "--"
                value: modelData.time || ""
            }
        }
    }

    SettingsCard {
        title: "Paths & Cache"
        subtitle: "Runtime directories"
        SettingsRow { label: "Cache dir"; value: VoiceInput.cacheDir }
        SettingsRow { label: "Model dir"; value: VoiceInput.modelDir }
        SettingsRow { label: "Venv dir"; value: VoiceInput.venvDir }
        SettingsRow { label: "Socket"; value: "/tmp/omd-voice.sock" }
    }
}
