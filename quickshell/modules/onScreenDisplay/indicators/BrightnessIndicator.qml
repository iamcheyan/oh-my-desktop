import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiYellow: "#e8ff82"

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)
    readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0

    implicitWidth: 300 + Appearance.sizes.elevationMargin * 2
    implicitHeight: popupBg.implicitHeight + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: popupBg
    }

    Rectangle {
        id: popupBg
        readonly property real innerPad: 12
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }

        color: root.tuiBg
        radius: Appearance.tiling.dialogRadius
        border.width: Appearance.tiling.borderWidth
        border.color: root.tuiLine
        clip: true

        implicitWidth: 300 + innerPad * 2
        implicitHeight: popupCol.implicitHeight + innerPad * 2

        ColumnLayout {
            id: popupCol
            anchors {
                fill: parent
                margins: popupBg.innerPad
            }
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: root.tuiPanel
                border.width: 1
                border.color: root.tuiYellow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    StyledText {
                        text: "BRIGHTNESS"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.tuiYellow
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    StyledText {
                        text: `${Math.round(root.brightnessValue * 100)}%`
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: root.tuiYellow
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 12

                CosmicIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "status/display-brightness-symbolic"
                    iconSize: 24
                    color: root.tuiYellow
                }

                StyledText {
                    text: `${Math.round(root.brightnessValue * 100)}%`
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: root.tuiFg
                }

                Item { Layout.fillWidth: true }
            }

            MeterBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                Layout.topMargin: 10
                Layout.bottomMargin: 14
                value: root.brightnessValue * 100
                accent: root.tuiYellow
            }
        }
    }

    component MeterBar: Row {
        id: meter

        property real value: 0
        property color accent: root.tuiYellow

        spacing: 3
        Repeater {
            model: 14
            Rectangle {
                required property int index
                width: Math.max(8, (meter.width - 39) / 14)
                height: meter.height
                color: index < Math.ceil(Math.max(0, Math.min(100, meter.value)) / 100 * 14) ? meter.accent : root.tuiLine
            }
        }
    }
}