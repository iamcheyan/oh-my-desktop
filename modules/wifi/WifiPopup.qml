// WifiPopup.qml — Wi-Fi networks + Bluetooth popup.
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.widgets
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
        onSettingsClicked: ActionManager.invoke("settings.open", {section: "wifi"})
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
        Layout.preferredHeight: ServiceManager.network.wifiEnabled
            ? Math.min(wifiListCol.implicitHeight, 280)
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
                model: ServiceManager.network.friendlyWifiNetworks.filter(ap => ap.active || ServiceManager.network.isKnownWifi(ap)).slice(0, 12)
                delegate: ColumnLayout {
                    id: apRow
                    required property var modelData
                    readonly property var ap: modelData
                    readonly property bool isActive: ap.active ?? false
                    readonly property bool isKnown: ServiceManager.network.isKnownWifi(ap)
                    readonly property bool isConnecting: ServiceManager.network.isConnectingTo(ap)
                    readonly property bool showPassword: ap.askingPassword === true

                    Layout.fillWidth: true
                    spacing: 0
                    visible: (ap.ssid || "").length > 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: apRow.isActive
                            ? Qt.rgba(TuiStyle.accent.r, TuiStyle.accent.g, TuiStyle.accent.b, 0.12)
                            : (apMouse.containsMouse ? TuiStyle.surfaceHover : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 16
                            spacing: 10

                            MaterialSymbol {
                                text: {
                                    if (apRow.isConnecting)
                                        return "progress_activity";
                                    const s = apRow.ap.strength ?? 0;
                                    if (s >= 75)
                                        return "wifi";
                                    if (s >= 50)
                                        return "network_wifi_3_bar";
                                    if (s >= 25)
                                        return "network_wifi_2_bar";
                                    if (s > 0)
                                        return "network_wifi_1_bar";
                                    return "wifi_off";
                                }
                                iconSize: 18
                                color: apRow.isActive ? TuiStyle.accent : TuiStyle.muted
                                Layout.preferredWidth: 22
                                RotationAnimator on rotation {
                                    running: apRow.isConnecting
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1200
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
                                        if (apRow.showPassword)
                                            return "Enter password";
                                        if (apRow.isKnown)
                                            return "Saved";
                                        return apRow.ap.isSecure ? "Secured" : "Open";
                                    }
                                    color: TuiStyle.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
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
                                if (apRow.ap.ssid)
                                    ServiceManager.network.connectToWifiNetwork(apRow.ap);
                            }
                        }
                    }

                    Rectangle {
                        visible: apRow.showPassword
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        implicitHeight: popupPassCol.implicitHeight + 14
                        radius: 6
                        color: TuiStyle.panel
                        border.width: 1
                        border.color: TuiStyle.line

                        ColumnLayout {
                            id: popupPassCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 4
                                color: TuiStyle.control
                                border.width: 1
                                border.color: popupPassField.activeFocus ? TuiStyle.accent : TuiStyle.line

                                TextInput {
                                    id: popupPassField
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: Text.AlignVCenter
                                    color: TuiStyle.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    clip: true
                                    focus: apRow.showPassword
                                    enabled: !ServiceManager.network.wifiConnecting
                                    Keys.onReturnPressed: {
                                        GlobalStates.barPopupEphemeral = false;
                                        ServiceManager.network.connectToWifiNetworkWithPassword(apRow.ap, popupPassField.text);
                                    }
                                    Keys.onEnterPressed: {
                                        GlobalStates.barPopupEphemeral = false;
                                        ServiceManager.network.connectToWifiNetworkWithPassword(apRow.ap, popupPassField.text);
                                    }
                                    Keys.onEscapePressed: ServiceManager.network.cancelWifiPassword()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                SettingsButton {
                                    Layout.fillWidth: true
                                    label: ServiceManager.network.wifiConnecting ? "…" : "Connect"
                                    iconName: "link"
                                    active: true
                                    enabledState: !ServiceManager.network.wifiConnecting && popupPassField.text.length > 0
                                    onClicked: {
                                        GlobalStates.barPopupEphemeral = false;
                                        ServiceManager.network.connectToWifiNetworkWithPassword(apRow.ap, popupPassField.text);
                                    }
                                }
                                SettingsButton {
                                    Layout.fillWidth: true
                                    label: "Cancel"
                                    iconName: "close"
                                    enabledState: !ServiceManager.network.wifiConnecting
                                    onClicked: ServiceManager.network.cancelWifiPassword()
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
            Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-wifi`]);
        }
    }

    // Divider between Wi-Fi block and Bluetooth
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 4
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
        onSettingsClicked: ActionManager.invoke("settings.open", {section: "bluetooth"})
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
                Layout.preferredHeight: 40
                color: btMouse.containsMouse ? TuiStyle.surfaceHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 10

                    MaterialSymbol {
                        text: btRow.isConnecting ? "progress_activity" : (btRow.isActive ? "bluetooth_connected" : "bluetooth")
                        iconSize: 18
                        color: btRow.isActive ? TuiStyle.accent : TuiStyle.muted
                        Layout.preferredWidth: 22

                        RotationAnimator on rotation {
                            running: btRow.isConnecting
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1200
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
            Quickshell.execDetached(["/bin/bash", "-c", `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-launch-bluetooth`]);
        }
    }
}
