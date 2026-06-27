pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root
    signal menuClosed

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiPanelAlt: "#091814"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiYellow: "#e8ff82"
    readonly property color tuiBlue: "#7bc7ff"
    readonly property color tuiPurple: "#c792ea"
    readonly property color tuiRed: "#ff6b8b"

    readonly property bool nightLightOn: Hyprsunset.temperatureActive
    readonly property int colorTemp: Hyprsunset.colorTemperature
    readonly property bool automatic: Hyprsunset.automatic
    readonly property int gamma: Hyprsunset.gamma
    readonly property var screens: Quickshell.screens
    readonly property int screenCount: screens.length
    property real wheelAccum: 0

    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])
    readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0

    function brightnessPercent() {
        return `${Math.round(root.brightnessValue * 100)}%`;
    }

    function screenResolution(screen) {
        return `${screen.width}x${screen.height}`;
    }

    implicitWidth: popupBg.implicitWidth + padding * 2
    implicitHeight: popupBg.implicitHeight + padding * 2

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
    }
    Component.onDestruction: {
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()

        StyledRectangularShadow {
            target: popupBg
            opacity: popupBg.opacity
        }

        Rectangle {
            id: popupBg
            readonly property real innerPad: 12
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.padding
            }

            color: root.tuiBg
            radius: Appearance.tiling.dialogRadius
            border.width: Appearance.tiling.borderWidth
            border.color: root.tuiLine
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: 300 + innerPad * 2
            implicitHeight: popupCol.implicitHeight + innerPad * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

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
                            text: "DISPLAY"
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
                            text: root.nightLightOn ? "NIGHT MODE" : "NORMAL"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.nightLightOn ? root.tuiYellow : root.tuiDim
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    anchors.margins: 14
                    spacing: 14

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
                            text: root.brightnessPercent()
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: root.tuiFg
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: "BRIGHTNESS"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.tuiYellow
                        }
                    }

                    MeterBar {
                        id: brightnessMeter
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        value: root.brightnessValue * 100
                        accent: root.tuiYellow

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.NoButton
                            onWheel: wheel => {
                                const r = WheelUtils.getSteps(wheel.angleDelta.y, root.wheelAccum)
                                root.wheelAccum = r.accum
                                for (let i = 0; i < Math.abs(r.steps); i++) {
                                    if (r.steps > 0)
                                        Brightness.increaseBrightness();
                                    else if (r.steps < 0)
                                        Brightness.decreaseBrightness();
                                }
                                wheel.accepted = true;
                            }
                            onPressed: {
                                const ratio = mouseX / width;
                                root.brightnessMonitor?.setBrightness(Math.max(0, Math.min(1, ratio)));
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    DetailRow {
                        keyText: "NIGHTLIGHT"
                        valueText: root.nightLightOn ? "ON" : "OFF"
                        valueColor: root.nightLightOn ? root.tuiYellow : root.tuiDim
                    }

                    DetailRow {
                        keyText: "COLOR TEMP"
                        valueText: root.nightLightOn ? `${root.colorTemp}K` : "--"
                        valueColor: root.nightLightOn ? root.tuiYellow : root.tuiDim
                    }

                    DetailRow {
                        keyText: "GAMMA"
                        valueText: `${root.gamma}%`
                        valueColor: root.gamma < 100 ? root.tuiPurple : root.tuiDim
                    }

                    DetailRow {
                        keyText: "MODE"
                        valueText: root.automatic ? "auto" : "manual"
                        valueColor: root.tuiDim
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    DetailRow {
                        keyText: "SCREENS"
                        valueText: `${root.screenCount}`
                        valueColor: root.tuiGreen
                    }

                    Repeater {
                        model: root.screens
                        DetailRow {
                            required property var modelData
                            keyText: `  ${modelData.name}`
                            valueText: root.screenResolution(modelData)
                            valueColor: root.tuiFg
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    component MeterBar: Row {
        id: meter

        property real value: 0
        property color accent: root.tuiGreen

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

    component DetailRow: RowLayout {
        property string keyText: ""
        property string valueText: ""
        property color valueColor: root.tuiFg

        Layout.fillWidth: true
        spacing: 10

        StyledText {
            Layout.preferredWidth: 80
            text: keyText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: root.tuiDim
        }

        StyledText {
            Layout.fillWidth: true
            text: valueText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            color: valueColor
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}