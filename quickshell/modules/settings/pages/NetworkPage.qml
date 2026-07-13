import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

PageBody {
    id: page

    required property var settingsRoot
    property string mode: "network"
    // ── Bluetooth ──────────────────────────────────────────────
    SettingsCard {
        title: "Bluetooth"
        visible: page.mode === "bluetooth"
        subtitle: {
            if (!BluetoothStatus.available) return "Not available"
            if (!BluetoothStatus.enabled) return "Disabled"
            if (BluetoothStatus.connected) return `${BluetoothStatus.activeDeviceCount} connected`
            return "Enabled"
        }

        SettingsToggleRow {
            label: "Bluetooth radio"
            description: "Enable or disable Bluetooth"
            checked: BluetoothStatus.enabled
            onToggled: {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
        }

        ButtonRow {
            visible: BluetoothStatus.available
            SettingsButton { label: "Bluetooth Manager"; iconName: "open_in_new"; onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached(["blueman-manager"]) } }
        }
    }

    // ── Wi-Fi Status ─────────────────────────────────────────────
    SettingsCard {
        title: "Wi-Fi"
        visible: page.mode !== "bluetooth"
        subtitle: {
            if (!Network.wifiEnabled) return "Disabled"
            if (Network.wifiScanning) return "Scanning..."
            if (Network.wifiConnecting) return "Connecting..."
            return Network.wifiStatus
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingsToggleRow {
                Layout.fillWidth: true
                label: "Wireless radio"
                description: "Enable or disable the Wi-Fi adapter"
                checked: Network.wifiEnabled
                onToggled: Network.toggleWifi()
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: SettingsTokens.radius
                color: scanMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"
                visible: Network.wifiEnabled

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: SettingsTokens.muted
                    RotationAnimator on rotation {
                        running: Network.wifiScanning
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1200
                    }
                }

                MouseArea {
                    id: scanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Network.rescanWifi()
                }
            }
        }

        SettingsRow {
            label: "Connected network"
            value: Network.active?.ssid || Network.networkName || "--"
            visible: Network.wifiEnabled
        }

        SettingsRow {
            label: "Signal strength"
            value: Network.active ? `${Network.active.strength}%` : "--"
            visible: Network.wifiEnabled && Network.active
        }

        ButtonRow {
            visible: Network.wifiEnabled
            SettingsButton { label: "Connection Editor"; iconName: "open_in_new"; onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached(["nm-connection-editor"]) } }
            SettingsButton { label: "Network TUI"; iconName: "open_in_new"; onClicked: { page.settingsRoot.dismiss(); Quickshell.execDetached(["foot", "--app-id=nmtui", "--title=nmtui", "--window-size-pixels=880x620", "-e", "nmtui"]) } }
        }
    }

    // ── Available Networks ───────────────────────────────────────
    SettingsCard {
        title: "Available Networks"
        subtitle: `${Network.friendlyWifiNetworks.length} found`
        visible: Network.wifiEnabled

        // Scanning placeholder
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            visible: Network.wifiScanning && Network.friendlyWifiNetworks.length === 0
            color: "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: 10

                MaterialSymbol {
                    text: "wifi_find"
                    iconSize: 18
                    color: SettingsTokens.muted
                    SequentialAnimation on opacity {
                        running: Network.wifiScanning
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.4; to: 1.0; duration: 700 }
                        NumberAnimation { from: 1.0; to: 0.4; duration: 700 }
                    }
                }

                StyledText {
                    text: "Scanning for networks..."
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        Repeater {
            model: Network.friendlyWifiNetworks.slice(0, 15)
            delegate: Rectangle {
                id: netDelegate
                required property var modelData
                readonly property var ap: modelData
                readonly property bool isActive: ap.active ?? false
                readonly property bool isKnown: Network.isKnownWifi(ap)
                readonly property bool isConnecting: Network.wifiConnecting && Network.wifiConnectTarget?.ssid === ap.ssid

                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: SettingsTokens.radius
                color: isActive ? SettingsTokens.accentSoft : (netMouse.containsMouse ? SettingsTokens.cardHover : "transparent")
                border.width: isActive ? 1 : 0
                border.color: SettingsTokens.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Signal icon
                    MaterialSymbol {
                        text: {
                            if (netDelegate.isConnecting) return "progress_activity"
                            const s = netDelegate.ap.strength ?? 0
                            if (s >= 75) return "wifi"
                            if (s >= 50) return "network_wifi_3_bar"
                            if (s >= 25) return "network_wifi_2_bar"
                            if (s > 0) return "network_wifi_1_bar"
                            return "wifi_off"
                        }
                        iconSize: 18
                        color: netDelegate.isActive ? SettingsTokens.accent : SettingsTokens.muted
                        Layout.preferredWidth: 22
                        RotationAnimator on rotation {
                            running: netDelegate.isConnecting
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1200
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: netDelegate.ap.ssid || "Hidden network"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: netDelegate.isActive ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 6

                            StyledText {
                                text: netDelegate.isActive ? "Connected" : netDelegate.isConnecting ? "Connecting..." : netDelegate.isKnown ? "Saved" : "New"
                                color: netDelegate.isActive ? SettingsTokens.accent : SettingsTokens.dim
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }

                            MaterialSymbol {
                                text: "lock"
                                iconSize: 14
                                color: SettingsTokens.dim
                                visible: netDelegate.ap.security && netDelegate.ap.security.length > 0
                            }
                        }
                    }

                    StyledText {
                        text: `${netDelegate.ap.strength ?? 0}%`
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: netDelegate.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!netDelegate.isActive && netDelegate.ap.ssid)
                            Network.connectToWifiNetwork(netDelegate.ap)
                    }
                }
            }
        }

        // Empty state
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: Network.friendlyWifiNetworks.length === 0 && !Network.wifiScanning
            color: "transparent"

            StyledText {
                anchors.centerIn: parent
                text: "No networks found. Click scan to search."
                color: SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    // ── Ethernet ─────────────────────────────────────────────────
    SettingsCard {
        title: "Ethernet"
        subtitle: Network.ethernet ? "Connected" : "Not connected"
        visible: page.mode !== "bluetooth" && (!Network.wifi || Network.ethernet)

        SettingsRow {
            label: "Status"
            value: Network.ethernet ? "Connected" : "Disconnected"
        }

        SettingsRow {
            label: "Interface"
            value: Network.networkName || "--"
            visible: Network.ethernet
        }
    }
}
