import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

ColumnLayout {
    id: pageRoot

    required property var settingsRoot
    property string mode: "bluetooth"

    width: parent ? parent.width : 900
    spacing: SettingsTokens.controlGap
    implicitHeight: {
        const viewportHeight = pageRoot.settingsRoot ? pageRoot.settingsRoot.height - 120 : 500
        const contentHeight = contentCol.implicitHeight + 50 + spacing + 12
        return Math.max(viewportHeight, contentHeight)
    }

    readonly property bool adapterAvailable: BluetoothStatus.available
    readonly property bool adapterEnabled: BluetoothStatus.enabled
    readonly property bool isDiscovering: Bluetooth.defaultAdapter?.discovering ?? false
    readonly property bool isBusy: BluetoothStatus.actionRunning

    // ── Header card ─────────────────────────────────────────────
    SettingsCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 60

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: 12

            MaterialSymbol {
                text: adapterAvailable
                    ? (adapterEnabled ? "bluetooth" : "bluetooth_disabled")
                    : "bluetooth_searching"
                iconSize: 22
                color: adapterEnabled ? SettingsTokens.accent : SettingsTokens.muted
                Layout.preferredWidth: 24
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: adapterAvailable
                        ? (adapterEnabled ? "Bluetooth" : "Bluetooth is off")
                        : "No adapter found"
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                }

                StyledText {
                    text: {
                        if (!adapterAvailable) return ""
                        if (!adapterEnabled) return "Toggle to start scanning"
                        if (isBusy) return BluetoothStatus.actionMessage || "Working…"
                        if (BluetoothStatus.activeDeviceCount > 0)
                            return `${BluetoothStatus.activeDeviceCount} device${BluetoothStatus.activeDeviceCount > 1 ? "s" : ""} connected`
                        if (isDiscovering) return "Scanning…"
                        return "Tap Scan to find devices"
                    }
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    visible: text.length > 0
                }
            }

            // Inline toggle switch
            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 26
                radius: height / 2
                color: adapterEnabled ? SettingsTokens.accent : SettingsTokens.line
                opacity: adapterAvailable ? 1 : 0.4

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    x: adapterEnabled ? parent.width - width - 3 : 3
                    color: adapterEnabled ? SettingsTokens.bg : SettingsTokens.fg
                    Behavior on x { NumberAnimation { duration: 110 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: adapterAvailable
                    onClicked: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !adapterEnabled
                    }
                }
            }
        }
    }

    // ── Action status banner ────────────────────────────────────
    SettingsCard {
        Layout.fillWidth: true
        visible: BluetoothStatus.actionMessage.length > 0
        Layout.preferredHeight: 52

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: 10

            MaterialSymbol {
                text: BluetoothStatus.actionError.length > 0 ? "error" : "progress_activity"
                iconSize: 18
                color: BluetoothStatus.actionError.length > 0 ? SettingsTokens.danger : SettingsTokens.accent
                Layout.preferredWidth: 20
                RotationAnimator on rotation {
                    running: BluetoothStatus.actionRunning && BluetoothStatus.actionError.length === 0
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 1200
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: BluetoothStatus.actionDeviceName || "Bluetooth"
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: BluetoothStatus.actionMessage
                    color: BluetoothStatus.actionError.length > 0 ? SettingsTokens.danger : SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Passkey display
            Rectangle {
                visible: BluetoothStatus.actionPasskey.length > 0
                Layout.preferredWidth: 90
                Layout.preferredHeight: 32
                radius: SettingsTokens.radius
                color: SettingsTokens.accentSoft

                StyledText {
                    anchors.centerIn: parent
                    text: BluetoothStatus.actionPasskey
                    color: SettingsTokens.accent
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ── Scan button ────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        spacing: 8

        SettingsButton {
            label: isDiscovering ? "Stop scan" : "Scan for devices"
            iconName: isDiscovering ? "stop" : "bluetooth_searching"
            active: isDiscovering
            enabledState: adapterEnabled
            Layout.preferredWidth: 180
            onClicked: {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.discovering = !isDiscovering
            }
        }

        Item { Layout.fillWidth: true }
    }

    // ── Content ────────────────────────────────────────────────
    ColumnLayout {
        id: contentCol
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: SettingsTokens.controlGap

        // ── Paired devices ──
        SettingsSection {
            title: "Paired devices"
            visible: adapterEnabled
                && BluetoothStatus.connectedDevices.length + BluetoothStatus.pairedButNotConnectedDevices.length > 0

            Repeater {
                model: BluetoothStatus.connectedDevices.concat(BluetoothStatus.pairedButNotConnectedDevices)
                delegate: Rectangle {
                    id: devDelegate
                    required property var modelData
                    readonly property var device: modelData
                    readonly property bool isConnected: device.connected
                    readonly property bool isBusy: BluetoothStatus.actionRunning && BluetoothStatus.actionAddress === (device.address || "")
                    readonly property string deviceName: device.name || device.deviceName || "Unknown device"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: SettingsTokens.radius
                    color: isConnected
                        ? SettingsTokens.accentSoft
                        : (devMouse.containsMouse ? SettingsTokens.cardHover : "transparent")
                    border.width: isConnected ? 1 : 0
                    border.color: SettingsTokens.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            text: isBusy ? "progress_activity" : "bluetooth"
                            iconSize: 18
                            color: isConnected ? SettingsTokens.accent : SettingsTokens.muted
                            Layout.preferredWidth: 20
                            RotationAnimator on rotation {
                                running: isBusy
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: devDelegate.deviceName
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: isConnected ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    if (isBusy) return BluetoothStatus.actionMessage || "Working…"
                                    if (isConnected) return "Connected"
                                    return "Paired · tap to connect"
                                }
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                        }

                        // Forget button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: SettingsTokens.radius
                            color: forgetMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"
                            visible: !isBusy

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: 16
                                color: SettingsTokens.danger
                            }

                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BluetoothStatus.pairDevice(devDelegate.device) // paired → forget
                            }
                        }
                    }

                    MouseArea {
                        id: devMouse
                        anchors.fill: parent
                        anchors.rightMargin: 38 // leave room for forget button
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !isBusy
                        onClicked: BluetoothStatus.connectDevice(devDelegate.device)
                    }
                }
            }
        }

        // ── Available (unpaired) devices ──
        SettingsSection {
            title: "Available devices"
            visible: adapterEnabled && isDiscovering && BluetoothStatus.unpairedDevices.length > 0

            Repeater {
                model: BluetoothStatus.unpairedDevices
                delegate: Rectangle {
                    id: availDelegate
                    required property var modelData
                    readonly property var device: modelData
                    readonly property bool isBusy: BluetoothStatus.actionRunning && BluetoothStatus.actionAddress === (device.address || "")
                    readonly property string deviceName: device.name || device.deviceName || "Unknown device"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: SettingsTokens.radius
                    color: availMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialSymbol {
                            text: isBusy ? "progress_activity" : "bluetooth"
                            iconSize: 18
                            color: SettingsTokens.muted
                            Layout.preferredWidth: 20
                            RotationAnimator on rotation {
                                running: isBusy
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: availDelegate.deviceName
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: isBusy ? (BluetoothStatus.actionMessage || "Pairing…") : "Tap to pair"
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }

                    MouseArea {
                        id: availMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !isBusy
                        onClicked: BluetoothStatus.pairDevice(availDelegate.device) // unpaired → pair-connect
                    }
                }
            }
        }

        // ── Empty states ──
        SettingsEmptyState {
            Layout.fillWidth: true
            visible: !adapterAvailable
            iconName: "bluetooth_disabled"
            title: "No Bluetooth adapter"
            description: "This device has no Bluetooth controller."
        }

        SettingsEmptyState {
            Layout.fillWidth: true
            visible: adapterAvailable && !adapterEnabled
            iconName: "bluetooth_disabled"
            title: "Bluetooth is off"
            description: "Toggle Bluetooth on to scan for nearby devices."
        }

        SettingsEmptyState {
            Layout.fillWidth: true
            visible: adapterAvailable && adapterEnabled
                && BluetoothStatus.connectedDevices.length === 0
                && BluetoothStatus.pairedButNotConnectedDevices.length === 0
                && (!isDiscovering || BluetoothStatus.unpairedDevices.length === 0)
            iconName: isDiscovering ? "bluetooth_searching" : "bluetooth"
            title: isDiscovering ? "Scanning…" : "No devices found"
            description: isDiscovering
                ? "Looking for Bluetooth devices nearby…"
                : "Press Scan to discover nearby Bluetooth devices."
        }
    }
}