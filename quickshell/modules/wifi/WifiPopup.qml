// WifiPopup.qml — Wi-Fi networks + Bluetooth popup.
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets
import qs.modules.bar
import qs.services
import qs.core.runtime
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

ColumnLayout {
    id: popup
    spacing: 0
    width: parent?.width ?? implicitWidth

    Component.onCompleted: {
        if (ServiceManager.network.wifiEnabled)
            ServiceManager.network.rescanWifi();
    }

    function connStatus() {
        if (ServiceManager.network.wifiConnectPhase === "connecting" || ServiceManager.network.wifiConnecting)
            return "Connecting";
        if (ServiceManager.network.wifiConnectPhase === "need_password")
            return "Password";
        if (ServiceManager.network.wifiConnectPhase === "failed")
            return "Failed";
        if (ServiceManager.network.ethernet)
            return "Connected";
        if (!ServiceManager.network.wifiEnabled || ServiceManager.network.wifiStatus === "disabled")
            return "Disabled";
        const s = ServiceManager.network.wifiStatus || "disconnected";
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function connTone() {
        const s = popup.connStatus();
        if (s === "Connected" || ServiceManager.network.wifiConnectPhase === "success")
            return TuiStyle.success;
        if (s === "Disabled" || s === "Failed")
            return TuiStyle.danger;
        if (s === "Connecting" || s === "Limited" || s === "Password")
            return TuiStyle.warning;
        return TuiStyle.muted;
    }
    function connIcon() {
        return ServiceManager.network.ethernet ? NerdIconMap.ethernet : NerdIconMap.wifi;
    }
    function connName() {
        if (ServiceManager.network.ethernet)
            return ServiceManager.network.networkName || "Wired Connection";
        return ServiceManager.network.active?.ssid || ServiceManager.network.networkName || "Not connected";
    }
    function connDetail() {
        if (ServiceManager.network.wifiConnectMessage.length > 0
                && ServiceManager.network.wifiConnectPhase !== "idle"
                && ServiceManager.network.wifiConnectPhase !== "success")
            return ServiceManager.network.wifiConnectMessage;
        if (ServiceManager.network.ethernet)
            return "";
        if (ServiceManager.network.wifiStatus === "connected")
            return `Signal ${ServiceManager.network.active?.strength ?? ServiceManager.network.networkStrength}%  ·  ${ServiceManager.network.friendlyWifiNetworks.length} nearby`;
        return `${ServiceManager.network.friendlyWifiNetworks.length} network${ServiceManager.network.friendlyWifiNetworks.length === 1 ? "" : "s"} nearby`;
    }


    // ── Wi-Fi section: toggle + nearby list ──
    PopupToggleRow {
        label: "Wi-Fi"
        checked: ServiceManager.network.wifiEnabled
        showSettingsButton: true
        showDivider: false
        onToggled: checked => {
            GlobalStates.barPopupEphemeral = false;
            ServiceManager.network.enableWifi(checked);
        }
        onSettingsClicked: {
            GlobalStates.barPopupType = "";
            GlobalStates.barPopupEphemeral = false;
            Quickshell.execDetached(["nm-connection-editor"]);
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.topMargin: 2
        Layout.bottomMargin: 4
        visible: ServiceManager.network.wifiEnabled
            && ServiceManager.network.wifiConnectMessage.length > 0
            && ServiceManager.network.wifiConnectPhase !== "idle"
        text: ServiceManager.network.wifiConnectMessage
        color: ServiceManager.network.wifiConnectPhase === "failed" || ServiceManager.network.wifiConnectPhase === "need_password"
            ? TuiStyle.danger
            : (ServiceManager.network.wifiConnectPhase === "success" ? TuiStyle.success : TuiStyle.muted)
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 12
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        visible: ServiceManager.network.wifiEnabled
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: ServiceManager.network.wifiScanning ? "Scanning…" : "Networks"
            color: TuiStyle.dim
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 4
            color: wifiScanMouse.containsMouse ? TuiStyle.controlHover : "transparent"

            MaterialSymbol {
                anchors.centerIn: parent
                width: 16
                height: 16
                horizontalAlignment: Text.AlignHCenter
                text: "refresh"
                iconSize: 16
                color: TuiStyle.muted
                RotationAnimator on rotation {
                    running: ServiceManager.network.wifiScanning
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1200
                }
            }

            MouseArea {
                id: wifiScanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    GlobalStates.barPopupEphemeral = false;
                    ServiceManager.network.rescanWifi();
                }
            }
        }
    }

    Flickable {
        id: wifiListFlick
        Layout.fillWidth: true
        readonly property real rowHeight: 44
        readonly property int maxVisibleRows: 5
        Layout.preferredHeight: ServiceManager.network.wifiEnabled
            ? (wifiListCol.implicitHeight <= maxVisibleRows * rowHeight
                ? wifiListCol.implicitHeight
                : maxVisibleRows * rowHeight)
            : 0
        visible: ServiceManager.network.wifiEnabled
        contentHeight: wifiListCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: wifiListCol.implicitHeight > height

        ColumnLayout {
            id: wifiListCol
            width: wifiListFlick.width
            spacing: 0

            Repeater {
                model: ServiceManager.network.friendlyWifiNetworks.slice(0, 12)
                delegate: ColumnLayout {
                    id: apRow
                    required property var modelData
                    readonly property var ap: modelData
                    readonly property bool isActive: ap.active ?? false
                    readonly property bool isKnown: ServiceManager.network.isKnownWifi(ap)
                    readonly property bool isConnecting: ServiceManager.network.isConnectingTo(ap)


                    Layout.fillWidth: true
                    spacing: 0
                    visible: (ap.ssid || "").length > 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.rightMargin: 6
                        Layout.preferredHeight: 44
                        radius: 6
                        color: apRow.isActive
                            ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                            : (apMouse.containsMouse ? TuiStyle.surfaceHover : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 16
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    visible: apRow.isConnecting
                                    text: "progress_activity"
                                    iconSize: 18
                                    color: TuiStyle.accent
                                    rotation: apRow.isConnecting ? rotation : 0

                                    RotationAnimator on rotation {
                                        running: apRow.isConnecting
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1200
                                    }
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    visible: !apRow.isConnecting
                                    rotation: 0
                                    text: {
                                        const s = apRow.ap.strength ?? 0;
                                        if (s >= 67)
                                            return "network_wifi_3_bar";
                                        if (s >= 33)
                                            return "network_wifi_2_bar";
                                        if (s > 0)
                                            return "network_wifi_1_bar";
                                        return "network_wifi";
                                    }
                                    iconSize: 18
                                    color: apRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: apRow.ap.ssid || "Hidden"
                                    color: TuiStyle.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: apRow.isActive ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        if (apRow.isActive)
                                            return "Connected";
                                        if (apRow.isConnecting)
                                            return "Connecting…";

                                        if (apRow.isKnown)
                                            return "Saved";
                                        return apRow.ap.isSecure ? "Secured" : "Open";
                                    }
                                    color: TuiStyle.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            // Green dot: this network is saved (no password needed from user)
                            Rectangle {
                                visible: apRow.isKnown
                                Layout.preferredWidth: 7
                                Layout.preferredHeight: 7
                                Layout.rightMargin: 4
                                radius: 3.5
                                color: TuiStyle.success
                            }

                            MaterialSymbol {
                                visible: apRow.ap.isSecure
                                text: "lock"
                                iconSize: 14
                                color: TuiStyle.dim
                            }

                            StyledText {
                                text: `${apRow.ap.strength ?? 0}%`
                                color: TuiStyle.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        MouseArea {
                            id: apMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: apRow.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !apRow.isActive && !apRow.isConnecting
                            onClicked: {
                                GlobalStates.barPopupEphemeral = false;
                                if (!apRow.ap.ssid)
                                    return;
                                // Known network: switch directly in the popup.
                                // Stranger network: hand off to the Wi-Fi TUI,
                                // which opens the password prompt for it.
                                if (apRow.isKnown) {
                                    ServiceManager.network.connectToWifiNetwork(apRow.ap);
                                } else {
                                    GlobalStates.barPopupType = "";
                                    ServiceManager.network.launchWifiTui(apRow.ap.ssid);
                                }
                            }
                        }
                    }

                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                visible: ServiceManager.network.friendlyWifiNetworks.length === 0 && !ServiceManager.network.wifiScanning
                text: "No networks found. Tap refresh to scan."
                color: TuiStyle.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Wi-Fi advanced footer ──
    PopupFooterLink {
        Layout.fillWidth: true
        label: "Add new Wi-Fi…"
        onClicked: {
            GlobalStates.barPopupType = "";
            GlobalStates.barPopupEphemeral = false;
            Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.root)}/quickshell/modules/wifi/bin/sumika-launch-wifi`]);
        }
    }

    // Divider between Wi-Fi block and Bluetooth
    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.preferredHeight: 1
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        color: TuiStyle.line
        opacity: TuiStyle.dividerOpacity
    }

    // ── Bluetooth section (standalone) ──
    PopupToggleRow {
        label: "Bluetooth"
        checked: BluetoothStatus.enabled
        enabled: BluetoothStatus.available
        showSettingsButton: true
        showDivider: false
        onToggled: checked => {
            GlobalStates.barPopupEphemeral = false;
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.enabled = checked;
        }
        onSettingsClicked: {
            GlobalStates.barPopupType = "";
            GlobalStates.barPopupEphemeral = false;
            Quickshell.execDetached(["blueman-manager"]);
        }
    }

    // ── Bluetooth saved devices list ──
    ColumnLayout {
        id: btListCol
        Layout.fillWidth: true
        spacing: 0
        visible: BluetoothStatus.enabled && btRepeater.count > 0

        Repeater {
            id: btRepeater
            model: {
                const list = [];
                if (BluetoothStatus.connectedDevices) {
                    for (let i = 0; i < BluetoothStatus.connectedDevices.length; i++) {
                        list.push(BluetoothStatus.connectedDevices[i]);
                    }
                }
                if (BluetoothStatus.pairedButNotConnectedDevices) {
                    for (let i = 0; i < BluetoothStatus.pairedButNotConnectedDevices.length; i++) {
                        list.push(BluetoothStatus.pairedButNotConnectedDevices[i]);
                    }
                }
                return list.slice(0, 5); // limit to 5 saved devices to save space
            }

            delegate: Rectangle {
                id: btRow
                required property var modelData
                readonly property var dev: modelData
                readonly property bool isActive: dev.connected ?? false
                readonly property bool isConnecting: BluetoothStatus.actionRunning && BluetoothStatus.actionAddress === dev.address

                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.preferredHeight: 40
                radius: 6
                color: btMouse.containsMouse ? TuiStyle.surfaceHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 10

                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    visible: btRow.isConnecting
                                    text: "progress_activity"
                                    iconSize: 18
                                    color: TuiStyle.accent
                                    rotation: btRow.isConnecting ? rotation : 0

                                    RotationAnimator on rotation {
                                        running: btRow.isConnecting
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1200
                                    }
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    visible: !btRow.isConnecting
                                    rotation: 0
                                    text: btRow.isActive ? "bluetooth_connected" : "bluetooth"
                                    iconSize: 18
                                    color: btRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                }
                            }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: btRow.dev.name || btRow.dev.address || "Unknown Device"
                            color: TuiStyle.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: btRow.isActive ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: btRow.isConnecting ? "Connecting…" : (btRow.isActive ? "Connected" : "Saved")
                            color: TuiStyle.dim
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideRight
                            visible: btRow.isConnecting || btRow.isActive
                        }
                    }
                }

                MouseArea {
                    id: btMouse
                    anchors.fill: parent

                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        GlobalStates.barPopupEphemeral = false;
                        BluetoothStatus.connectDevice(btRow.dev);
                    }
                }
            }
        }
    }

    // ── Bluetooth TUI link ──
    PopupFooterLink {
        Layout.fillWidth: true
        visible: BluetoothStatus.enabled
        label: "Add new Bluetooth…"
        onClicked: {
            GlobalStates.barPopupType = "";
            GlobalStates.barPopupEphemeral = false;
            Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.root)}/quickshell/modules/wifi/bin/sumika-launch-bluetooth`]);
        }
    }

}
