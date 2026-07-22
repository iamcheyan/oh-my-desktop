// VoicePopup.qml — Voice input testing and status popup.
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.bar
import qs.services
import qs.core.runtime
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth

    function stateLabel() {
        if (VoiceInput.state === "setup") return "Not Installed";
        if (VoiceInput.state === "idle") return "Ready";
        if (VoiceInput.state === "recording") return "Recording";
        if (VoiceInput.state === "transcribing") return "Transcribing";
        if (VoiceInput.state === "success") return "Transcription Success";
        if (VoiceInput.state === "error") return "Error";
        return VoiceInput.state;
    }
    function tone() {
        if (VoiceInput.state === "idle" || VoiceInput.state === "success") return TuiStyle.success;
        if (VoiceInput.state === "recording" || VoiceInput.state === "error") return TuiStyle.danger;
        if (VoiceInput.state === "transcribing" || VoiceInput.state === "setup") return TuiStyle.warning;
        return TuiStyle.muted;
    }

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.mic
        title: "Voice Input"
        subtitle: popup.stateLabel()
        tone: popup.tone()
    }

    // Model status card
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: modelCol.implicitHeight + 16
        color: TuiStyle.panel
        radius: TuiStyle.radius
        clip: true

        ColumnLayout {
            id: modelCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            PopupInfoRow {
                label: "Model"
                value: VoiceInput.modelSizeMB > 0 ? `SenseVoice Small (${VoiceInput.modelSizeMB} MB)` : "Missing"
                valueColor: VoiceInput.modelSizeMB > 0 ? TuiStyle.success : TuiStyle.danger
                showDivider: true
            }

            PopupInfoRow {
                label: "Daemon Status"
                value: VoiceInput.daemonRunning ? "Active (RAM Loaded)" : "Standby"
                valueColor: VoiceInput.daemonRunning ? TuiStyle.success : TuiStyle.dim
                showDivider: true
            }

            PopupInfoRow {
                label: "Virtual Env"
                value: VoiceInput.state === "setup" ? "Missing" : "Ready"
                valueColor: VoiceInput.state === "setup" ? TuiStyle.danger : TuiStyle.success
                showDivider: false
            }
        }
    }

    // Debug test section
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: debugCol.implicitHeight + 16
        color: TuiStyle.panel
        radius: TuiStyle.radius
        clip: true
        visible: VoiceInput.state !== "setup"

        ColumnLayout {
            id: debugCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Circle button for record toggle
                Rectangle {
                    id: debugRecBtn
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: VoiceInput.state === "recording" ? TuiStyle.danger : recMouse.containsMouse ? TuiStyle.surfaceHover : TuiStyle.surfaceRaised
                    border.width: 1
                    border.color: VoiceInput.state === "recording" ? TuiStyle.danger : TuiStyle.line

                    NerdIcon {
                        anchors.centerIn: parent
                        iconSize: 20
                        text: VoiceInput.state === "recording" ? NerdIconMap.stop : NerdIconMap.mic
                        color: TuiStyle.fg
                    }

                    MouseArea {
                        id: recMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: VoiceInput.state === "idle" || VoiceInput.state === "recording"
                        onClicked: {
                            if (VoiceInput.state === "recording") {
                                VoiceInput.stopRecording();
                            } else {
                                VoiceInput.testRecording();
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: {
                            if (VoiceInput.state === "recording") return `Recording ${VoiceInput.recordingDuration.toFixed(1)}s`
                            if (VoiceInput.state === "transcribing") return "Transcribing…"
                            if (VoiceInput.state === "success") return "Transcription ready"
                            if (VoiceInput.state === "error") return "Error"
                            return "Tap mic to test 3s"
                        }
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: popup.tone()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: VoiceInput.lastError || VoiceInput.lastTranscription || "—"
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: VoiceInput.lastError ? TuiStyle.danger : TuiStyle.fg
                    }
                }
            }

            IconActionRow {
                PopupIconButton {
                    icon: "content_copy"
                    label: "COPY TEXT"
                    enabledState: VoiceInput.lastTranscription.length > 0
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c",
                            `printf '%s' '${StringUtils.shellSingleQuoteEscape(VoiceInput.lastTranscription)}' | wl-copy`]);
                        VoiceInput.notify("Copied", VoiceInput.lastTranscription, "edit-copy");
                    }
                }
                PopupIconButton {
                    icon: "content_paste"
                    label: "PASTE"
                    enabledState: VoiceInput.lastTranscription.length > 0
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c",
                            `payload=$(mktemp); trap 'rm -f "$payload"' EXIT; ` +
                            `printf '%s' '${StringUtils.shellSingleQuoteEscape(VoiceInput.lastTranscription)}' > "$payload" && ` +
                            `wl-copy < "$payload" && OMD_PASTE_SOURCE=voice-manual ` +
                            `'${VoiceInput.shareDir}/omd-paste-at-cursor' --file "$payload" auto`]);
                    }
                }
            }
        }
    }

    // History section
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(historyList.implicitHeight + 16, 160)
        color: TuiStyle.panel
        radius: TuiStyle.radius
        clip: true
        visible: VoiceInput.history.length > 0

        ColumnLayout {
            id: historyList
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            StyledText {
                text: `History (${VoiceInput.history.length})`
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: TuiStyle.dim
            }

            ColumnLayout {
                spacing: 0
                Repeater {
                    model: VoiceInput.history.slice(0, 5)
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: histMouse.containsMouse ? TuiStyle.panelAlt : "transparent"

                        MouseArea {
                            id: histMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c",
                                    `printf '%s' '${StringUtils.shellSingleQuoteEscape(modelData.text)}' | wl-copy`]);
                                GlobalStates.barPopupType = ""
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 8

                            StyledText {
                                text: modelData.time
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: TuiStyle.dim
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.text
                                elide: Text.ElideRight
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: histMouse.containsMouse ? TuiStyle.fg : TuiStyle.muted
                            }
                        }
                    }
                }
            }
        }
    }

    IconActionRow {
        PopupIconButton {
            icon: "play_arrow"
            label: VoiceInput.state === "setup" ? "Setup" : "Test"
            onClicked: {
                if (VoiceInput.state === "setup") {
                    VoiceInput.setup();
                } else {
                    VoiceInput.testRecording();
                }
                GlobalStates.barPopupType = ""
            }
        }
        PopupIconButton {
            icon: "refresh"
            label: "Check State"
            onClicked: {
                VoiceInput.checkState();
                VoiceInput.refreshModelInfo();
                VoiceInput.refreshDaemonStatus();
            }
        }
        PopupIconButton {
            icon: "delete"
            label: "Clear History"
            enabledState: VoiceInput.history.length > 0
            onClicked: VoiceInput.clearHistory()
        }
    }

    PopupFooterLink {
        Layout.fillWidth: true
        label: "Voice Settings…"
        onClicked: {
            GlobalStates.barPopupType = ""
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "voice"]);
        }
    }
}
