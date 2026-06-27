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

    function btStateLabel() {
        if (!BluetoothStatus.available)
            return "unavailable";
        if (!BluetoothStatus.enabled)
            return "disabled";
        if (!BluetoothStatus.connected)
            return "on";
        return "connected";
    }

    function stateTone(state) {
        if (state === "connected")
            return root.tuiGreen;
        if (state === "on")
            return root.tuiBlue;
        if (state === "disabled")
            return root.tuiRed;
        return root.tuiDim;
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
                    border.color: root.stateTone(root.btStateLabel())

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8

                        StyledText {
                            text: "BLUETOOTH"
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
                            text: root.btStateLabel().toUpperCase()
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.stateTone(root.btStateLabel())
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
                            name: BluetoothStatus.connected ? "status/bluetooth-active-symbolic" : BluetoothStatus.enabled ? "devices/bluetooth-symbolic" : "status/bluetooth-disabled-symbolic"
                            iconSize: 24
                            color: root.stateTone(root.btStateLabel())
                        }

                        StyledText {
                            text: BluetoothStatus.connected
                                ? `${BluetoothStatus.activeDeviceCount} device${BluetoothStatus.activeDeviceCount !== 1 ? "s" : ""}`
                                : BluetoothStatus.available ? "No connections" : "No adapter"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: root.tuiFg
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    TuiDetailRow {
                        keyText: "STATE"
                        valueText: root.btStateLabel()
                        valueColor: root.stateTone(root.btStateLabel())
                    }

                    TuiDetailRow {
                        keyText: "ADAPTER"
                        valueText: BluetoothStatus.available ? "present" : "missing"
                        valueColor: BluetoothStatus.available ? root.tuiGreen : root.tuiRed
                    }

                    TuiDetailRow {
                        keyText: "ENABLED"
                        valueText: BluetoothStatus.enabled ? "yes" : "no"
                        valueColor: BluetoothStatus.enabled ? root.tuiGreen : root.tuiRed
                    }

                    TuiDetailRow {
                        keyText: "DEVICES"
                        valueText: `${BluetoothStatus.friendlyDeviceList?.length ?? 0} total`
                        valueColor: root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "PAIRED"
                        valueText: `${BluetoothStatus.pairedButNotConnectedDevices?.length ?? 0}`
                        valueColor: root.tuiYellow
                    }

                    TuiDetailRow {
                        keyText: "UNPAIRED"
                        valueText: `${BluetoothStatus.unpairedDevices?.length ?? 0}`
                        valueColor: root.tuiDim
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                        visible: BluetoothStatus.connectedDevices.length > 0
                    }

                    Repeater {
                        model: BluetoothStatus.connectedDevices.slice(0, 5)
                        delegate: TuiDetailRow {
                            required property var modelData
                            keyText: "DEV"
                            valueText: modelData?.name || "Unknown"
                            valueColor: root.tuiGreen
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

}