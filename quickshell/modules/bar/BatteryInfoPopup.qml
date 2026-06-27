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
    readonly property color tuiRed: "#ff6b8b"

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

                    MeterBar {
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

                    DetailRow {
                        keyText: "STATE"
                        valueText: root.batteryStateLabel()
                        valueColor: Battery.isCharging ? root.tuiYellow : root.tuiGreen
                    }

                    DetailRow {
                        keyText: Battery.isCharging ? "TO FULL" : "TO EMPTY"
                        valueText: root.formatBatteryTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty)
                        valueColor: root.tuiFg
                    }

                    DetailRow {
                        keyText: "HEALTH"
                        valueText: Battery.available && Battery.health > 0 ? `${Battery.health.toFixed(1)}%` : "--"
                        valueColor: Battery.health > 0 && Battery.health < 80 ? root.tuiYellow : root.tuiGreen
                    }

                    DetailRow {
                        keyText: "PROFILE"
                        valueText: PowerProfiles.available ? PowerProfiles.currentProfile : "unavailable"
                        valueColor: PowerProfiles.currentProfile === "performance" ? root.tuiRed
                            : PowerProfiles.currentProfile === "balanced" ? root.tuiYellow
                            : PowerProfiles.currentProfile === "power-saver" ? root.tuiGreen
                            : root.tuiDim
                    }

                    DetailRow {
                        keyText: "LOW"
                        valueText: `${Config.options.battery.low}%`
                        valueColor: root.tuiDim
                    }

                    DetailRow {
                        keyText: "CRITICAL"
                        valueText: `${Config.options.battery.critical}%`
                        valueColor: root.tuiDim
                    }

                    DetailRow {
                        keyText: "SUSPEND"
                        valueText: Config.options.battery.automaticSuspend ? `${Config.options.battery.suspend}s` : "off"
                        valueColor: Config.options.battery.automaticSuspend ? root.tuiYellow : root.tuiDim
                    }

                    Item { Layout.preferredHeight: 8 }
                }
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
            Layout.preferredWidth: 70
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
}
