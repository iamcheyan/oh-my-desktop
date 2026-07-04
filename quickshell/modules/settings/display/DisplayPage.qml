import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property var brightnessMonitor: ({ brightness: 0, setBrightness: function(){} })

    width: parent ? parent.width : 760
    spacing: 18
    implicitHeight: content.implicitHeight

    DisplayConfigState {
        id: displayState
        onOutputsChanged: root.updateMonitorList()
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
            color: "#454545"

            Rectangle {
                width: sliderRoot.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: TuiStyle.accent
            }
        }

        handle: Rectangle {
            x: sliderRoot.visualPosition * (sliderRoot.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: "#f4f4f4"
            border.width: 2
            border.color: sliderRoot.pressed ? TuiStyle.accent : "#4a4a4a"
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
            subtitle: displayState.refreshing ? "Reading Hyprland outputs..." : `${displayState.outputs.length} output(s)`

            MonitorCanvas {
                Layout.fillWidth: true
                state: displayState
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Identify"
                    iconName: "badge"
                    onClicked: displayState.identify()
                }
                SmallButton {
                    text: "Refresh"
                    iconName: "refresh"
                    onClicked: displayState.refresh()
                }
                Item { Layout.fillWidth: true }
                SmallButton {
                    text: "Apply all"
                    iconName: "check"
                    primary: true
                    enabled: displayState.hasPendingChanges && !displayState.applying
                    onClicked: displayState.applyAll()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: displayState.errorText.length > 0
                text: displayState.errorText
                color: "#d8d8d8"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Outputs"
            subtitle: displayState.hasPendingChanges ? "Pending changes" : "Current configuration"

            Repeater {
                model: displayState.outputs

                OutputCard {
                    required property var modelData
                    state: displayState
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
                    color: "#f4f4f4"
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
                    color: "#a8a8a8"
                    font.pixelSize: 13
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Wallpaper"
            subtitle: "Single image or folder rotation"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                SmallButton {
                    Layout.fillWidth: true
                    text: "Choose image"
                    iconName: "image"
                    onClicked: Quickshell.execDetached(["bash", "-lc", "$HOME/.config/omd/bin/omd-wallpaper pick-file"])
                }
                SmallButton {
                    Layout.fillWidth: true
                    text: "Choose folder"
                    iconName: "folder"
                    onClicked: Quickshell.execDetached(["bash", "-lc", "$HOME/.config/omd/bin/omd-wallpaper pick-folder"])
                }
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
        radius: 18
        color: "#1b1b1b"
        border.width: 1
        border.color: "#303030"

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
                    color: "#f4f4f4"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: card.subtitle
                    color: "#a8a8a8"
                    font.pixelSize: 13
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#363636"
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
        color: !enabled ? "#202020" : primary ? TuiStyle.accentWash(TuiStyle.accent) : (mouse.containsMouse ? "#373737" : "#292929")
        border.width: 1
        border.color: primary ? TuiStyle.accent : "#4a4a4a"
        opacity: enabled ? 1 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 9
            MaterialSymbol {
                text: button.iconName
                iconSize: 19
                color: primary ? TuiStyle.accent : "#f4f4f4"
            }
            StyledText {
                id: label
                text: button.text
                color: "#f4f4f4"
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
            StyledText { text: toggleLine.title; color: "#f4f4f4"; font.pixelSize: 14; font.weight: Font.DemiBold }
            StyledText { text: toggleLine.description; color: "#8f8f8f"; font.pixelSize: 13 }
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
                color: control.checked ? TuiStyle.accent : "#454545"

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
