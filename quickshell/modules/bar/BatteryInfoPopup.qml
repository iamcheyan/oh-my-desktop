pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

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
    readonly property color tuiRed: TuiStyle.red

    function formatBatteryTime(seconds) {
        if (!Battery.available || seconds <= 0)
            return "--";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    function batteryStateLabel() {
        if (!Battery.available)
            return "unavailable";
        if (Battery.isCharging)
            return "charging";
        if (Battery.isPluggedIn)
            return "plugged";
        return "battery";
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
                    border.color: Battery.isLowAndNotCharging ? root.tuiRed : Battery.isCharging ? root.tuiYellow : root.tuiGreen

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8

                        StyledText {
                            text: "BATTERY"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.tuiBlue
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
                        }

                        StyledText {
                            text: root.batteryStateLabel().toUpperCase()
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Battery.isCharging ? root.tuiYellow : Battery.isLowAndNotCharging ? root.tuiRed : root.tuiGreen
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

                        MaterialSymbol {
                            text: Battery.isCharging ? "bolt" : "battery_android_full"
                            iconSize: 28
                            color: Battery.isLowAndNotCharging ? root.tuiRed : root.tuiGreen
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.Bold
                            color: Battery.isLowAndNotCharging ? root.tuiRed : root.tuiFg
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: Battery.available ? `${Battery.energyRate.toFixed(1)}W` : "--"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.tuiBlue
                        }
                    }

                    TuiMeterBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        value: Battery.available ? Battery.percentage * 100 : 0
                        accent: Battery.isLowAndNotCharging ? root.tuiRed : Battery.isCharging ? root.tuiYellow : root.tuiGreen
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    TuiDetailRow {
                        keyText: "STATE"
                        valueText: root.batteryStateLabel()
                        valueColor: Battery.isCharging ? root.tuiYellow : root.tuiGreen
                    }

                    TuiDetailRow {
                        keyText: Battery.isCharging ? "TO FULL" : "TO EMPTY"
                        valueText: root.formatBatteryTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty)
                        valueColor: root.tuiFg
                    }

                    TuiDetailRow {
                        keyText: "HEALTH"
                        valueText: Battery.available && Battery.health > 0 ? `${Battery.health.toFixed(1)}%` : "--"
                        valueColor: Battery.health > 0 && Battery.health < 80 ? root.tuiYellow : root.tuiGreen
                    }

                    TuiDetailRow {
                        keyText: "PROFILE"
                        valueText: PowerProfiles.available ? PowerProfiles.currentProfile : "unavailable"
                        valueColor: PowerProfiles.currentProfile === "performance" ? root.tuiRed
                            : PowerProfiles.currentProfile === "balanced" ? root.tuiYellow
                            : PowerProfiles.currentProfile === "power-saver" ? root.tuiGreen
                            : root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "LOW"
                        valueText: `${Config.options.battery.low}%`
                        valueColor: root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "CRITICAL"
                        valueText: `${Config.options.battery.critical}%`
                        valueColor: root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "SUSPEND"
                        valueText: Config.options.battery.automaticSuspend ? `${Config.options.battery.suspend}s` : "off"
                        valueColor: Config.options.battery.automaticSuspend ? root.tuiYellow : root.tuiDim
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
                            label: "POWER"
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
