import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root

    readonly property color tuiBg: "#000000"
    readonly property color tuiFg: "#f8f8f2"
    readonly property color tuiDim: "#8a8a8a"
    readonly property color tuiGreen: "#32ff6a"
    readonly property color tuiYellow: "#f1fa8c"
    readonly property color tuiBlue: "#8ec7ff"
    readonly property color tuiPurple: "#c792ea"
    readonly property color tuiSelection: "#687bad"
    readonly property string activeName: Network.active?.ssid || Network.networkName || Translation.tr("none")
    readonly property string statusText: Network.wifiScanning ? Translation.tr("scanning") : Network.wifiStatus

    function openSettings() {
        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
    }

    backgroundWidth: Math.min(860, Math.max(680, width - 32))
    backgroundHeight: Math.min(660, Math.max(500, height - 96))
    anchorPosition: 0

    component TuiText: StyledText {
        color: root.tuiFg
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        textFormat: Text.PlainText
    }

    component TuiSection: Item {
        id: section

        required property string title
        property color borderColor: root.tuiGreen
        default property alias content: sectionContent.data

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 10
            color: root.tuiBg
            border.width: 2
            border.color: section.borderColor
        }

        Rectangle {
            x: 18
            y: 0
            height: 22
            width: sectionTitle.implicitWidth + 20
            color: root.tuiBg

            TuiText {
                id: sectionTitle
                anchors.centerIn: parent
                text: section.title
                color: section.borderColor
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
            }
        }

        Item {
            id: sectionContent
            anchors.fill: parent
            anchors.topMargin: 24
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            networkList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            networkList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            Network.rescanWifi();
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            root.openSettings();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const item = networkList.currentItem;
            if (item?.wifiNetwork)
                Network.connectToWifiNetwork(item.wifiNetwork);
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
            Network.rescanWifi();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: root.tuiBg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            TuiSection {
                title: Translation.tr("Wi-Fi Networks")
                Layout.fillWidth: true
                Layout.fillHeight: true
                borderColor: root.tuiGreen

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 8

                        TuiText {
                            Layout.preferredWidth: 220
                            text: "Name"
                            color: root.tuiYellow
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }

                        TuiText {
                            Layout.preferredWidth: 88
                            text: "Signal"
                            color: root.tuiYellow
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }

                        TuiText {
                            Layout.preferredWidth: 64
                            text: "Band"
                            color: root.tuiYellow
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }

                        TuiText {
                            Layout.fillWidth: true
                            text: "Security"
                            color: root.tuiYellow
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: Network.friendlyWifiNetworks.length > 0 ? 0 : 1

                        ListView {
                            id: networkList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 0
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 80
                            keyNavigationEnabled: true
                            model: ScriptModel {
                                values: Network.friendlyWifiNetworks
                            }
                            delegate: WifiNetworkItem {
                                required property WifiAccessPoint modelData
                                wifiNetwork: modelData
                                width: ListView.view.width
                                selectionColor: root.tuiSelection
                                foregroundColor: root.tuiFg
                                dimColor: root.tuiDim
                                greenColor: root.tuiGreen
                                blueColor: root.tuiBlue
                                bgColor: root.tuiBg
                            }
                        }

                        Rectangle {
                            color: "transparent"

                            TuiText {
                                anchors.centerIn: parent
                                text: Network.wifiScanning
                                    ? Translation.tr("scanning for networks...")
                                    : Translation.tr("no networks found")
                                color: root.tuiDim
                            }
                        }
                    }
                }
            }

            TuiSection {
                title: Translation.tr("Adapter")
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                borderColor: root.tuiFg

                GridLayout {
                    anchors.fill: parent
                    columns: 4
                    rowSpacing: 14
                    columnSpacing: 24

                    TuiText { text: "Name"; color: root.tuiFg; font.weight: Font.Bold }
                    TuiText { text: "Connection"; color: root.tuiFg; font.weight: Font.Bold }
                    TuiText { text: "Power"; color: root.tuiFg; font.weight: Font.Bold }
                    TuiText { text: "State"; color: root.tuiFg; font.weight: Font.Bold }

                    TuiText { text: "wld0"; color: root.tuiFg }
                    TuiText {
                        Layout.fillWidth: true
                        text: root.activeName
                        elide: Text.ElideRight
                        color: Network.wifiStatus === "connected" ? root.tuiFg : root.tuiDim
                    }
                    TuiText {
                        text: Network.wifiEnabled ? "On" : "Off"
                        color: Network.wifiEnabled ? root.tuiGreen : Appearance.tiling.error
                    }
                    TuiText {
                        text: root.statusText
                        color: Network.wifiStatus === "connected" ? root.tuiGreen
                            : Network.wifiStatus === "disabled" ? Appearance.tiling.error
                            : root.tuiYellow
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                spacing: 18
                layoutDirection: Qt.LeftToRight

                TuiText { text: "↵ connect"; color: root.tuiPurple }
                TuiText { text: "r rescan"; color: root.tuiPurple }
                TuiText { text: "k,↑ up"; color: root.tuiPurple }
                TuiText { text: "j,↓ down"; color: root.tuiPurple }
                TuiText { text: "s settings"; color: root.tuiPurple }
                TuiText { text: "esc close"; color: root.tuiPurple }
            }
        }
    }
}
