import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property WifiAccessPoint wifiNetwork
    enabled: !(Network.wifiConnectTarget === root.wifiNetwork && !wifiNetwork?.active)

    active: (wifiNetwork?.askingPassword || wifiNetwork?.active) ?? false
    onClicked: {
        Network.connectToWifiNetwork(wifiNetwork);
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            spacing: 10
            CosmicIcon {
                iconSize: Appearance.font.pixelSize.larger
                property int strength: root.wifiNetwork?.strength ?? 0
                name: strength > 80 ? "status/network-wireless-signal-excellent-symbolic" : strength > 60 ? "status/network-wireless-signal-good-symbolic" : strength > 40 ? "status/network-wireless-signal-ok-symbolic" : strength > 20 ? "status/network-wireless-signal-weak-symbolic" : "status/network-wireless-signal-none-symbolic"
                color: Appearance.tiling.textDim
            }
            StyledText {
                Layout.fillWidth: true
                color: Appearance.tiling.text
                elide: Text.ElideRight
                text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                textFormat: Text.PlainText
            }
            CosmicIcon {
                visible: (root.wifiNetwork?.isSecure || root.wifiNetwork?.active) ?? false
                name: root.wifiNetwork?.active ? "actions/object-select-symbolic" : Network.wifiConnectTarget === root.wifiNetwork ? "status/network-wireless-acquiring-symbolic" : "status/network-wireless-encrypted-symbolic"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.tiling.textDim
            }
        }

        ColumnLayout { // Password
            id: passwordPrompt
            Layout.topMargin: 8
            visible: root.wifiNetwork?.askingPassword ?? false

            MaterialTextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Password")

                // Password
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onAccepted: {
                    Network.changePassword(root.wifiNetwork, passwordField.text);
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: {
                        root.wifiNetwork.askingPassword = false;
                    }
                }

                DialogButton {
                    buttonText: Translation.tr("Connect")
                    onClicked: {
                        Network.changePassword(root.wifiNetwork, passwordField.text);
                    }
                }
            }
        }

        ColumnLayout { // Public wifi login page
            id: publicWifiPortal
            Layout.topMargin: 8
            visible: (root.wifiNetwork?.active && (root.wifiNetwork?.security ?? "").trim().length === 0) ?? false

            RowLayout {
                DialogButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Open network portal")
                    colBackground: Appearance.tiling.bgActive
                    colBackgroundHover: Appearance.tiling.bgHover
                    colRipple: Appearance.tiling.bgActive
                    onClicked: {
                        Network.openPublicWifiPortal()
                        GlobalStates.sidebarRightOpen = false
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
