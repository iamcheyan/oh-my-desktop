import qs
import qs.core.runtime
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

ColumnLayout {
    id: pageRoot
    property var settingsRoot: null

    readonly property bool wideLayout: width >= 980
    width: parent ? parent.width : 900
    spacing: SettingsTokens.controlGap
    implicitHeight: {
        const viewportHeight = pageRoot.settingsRoot ? pageRoot.settingsRoot.height - 120 : 500;
        const contentHeight = contentGrid.implicitHeight + 50 + spacing + 12;
        return Math.max(viewportHeight, contentHeight);
    }

    function safeVolume(node) {
        const level = Number(node?.audio?.volume ?? 0);
        return Number.isFinite(level) ? level : 0;
    }

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: pageRoot.wideLayout ? 2 : 1
        columnSpacing: SettingsTokens.columnGap
        rowSpacing: SettingsTokens.columnGap

        // ── Left Column: Audio Devices ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout ? (contentGrid.width - SettingsTokens.columnGap) / 2 : contentGrid.width
            implicitHeight: leftColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 68

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: SettingsTokens.radius
                            color: SettingsTokens.accentSoft

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "speaker"
                                iconSize: 25
                                color: SettingsTokens.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: "Audio devices"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: `${ServiceManager.audio.typedSinks.length} output${ServiceManager.audio.typedSinks.length === 1 ? "" : "s"}  ·  ${ServiceManager.audio.typedSources.length} input${ServiceManager.audio.typedSources.length === 1 ? "" : "s"}`
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                // ── Output Devices Section ──
                SettingsSection {
                    title: "Output devices"

                // Loading overlay for WirePlumber reload
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    visible: ServiceManager.audio.wireplumberReloading
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
                                running: ServiceManager.audio.wireplumberReloading
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
                    model: ServiceManager.audio.typedSinks
                    delegate: ColumnLayout {
                        id: sinkDelegate
                        required property var modelData
                        readonly property var node: modelData
                        readonly property bool isActive: ServiceManager.audio.sink?.name === node.name
                        readonly property bool hasAlias: ServiceManager.audio.hasDeviceAlias(node.name)
                        property bool editing: false
                        property string aliasText: ""

                        Layout.fillWidth: true
                        spacing: 6

                        // Device row
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: sinkDelegate.hasAlias ? 94 : 78
                            radius: SettingsTokens.radius
                            color: sinkDelegate.isActive ? SettingsTokens.accentSoft : (sinkRowMouse.containsMouse ? SettingsTokens.buttonHover : "transparent")
                            border.width: sinkDelegate.isActive ? 1 : 0
                            border.color: SettingsTokens.accent

                            MouseArea {
                                id: sinkRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceManager.audio.setDefaultSink(sinkDelegate.node)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
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
                                            text: ServiceManager.audio.displayName(sinkDelegate.node)
                                            color: SettingsTokens.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: sinkDelegate.isActive ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: sinkDelegate.hasAlias ? ServiceManager.audio.originalName(sinkDelegate.node) : ""
                                            visible: sinkDelegate.hasAlias
                                            color: SettingsTokens.dim
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            elide: Text.ElideRight
                                        }
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
                                                sinkDelegate.aliasText = ServiceManager.audio.getDeviceAlias(sinkDelegate.node.name) || ""
                                                sinkDelegate.editing = true
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 32
                                    spacing: 12

                                    SettingsSlider {
                                        Layout.fillWidth: true
                                        value: pageRoot.safeVolume(sinkDelegate.node)
                                        onMoved: {
                                            if (sinkDelegate.node?.audio)
                                                sinkDelegate.node.audio.volume = value
                                        }
                                    }

                                    StyledText {
                                        Layout.preferredWidth: 48
                                        text: `${Math.round(pageRoot.safeVolume(sinkDelegate.node) * 100)}%`
                                        color: SettingsTokens.muted
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        horizontalAlignment: Text.AlignRight
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
                                        ServiceManager.audio.setDeviceAlias(sinkDelegate.node.name, sinkDelegate.aliasText)
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
                                            ServiceManager.audio.setDeviceAlias(sinkDelegate.node.name, sinkDelegate.aliasText)
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
                                            ServiceManager.audio.removeDeviceAlias(sinkDelegate.node.name)
                                            sinkDelegate.editing = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }

                // ── Input Devices Section ──
                SettingsSection {
                    title: "Input devices"
                    visible: ServiceManager.audio.typedSources.length > 0

                    Repeater {
                        model: ServiceManager.audio.typedSources
                        delegate: ColumnLayout {
                        id: sourceDelegate
                        required property var modelData
                        readonly property var node: modelData
                        readonly property bool isActive: ServiceManager.audio.source?.name === node.name

                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 78
                            radius: SettingsTokens.radius
                            color: sourceDelegate.isActive ? SettingsTokens.accentSoft : (sourceRowMouse.containsMouse ? SettingsTokens.buttonHover : "transparent")
                            border.width: sourceDelegate.isActive ? 1 : 0
                            border.color: SettingsTokens.accent

                            MouseArea {
                                id: sourceRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ServiceManager.audio.setDefaultSource(sourceDelegate.node)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    MaterialSymbol {
                                        text: sourceDelegate.isActive ? "check_circle" : "radio_button_unchecked"
                                        iconSize: 18
                                        color: sourceDelegate.isActive ? SettingsTokens.accent : SettingsTokens.muted
                                        Layout.preferredWidth: 22
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: ServiceManager.audio.displayName(sourceDelegate.node)
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sourceDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 32
                                    spacing: 12

                                    SettingsSlider {
                                        Layout.fillWidth: true
                                        value: pageRoot.safeVolume(sourceDelegate.node)
                                        onMoved: {
                                            if (sourceDelegate.node?.audio)
                                                sourceDelegate.node.audio.volume = value
                                        }
                                    }

                                    StyledText {
                                        Layout.preferredWidth: 48
                                        text: `${Math.round(pageRoot.safeVolume(sourceDelegate.node) * 100)}%`
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

                Item { Layout.fillHeight: true }
            }
        }

        // ── Right Column: Volume & Controls ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout ? (contentGrid.width - SettingsTokens.columnGap) / 2 : contentGrid.width
            implicitHeight: rightColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: rightColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 68

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: SettingsTokens.radius
                            color: SettingsTokens.accentSoft

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: ServiceManager.audio.sink?.audio.muted ? "volume_off" : "volume_up"
                                iconSize: 25
                                color: SettingsTokens.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: "Volume & controls"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: ServiceManager.audio.sink ? ServiceManager.audio.displayName(ServiceManager.audio.sink) : "No output device"
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                // ── Master Volume Section ──
                SettingsSection {
                    title: "Master volume"

                SettingsSliderRow {
                    label: "Volume level"
                    description: ServiceManager.audio.sink ? ServiceManager.audio.displayName(ServiceManager.audio.sink) : "No output device"
                    value: ServiceManager.audio.sink?.audio.muted ? 0 : pageRoot.safeVolume(ServiceManager.audio.sink)
                    from: 0
                    to: 1
                    formatValue: val => `${Math.round(val * 100)}%`
                    onMoved: {
                        if (ServiceManager.audio.sink && !ServiceManager.audio.sink.audio.muted)
                            ServiceManager.audio.sink.audio.volume = value
                    }
                }

                SettingsToggleRow {
                    label: "Mute output"
                    description: "Mute all audio output"
                    checked: ServiceManager.audio.sink?.audio.muted ?? false
                    onToggled: ServiceManager.audio.toggleMute()
                }

                ButtonRow {
                    SettingsButton {
                        label: "Cycle Output Device"
                        iconName: "swap_horiz"
                        onClicked: ServiceManager.audio.cycleAudioOutput()
                    }
                    SettingsButton {
                        label: "Volume Control"
                        iconName: "open_in_new"
                        onClicked: {
                            pageRoot.settingsRoot.dismiss()
                            ActionManager.invoke("settings.open", {page: "sound"})
                        }
                    }
                }
                }

                // ── Microphone Section ──
                SettingsSection {
                    title: "Microphone"

                SettingsSliderRow {
                    label: "Input volume"
                    description: ServiceManager.audio.source ? ServiceManager.audio.displayName(ServiceManager.audio.source) : "No input device"
                    value: ServiceManager.audio.source?.audio.muted ? 0 : pageRoot.safeVolume(ServiceManager.audio.source)
                    from: 0
                    to: 1
                    formatValue: val => `${Math.round(val * 100)}%`
                    onMoved: {
                        if (ServiceManager.audio.source && !ServiceManager.audio.source.audio.muted)
                            ServiceManager.audio.source.audio.volume = value
                    }
                }

                SettingsToggleRow {
                    label: "Mute microphone"
                    description: "Mute microphone input"
                    checked: ServiceManager.audio.source?.audio.muted ?? false
                    onToggled: ServiceManager.audio.toggleMicMute()
                }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
