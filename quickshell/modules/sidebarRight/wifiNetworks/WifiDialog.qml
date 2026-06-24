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

    readonly property string statusText: Network.wifiScanning
        ? Translation.tr("scanning")
        : Network.wifiStatus
    readonly property string activeName: Network.active?.ssid || Network.networkName || Translation.tr("none")

    backgroundWidth: Math.min(700, Math.max(520, width - 32))
    backgroundHeight: Math.min(620, Math.max(440, height - 96))
    anchorPosition: 0

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
        implicitHeight: 30
        color: Appearance.tiling.bgTitlebar

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            StyledText {
                text: "omd-wifi"
                color: Appearance.tiling.textBright
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
            }

            StyledText {
                text: `[${root.statusText}]`
                color: Network.wifiStatus === "connected" ? Appearance.tiling.success
                    : Network.wifiStatus === "disabled" ? Appearance.tiling.error
                    : Appearance.tiling.accentBright
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: `${Network.friendlyWifiNetworks.length} aps`
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        color: Appearance.tiling.bg
        border.width: Appearance.tiling.borderWidth
        border.color: Appearance.tiling.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            StyledText {
                text: "current:"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.fillWidth: true
                text: root.activeName
                elide: Text.ElideRight
                color: Network.wifiStatus === "connected" ? Appearance.tiling.textBright : Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                text: Network.wifiEnabled ? "radio:on" : "radio:off"
                color: Network.wifiEnabled ? Appearance.tiling.success : Appearance.tiling.error
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 24
        color: Appearance.tiling.bgInput
        border.width: Appearance.tiling.borderWidth
        border.color: Appearance.tiling.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: "SSID"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 54
                horizontalAlignment: Text.AlignRight
                text: "SIGNAL"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: "%"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: "BAND"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.preferredWidth: 72
                horizontalAlignment: Text.AlignRight
                text: "SECURITY"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    StackLayout {
        Layout.fillHeight: true
        Layout.fillWidth: true
        currentIndex: Network.friendlyWifiNetworks.length > 0 ? 0 : 1

        ListView {
            id: networkList
            Layout.fillHeight: true
            Layout.fillWidth: true
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
                onDismiss: root.dismiss()
            }
        }

        Rectangle {
            color: "transparent"

            StyledText {
                anchors.centerIn: parent
                text: Network.wifiScanning
                    ? Translation.tr("scanning for networks...")
                    : Translation.tr("no networks found")
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 32
        color: Appearance.tiling.bgTitlebar

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            StyledText {
                text: "↑/k ↓/j move"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                text: "enter connect"
                color: Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                text: "r rescan"
                color: Network.wifiScanning ? Appearance.tiling.accentBright : Appearance.tiling.textDim
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Item { Layout.fillWidth: true }

            DialogButton {
                implicitHeight: 26
                buttonText: Translation.tr("Settings")
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
                }
            }

            DialogButton {
                implicitHeight: 26
                buttonText: Translation.tr("Close")
                onClicked: root.dismiss()
            }
        }
    }
}
