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
    readonly property color tuiAccent: TuiStyle.accent
    readonly property color tuiYellow: TuiStyle.yellow
    readonly property color tuiBlue: TuiStyle.blue
    readonly property color tuiPurple: TuiStyle.purple
    readonly property color tuiRed: TuiStyle.red

    function wifiStateLabel() {
        if (Network.ethernet)
            return "wired";
        if (!Network.wifiEnabled || Network.wifiStatus === "disabled")
            return "disabled";
        if (Network.wifiStatus === "connected")
            return "connected";
        if (Network.wifiStatus === "connecting")
            return "connecting";
        if (Network.wifiStatus === "limited")
            return "limited";
        return "disconnected";
    }

    function stateTone(state) {
        if (state === "connected" || state === "wired")
            return root.tuiAccent;
        if (state === "connecting")
            return root.tuiYellow;
        if (state === "limited")
            return root.tuiYellow;
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
                    border.color: root.stateTone(root.wifiStateLabel())

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 8

                        StyledText {
                            text: Network.ethernet ? "ETHERNET" : "WI-FI"
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
                            text: root.wifiStateLabel().toUpperCase()
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.stateTone(root.wifiStateLabel())
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
                            name: Network.cosmicIcon
                            iconSize: 24
                            color: root.stateTone(root.wifiStateLabel())
                        }

                        StyledText {
                            text: Network.ethernet ? (Network.networkName || "Wired") : (Network.active?.ssid || Network.networkName || "No network")
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: root.tuiFg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: !Network.ethernet && Network.wifiStatus === "connected"
                            text: Number.isFinite(Network.active?.strength ?? Network.networkStrength)
                                ? `${Network.active?.strength ?? Network.networkStrength}%` : ""
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.tuiBlue
                        }
                    }

                    TuiMeterBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        visible: !Network.ethernet && Network.wifiStatus === "connected"
                        value: (Network.active?.strength ?? Network.networkStrength) ?? 0
                        accent: root.tuiBlue
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    TuiDetailRow {
                        keyText: "STATE"
                        valueText: root.wifiStateLabel()
                        valueColor: root.stateTone(root.wifiStateLabel())
                    }

                    TuiDetailRow {
                        keyText: "INTERFACE"
                        valueText: Network.ethernet ? "ethernet" : "wi-fi"
                        valueColor: root.tuiFg
                    }

                    TuiDetailRow {
                        keyText: "SSID"
                        valueText: Network.ethernet ? (Network.networkName || "--") : (Network.active?.ssid || Network.networkName || "--")
                        valueColor: root.tuiFg
                    }

                    TuiDetailRow {
                        keyText: "SIGNAL"
                        valueText: !Network.ethernet && Network.wifiStatus === "connected"
                            ? `${Network.active?.strength ?? Network.networkStrength}%` : "--"
                        valueColor: root.tuiBlue
                    }

                    TuiDetailRow {
                        keyText: "ENABLED"
                        valueText: Network.ethernet ? "yes" : (Network.wifiEnabled ? "yes" : "no")
                        valueColor: Network.ethernet || Network.wifiEnabled ? root.tuiAccent : root.tuiRed
                    }

                    TuiDetailRow {
                        keyText: "SCANNING"
                        valueText: Network.wifiScanning ? "yes" : "no"
                        valueColor: Network.wifiScanning ? root.tuiYellow : root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "NETWORKS"
                        valueText: `${Network.friendlyWifiNetworks.length}`
                        valueColor: root.tuiDim
                    }

                    TuiDetailRow {
                        keyText: "CONNECTING"
                        valueText: Network.wifiConnecting ? "yes" : "no"
                        valueColor: Network.wifiConnecting ? root.tuiYellow : root.tuiDim
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
                            label: "MANAGE"
                            accent: root.tuiAccent
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
