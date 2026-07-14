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
    id: pageRoot
    property var settingsRoot: null

    readonly property bool wideLayout: width >= 980

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        columns: pageRoot.wideLayout ? 2 : 1
        columnSpacing: 16
        rowSpacing: 16

        // ── Left Column: Audio Devices ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: pageRoot.wideLayout ? (contentGrid.width - 16) / 2 : contentGrid.width
            spacing: 16

            SettingsCard {
                title: "Audio Devices"
                subtitle: `${Audio.typedSinks.length} output${Audio.typedSinks.length === 1 ? "" : "s"}, ${Audio.typedSources.length} input${Audio.typedSources.length === 1 ? "" : "s"}`

                // ── Output Devices Section ──
                StyledText {
                    text: "Output Devices"
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                }

                // Loading overlay for WirePlumber reload
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    visible: Audio.wireplumberReloading
                    radius: SettingsTokens.radius
                    color: SettingsTokens.accentSoft
                    border.width: 1
                    border.color: SettingsTokens.accent

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        MaterialSymbol {
                            text: "refresh"
                            iconSize: 18
                            color: SettingsTokens.accent
                            RotationAnimator on rotation {
                                running: Audio.wireplumberReloading
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1200
                            }
                        }

                        StyledText {
                            text: "Restarting audio system..."
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Repeater {
                    model: Audio.typedSinks
                    delegate: ColumnLayout {
                        id: sinkDelegate
                        required property var modelData
                        readonly property var node: modelData
                        readonly property bool isActive: Audio.sink?.name === node.name
                        readonly property bool hasAlias: Audio.hasDeviceAlias(node.name)
                        property bool editing: false
                        property string aliasText: ""

                        Layout.fillWidth: true
                        spacing: 6

                        // Device row
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: SettingsTokens.radius
                            color: sinkDelegate.isActive ? SettingsTokens.accentSoft : (sinkRowMouse.containsMouse ? SettingsTokens.buttonHover : "transparent")
                            border.width: sinkDelegate.isActive ? 1 : 0
                            border.color: SettingsTokens.accent

                            MouseArea {
                                id: sinkRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Audio.setDefaultSink(sinkDelegate.node)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                MaterialSymbol {
                                    text: sinkDelegate.isActive ? "check_circle" : "radio_button_unchecked"
                                    iconSize: 18
                                    color: sinkDelegate.isActive ? SettingsTokens.accent : SettingsTokens.muted
                                    Layout.preferredWidth: 22
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.displayName(sinkDelegate.node)
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sinkDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: sinkDelegate.hasAlias ? Audio.originalName(sinkDelegate.node) : ""
                                        visible: sinkDelegate.hasAlias
                                        color: SettingsTokens.dim
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                    }
                                }

                                // Per-device volume slider
                                SettingsSlider {
                                    Layout.preferredWidth: 100
                                    value: sinkDelegate.node?.audio?.volume ?? 0
                                    onMoved: {
                                        if (sinkDelegate.node?.audio)
                                            sinkDelegate.node.audio.volume = value
                                    }
                                }

                                StyledText {
                                    Layout.preferredWidth: 38
                                    text: `${Math.round((sinkDelegate.node?.audio?.volume ?? 0) * 100)}%`
                                    color: SettingsTokens.muted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    horizontalAlignment: Text.AlignRight
                                }

                                // Rename button
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: SettingsTokens.radius
                                    color: renameMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"
                                    visible: !sinkDelegate.editing

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "edit"
                                        iconSize: 16
                                        color: SettingsTokens.muted
                                    }

                                    MouseArea {
                                        id: renameMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            sinkDelegate.aliasText = Audio.getDeviceAlias(sinkDelegate.node.name) || ""
                                            sinkDelegate.editing = true
                                        }
                                    }
                                }
                            }
                        }

                        // Inline rename dialog
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            visible: sinkDelegate.editing
                            radius: SettingsTokens.radius
                            color: SettingsTokens.panelAlt
                            border.width: 1
                            border.color: SettingsTokens.accent

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                TextInput {
                                    Layout.fillWidth: true
                                    text: sinkDelegate.aliasText
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    clip: true
                                    onTextEdited: sinkDelegate.aliasText = text
                                    onAccepted: {
                                        Audio.setDeviceAlias(sinkDelegate.node.name, sinkDelegate.aliasText)
                                        sinkDelegate.editing = false
                                    }
                                    Keys.onEscapePressed: sinkDelegate.editing = false
                                    Component.onCompleted: forceActiveFocus()
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: SettingsTokens.radius
                                    color: saveMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 16
                                        color: SettingsTokens.accent
                                    }

                                    MouseArea {
                                        id: saveMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Audio.setDeviceAlias(sinkDelegate.node.name, sinkDelegate.aliasText)
                                            sinkDelegate.editing = false
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: SettingsTokens.radius
                                    color: cancelMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"
                                    visible: sinkDelegate.hasAlias

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconSize: 16
                                        color: "#f07070"
                                    }

                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Audio.removeDeviceAlias(sinkDelegate.node.name)
                                            sinkDelegate.editing = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Divider between Output and Input Devices
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                    opacity: 0.4
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    visible: Audio.typedSinks.length > 0 && Audio.typedSources.length > 0
                }

                // ── Input Devices Section ──
                StyledText {
                    text: "Input Devices"
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    visible: Audio.typedSources.length > 0
                }

                Repeater {
                    model: Audio.typedSources
                    delegate: ColumnLayout {
                        id: sourceDelegate
                        required property var modelData
                        readonly property var node: modelData
                        readonly property bool isActive: Audio.source?.name === node.name

                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: SettingsTokens.radius
                            color: sourceDelegate.isActive ? SettingsTokens.accentSoft : (sourceRowMouse.containsMouse ? SettingsTokens.buttonHover : "transparent")
                            border.width: sourceDelegate.isActive ? 1 : 0
                            border.color: SettingsTokens.accent

                            MouseArea {
                                id: sourceRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Audio.setDefaultSource(sourceDelegate.node)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                MaterialSymbol {
                                    text: sourceDelegate.isActive ? "check_circle" : "radio_button_unchecked"
                                    iconSize: 18
                                    color: sourceDelegate.isActive ? SettingsTokens.accent : SettingsTokens.muted
                                    Layout.preferredWidth: 22
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.displayName(sourceDelegate.node)
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sourceDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }

                                SettingsSlider {
                                    Layout.preferredWidth: 100
                                    value: sourceDelegate.node?.audio?.volume ?? 0
                                    onMoved: {
                                        if (sourceDelegate.node?.audio)
                                            sourceDelegate.node.audio.volume = value
                                    }
                                }

                                StyledText {
                                    Layout.preferredWidth: 38
                                    text: `${Math.round((sourceDelegate.node?.audio?.volume ?? 0) * 100)}%`
                                    color: SettingsTokens.muted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Right Column: Volume & Controls ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: pageRoot.wideLayout ? (contentGrid.width - 16) / 2 : contentGrid.width
            spacing: 16

            SettingsCard {
                title: "Volume & Controls"
                subtitle: "Adjust volume levels and input capture"

                // ── Master Volume Section ──
                StyledText {
                    text: "Master Volume"
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                }

                SettingsSliderRow {
                    label: "Volume level"
                    description: Audio.sink ? Audio.displayName(Audio.sink) : "No output device"
                    value: Audio.sink?.audio.muted ? 0 : (Audio.sink?.audio.volume ?? 0)
                    from: 0
                    to: 1
                    formatValue: val => `${Math.round(val * 100)}%`
                    onMoved: {
                        if (Audio.sink && !Audio.sink.audio.muted)
                            Audio.sink.audio.volume = value
                    }
                }

                SettingsToggleRow {
                    label: "Mute output"
                    description: "Mute all audio output"
                    checked: Audio.sink?.audio.muted ?? false
                    onToggled: Audio.toggleMute()
                }

                ButtonRow {
                    SettingsButton {
                        label: "Cycle Output Device"
                        iconName: "swap_horiz"
                        onClicked: Audio.cycleAudioOutput()
                    }
                    SettingsButton {
                        label: "Volume Control"
                        iconName: "open_in_new"
                        onClicked: { pageRoot.settingsRoot.dismiss(); Quickshell.execDetached(["pavucontrol"]) }
                    }
                }

                // Divider between Master Volume and Microphone
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                    opacity: 0.4
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                }

                // ── Microphone Section ──
                StyledText {
                    text: "Microphone"
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                }

                SettingsSliderRow {
                    label: "Input volume"
                    description: Audio.source ? Audio.displayName(Audio.source) : "No input device"
                    value: Audio.source?.audio.muted ? 0 : (Audio.source?.audio.volume ?? 0)
                    from: 0
                    to: 1
                    formatValue: val => `${Math.round(val * 100)}%`
                    onMoved: {
                        if (Audio.source && !Audio.source.audio.muted)
                            Audio.source.audio.volume = value
                    }
                }

                SettingsToggleRow {
                    label: "Mute microphone"
                    description: "Mute microphone input"
                    checked: Audio.source?.audio.muted ?? false
                    onToggled: Audio.toggleMicMute()
                }
            }
        }
    }
}
