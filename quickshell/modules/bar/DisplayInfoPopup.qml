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
    signal manageRequested

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    readonly property color tuiBg: TuiStyle.bg
    readonly property color tuiPanel: TuiStyle.panel
    readonly property color tuiPanelAlt: TuiStyle.panelAlt
    readonly property color tuiFg: TuiStyle.fg
    readonly property color tuiDim: TuiStyle.dim
    readonly property color tuiLine: TuiStyle.line
    readonly property color tuiGreen: TuiStyle.green
    readonly property color tuiYellow: TuiStyle.yellow
    readonly property color tuiBlue: TuiStyle.blue
    readonly property color tuiPurple: TuiStyle.purple
    readonly property color tuiRed: TuiStyle.red

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

                    TuiMeterBar {
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

                    TuiDetailRow {
                        keyText: "NIGHTLIGHT"
                        valueText: root.nightLightOn ? "ON" : "OFF"
                        valueColor: root.nightLightOn ? root.tuiYellow : root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "COLOR TEMP"
                        valueText: root.nightLightOn ? `${root.colorTemp}K` : "--"
                        valueColor: root.nightLightOn ? root.tuiYellow : root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "GAMMA"
                        valueText: `${root.gamma}%`
                        valueColor: root.gamma < 100 ? root.tuiPurple : root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "MODE"
                        valueText: root.automatic ? "auto" : "manual"
                        valueColor: root.tuiDim
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    TuiDetailRow {
                        keyText: "SCREENS"
                        valueText: `${root.screenCount}`
                        valueColor: root.tuiGreen
                    }

                    Repeater {
                        model: root.screens
                        TuiDetailRow {
                            required property var modelData
                            keyText: `  ${modelData.name}`
                            valueText: root.screenResolution(modelData)
                            valueColor: root.tuiFg
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: TuiStyle.borderWidth
                        color: root.tuiLine
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        TuiActionButton {
                            label: "SETTINGS"
                            accent: root.tuiGreen
                            onClicked: {
                                root.manageRequested();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

}
