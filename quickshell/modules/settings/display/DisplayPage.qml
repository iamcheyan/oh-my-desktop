import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

ColumnLayout {
    id: root

    property var brightnessMonitor: ({ brightness: 0, setBrightness: function(){} })
    property var settingsRoot: null

    width: parent ? parent.width : 760
    spacing: 18
    implicitHeight: content.implicitHeight

    DisplayConfigState {
        id: configState
    }

    property string optimizationMode: Persistent.ready ? (Persistent.states.display?.optimization ?? "balanced") : "balanced"

    function applyOptimization(mode) {
        if (!Persistent.ready) return;
        Persistent.states.display.optimization = mode;

        let evalStr = "";
        if (mode === "performance") {
            evalStr = "hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })";
        } else if (mode === "balanced") {
            evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 1 } }, animations = { enabled = true } })";
        } else if (mode === "visuals") {
            evalStr = "hl.config({ decoration = { blur = { enabled = true, passes = 2 } }, animations = { enabled = true } })";
        }

        if (evalStr !== "") {
            Quickshell.execDetached(["hyprctl", "eval", evalStr]);
        }
    }

    component SettingsSlider: Slider {
        id: sliderRoot
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        leftPadding: 0
        rightPadding: 0

        background: Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: sliderRoot.width
            height: 6
            radius: 3
            color: SettingsTokens.line

            Rectangle {
                width: sliderRoot.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: SettingsTokens.accent
            }
        }

        handle: Rectangle {
            x: sliderRoot.visualPosition * (sliderRoot.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: SettingsTokens.fg
            border.width: 2
            border.color: sliderRoot.pressed ? SettingsTokens.accent : SettingsTokens.buttonBorder
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }
    }

    ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: 18

        PanelCard {
            Layout.fillWidth: true
            title: "Display layout"
            subtitle: configState.refreshing ? "Reading Hyprland outputs..." : `${configState.outputs.length} output(s)`

            MonitorCanvas {
                Layout.fillWidth: true
                displayState: configState
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Identify"
                    iconName: "badge"
                    onClicked: configState.identify()
                }
                SmallButton {
                    text: "Refresh"
                    iconName: "refresh"
                    onClicked: configState.refresh()
                }
                Item { Layout.fillWidth: true }
                SmallButton {
                    text: "Apply all"
                    iconName: "check"
                    primary: true
                    enabled: configState.hasPendingChanges && !configState.applying
                    onClicked: configState.applyAll()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: configState.errorText.length > 0
                text: configState.errorText
                color: SettingsTokens.fg
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Outputs"
            subtitle: configState.hasPendingChanges ? "Pending changes" : "Current configuration"

            Repeater {
                model: configState.outputs

                OutputCard {
                    required property var modelData
                    displayState: configState
                    output: modelData
                }
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Brightness"
            subtitle: `${Math.round(root.brightnessMonitor.brightness * 100)}%`

            SettingsSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                stepSize: 0.01
                value: root.brightnessMonitor.brightness
                onMoved: root.brightnessMonitor.setBrightness(value)
            }

            ToggleLine {
                title: "Brightness OSD"
                description: "Show on-screen display when brightness changes"
                checked: Config.options.osd.brightnessEnabled ?? true
                onToggled: Config.setNestedValue("osd.brightnessEnabled", !Config.options.osd.brightnessEnabled)
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Night light"
            subtitle: Hyprsunset.temperatureActive ? "Active" : "Inactive"

            ToggleLine {
                title: "Night light"
                description: "Reduce blue light for warmer colors"
                checked: Hyprsunset.temperatureActive
                onToggled: Hyprsunset.toggleTemperature(!Hyprsunset.temperatureActive)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                StyledText {
                    text: "Color temperature"
                    color: SettingsTokens.fg
                    font.pixelSize: 14
                }
                SettingsSlider {
                    Layout.fillWidth: true
                    from: 2500
                    to: 6500
                    stepSize: 100
                    value: Config.options.light.night.colorTemperature ?? 6000
                    onMoved: Config.setNestedValue("light.night.colorTemperature", Math.round(value))
                }
                StyledText {
                    text: `${Config.options.light.night.colorTemperature ?? 6000}K`
                    color: SettingsTokens.dim
                    font.pixelSize: 13
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Performance & Effects"
            subtitle: {
                const mode = root.optimizationMode;
                return mode === "performance" ? "High Performance" : mode === "balanced" ? "Balanced" : "Best Visuals";
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                SmallButton {
                    Layout.fillWidth: true
                    text: "High Perf"
                    iconName: "speed"
                    primary: root.optimizationMode === "performance"
                    onClicked: root.applyOptimization("performance")
                }
                SmallButton {
                    Layout.fillWidth: true
                    text: "Balanced"
                    iconName: "balance"
                    primary: root.optimizationMode === "balanced"
                    onClicked: root.applyOptimization("balanced")
                }
                SmallButton {
                    Layout.fillWidth: true
                    text: "Best Visuals"
                    iconName: "palette"
                    primary: root.optimizationMode === "visuals"
                    onClicked: root.applyOptimization("visuals")
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.optimizationMode === "performance"
                    ? "🏎️ High Performance: Frosted glass blur effect is disabled for maximum UI smoothness and battery life."
                    : root.optimizationMode === "balanced"
                        ? "⚖️ Balanced: 1 blur pass enabled. High-quality frosted glass look with 50% GPU load reduction (best for integrated GPUs)."
                        : "✨ Best Visuals: 2 blur passes enabled. Full-resolution premium glass aesthetics (best for dedicated GPUs)."
                color: SettingsTokens.dim
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }

    }

    component PanelCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        default property alias content: body.data

        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 34
        radius: TuiStyle.radius
        color: SettingsTokens.card
        border.width: 1
        border.color: SettingsTokens.line

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 17
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                StyledText {
                    Layout.fillWidth: true
                    text: card.title
                    color: SettingsTokens.fg
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: card.subtitle
                    color: SettingsTokens.dim
                    font.pixelSize: 13
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: SettingsTokens.line
                opacity: TuiStyle.dividerOpacity
                visible: body.children.length > 0
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 14
            }
        }
    }

    component SmallButton: Rectangle {
        id: button
        property string text: ""
        property string iconName: ""
        property bool primary: false
        signal clicked

        Layout.preferredHeight: 42
        implicitWidth: label.implicitWidth + 64
        radius: 13
        color: !enabled ? SettingsTokens.bg : primary ? TuiStyle.accentWash(TuiStyle.accent) : (mouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button)
        border.width: 1
        border.color: primary ? SettingsTokens.accent : SettingsTokens.buttonBorder
        opacity: enabled ? 1 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 9
            MaterialSymbol {
                text: button.iconName
                iconSize: 19
                color: primary ? SettingsTokens.accent : SettingsTokens.fg
            }
            StyledText {
                id: label
                text: button.text
                color: SettingsTokens.fg
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    component ToggleLine: RowLayout {
        id: toggleLine
        property string title: ""
        property string description: ""
        property bool checked: false
        signal toggled

        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText { text: toggleLine.title; color: SettingsTokens.fg; font.pixelSize: 14; font.weight: Font.DemiBold }
            StyledText { text: toggleLine.description; color: SettingsTokens.dim; font.pixelSize: 13 }
        }
        Switch {
            id: control
            checked: toggleLine.checked
            onToggled: toggleLine.toggled()

            indicator: Rectangle {
                implicitWidth: 46
                implicitHeight: 26
                x: control.leftPadding
                y: parent.height / 2 - height / 2
                radius: height / 2
                color: control.checked ? SettingsTokens.accent : SettingsTokens.line

                Rectangle {
                    x: control.checked ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: control.checked ? "#111111" : "#dedede"
                    Behavior on x { NumberAnimation { duration: 110 } }
                }
            }
        }
    }
}
