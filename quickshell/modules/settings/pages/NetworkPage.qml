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

ColumnLayout {
    id: pageRoot

    required property var settingsRoot
    // Kept for SettingsDialog mode aliases (wifi / network / bluetooth route).
    property string mode: "network"
    readonly property bool wideLayout: width >= 980

    width: parent ? parent.width : 900
    spacing: SettingsTokens.controlGap
    implicitHeight: {
        const viewportHeight = pageRoot.settingsRoot ? pageRoot.settingsRoot.height - 120 : 500
        const contentHeight = contentGrid.implicitHeight + 50 + spacing + 12
        return Math.max(viewportHeight, contentHeight)
    }

    readonly property string healthTitle: {
        if (!Network.wifiEnabled && !Network.ethernet)
            return Network.wifiEnabled === false ? "Wi‑Fi off" : "Disconnected"
        if (Network.wifiConnectPhase === "connecting" || Network.wifiConnecting)
            return "Connecting…"
        if (Network.wifiConnectPhase === "need_password")
            return "Password required"
        if (Network.wifiConnectPhase === "failed")
            return "Connection failed"
        if (Network.ethernet && Network.connectionKind === "ethernet")
            return "Ethernet"
        if (Network.wifiStatus === "connected" || Network.active)
            return "Connected"
        if (Network.wifiStatus === "limited")
            return "Limited"
        return "Disconnected"
    }

    readonly property string healthDetail: {
        if (Network.wifiConnectMessage.length > 0
                && Network.wifiConnectPhase !== "idle"
                && Network.wifiConnectPhase !== "success")
            return Network.wifiConnectMessage
        const name = Network.active?.ssid || Network.networkName || ""
        const ip = Network.ipv4Address
        if (name && ip)
            return `${name}  ·  ${ip}`
        if (name)
            return name
        if (Network.wifiEnabled)
            return `${Network.friendlyWifiNetworks.length} network${Network.friendlyWifiNetworks.length === 1 ? "" : "s"} nearby`
        return "Turn on Wi‑Fi or plug in ethernet"
    }

    readonly property bool healthWarning: Network.wifiConnectPhase === "failed"
        || Network.wifiConnectPhase === "need_password"
        || Network.wifiStatus === "limited"
        || (!Network.wifiEnabled && !Network.ethernet)

    Component.onCompleted: {
        Network.update()
        Network.refreshFirewall()
        if (Network.wifiEnabled)
            Network.rescanWifi()
    }

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: pageRoot.wideLayout ? 2 : 1
        columnSpacing: SettingsTokens.columnGap
        rowSpacing: SettingsTokens.columnGap

        // ════════════════════════════════════════
        // LEFT · Connect
        // ════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout
                ? (contentGrid.width - SettingsTokens.columnGap) / 2
                : contentGrid.width
            implicitHeight: leftColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 68

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: SettingsTokens.radius
                            color: pageRoot.healthWarning ? SettingsTokens.warningPanel : SettingsTokens.accentSoft
                            border.width: pageRoot.healthWarning ? 1 : 0
                            border.color: pageRoot.healthWarning ? SettingsTokens.warningBorder : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: Network.ethernet && Network.connectionKind === "ethernet"
                                    ? "lan"
                                    : (pageRoot.healthWarning ? "wifi_off" : "wifi")
                                iconSize: 25
                                color: pageRoot.healthWarning ? SettingsTokens.danger : SettingsTokens.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: "Network"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: `${pageRoot.healthTitle}  ·  ${pageRoot.healthDetail}`
                                color: pageRoot.healthWarning ? SettingsTokens.danger : SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                SettingsSection {
                    title: "Wi‑Fi radio"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        SettingsToggleRow {
                            Layout.fillWidth: true
                            label: "Wireless"
                            description: Network.wifiEnabled ? "Adapter enabled" : "Adapter disabled"
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
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Network.rescanWifi()
                            }
                        }
                    }
                }

                SettingsSection {
                    title: "Available networks"
                    visible: Network.wifiEnabled

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: Network.wifiScanning && Network.friendlyWifiNetworks.length === 0
                        text: "Scanning…"
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    Repeater {
                        model: Network.friendlyWifiNetworks.slice(0, 18)
                        delegate: ColumnLayout {
                            id: netDelegate
                            required property var modelData
                            readonly property var ap: modelData
                            readonly property bool isActive: ap.active ?? false
                            readonly property bool isKnown: Network.isKnownWifi(ap)
                            readonly property bool isConnecting: Network.isConnectingTo(ap)
                            readonly property bool showPassword: ap.askingPassword === true
                            readonly property bool isSuggested: {
                                const list = Network.suggestedWifiList
                                return list && list.length > 0 && list[0].ssid === ap.ssid && !isActive
                            }

                            Layout.fillWidth: true
                            spacing: 0
                            visible: (ap.ssid || "").length > 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: SettingsTokens.radius
                                color: netDelegate.isActive
                                    ? SettingsTokens.accentSoft
                                    : (netMouse.containsMouse ? SettingsTokens.cardHover : "transparent")
                                border.width: netDelegate.isActive || netDelegate.showPassword ? 1 : 0
                                border.color: SettingsTokens.accent

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    MaterialSymbol {
                                        text: {
                                            if (netDelegate.isConnecting)
                                                return "progress_activity"
                                            const s = netDelegate.ap.strength ?? 0
                                            if (s >= 75)
                                                return "wifi"
                                            if (s >= 50)
                                                return "network_wifi_3_bar"
                                            if (s >= 25)
                                                return "network_wifi_2_bar"
                                            if (s > 0)
                                                return "network_wifi_1_bar"
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
                                            text: netDelegate.ap.ssid || "Hidden"
                                            color: SettingsTokens.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: netDelegate.isActive ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            spacing: 6
                                            StyledText {
                                                text: {
                                                    if (netDelegate.isActive)
                                                        return "Connected"
                                                    if (netDelegate.isConnecting)
                                                        return "Connecting…"
                                                    if (netDelegate.showPassword)
                                                        return "Enter password"
                                                    if (netDelegate.isSuggested)
                                                        return "Suggested"
                                                    if (netDelegate.isKnown)
                                                        return "Saved"
                                                    return netDelegate.ap.isSecure ? "Secured" : "Open"
                                                }
                                                color: netDelegate.isActive || netDelegate.isSuggested
                                                    ? SettingsTokens.accent
                                                    : SettingsTokens.dim
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                            }
                                            MaterialSymbol {
                                                text: "lock"
                                                iconSize: 14
                                                color: SettingsTokens.dim
                                                visible: netDelegate.ap.isSecure
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
                                    enabled: !netDelegate.isActive && !netDelegate.isConnecting
                                    onClicked: {
                                        if (netDelegate.ap.ssid)
                                            Network.connectToWifiNetwork(netDelegate.ap)
                                    }
                                }
                            }

                            Rectangle {
                                visible: netDelegate.showPassword
                                Layout.fillWidth: true
                                Layout.leftMargin: 8
                                Layout.rightMargin: 8
                                Layout.bottomMargin: 8
                                implicitHeight: passColumn.implicitHeight + 16
                                radius: SettingsTokens.radius
                                color: SettingsTokens.panelAlt
                                border.width: 1
                                border.color: SettingsTokens.line

                                ColumnLayout {
                                    id: passColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    spacing: 8

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Network.lastConnectError.length > 0
                                            ? Network.lastConnectError
                                            : `Password for ${netDelegate.ap.ssid}`
                                        color: Network.lastConnectError.length > 0
                                            ? SettingsTokens.danger
                                            : SettingsTokens.muted
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        wrapMode: Text.WordWrap
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        radius: SettingsTokens.radius
                                        color: SettingsTokens.button
                                        border.width: 1
                                        border.color: passField.activeFocus ? SettingsTokens.accent : SettingsTokens.buttonBorder

                                        TextInput {
                                            id: passField
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: Text.AlignVCenter
                                            color: SettingsTokens.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            echoMode: TextInput.Password
                                            passwordCharacter: "•"
                                            clip: true
                                            focus: netDelegate.showPassword
                                            enabled: !Network.wifiConnecting
                                            Keys.onReturnPressed: Network.connectToWifiNetworkWithPassword(netDelegate.ap, passField.text)
                                            Keys.onEnterPressed: Network.connectToWifiNetworkWithPassword(netDelegate.ap, passField.text)
                                            Keys.onEscapePressed: Network.cancelWifiPassword()
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: SettingsTokens.controlGap
                                        SettingsButton {
                                            Layout.fillWidth: true
                                            label: Network.wifiConnecting ? "Connecting…" : "Connect"
                                            iconName: "link"
                                            active: true
                                            enabledState: !Network.wifiConnecting && passField.text.length > 0
                                            onClicked: Network.connectToWifiNetworkWithPassword(netDelegate.ap, passField.text)
                                        }
                                        SettingsButton {
                                            Layout.fillWidth: true
                                            label: "Cancel"
                                            iconName: "close"
                                            enabledState: !Network.wifiConnecting
                                            onClicked: Network.cancelWifiPassword()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: Network.friendlyWifiNetworks.length === 0 && !Network.wifiScanning
                        text: "No networks found. Tap refresh to scan."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                SettingsSection {
                    title: "Saved profiles"
                    visible: Network.savedWifiProfiles.length > 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: "Forget or toggle autoconnect for known Wi‑Fi profiles."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: Network.savedWifiProfiles.slice(0, 16)
                        delegate: Rectangle {
                            id: savedRow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 48
                            radius: SettingsTokens.radius
                            color: savedMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    text: "bookmark"
                                    iconSize: 18
                                    color: SettingsTokens.muted
                                    Layout.preferredWidth: 22
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: savedRow.modelData.name
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        text: savedRow.modelData.autoconnect ? "Autoconnect on" : "Autoconnect off"
                                        color: SettingsTokens.dim
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                }

                                SettingsIconButton {
                                    iconName: savedRow.modelData.autoconnect ? "link" : "link_off"
                                    onClicked: Network.setSavedProfileAutoconnect(
                                        savedRow.modelData.name,
                                        !savedRow.modelData.autoconnect)
                                }

                                SettingsIconButton {
                                    iconName: "delete"
                                    onClicked: Network.forgetSavedProfile(savedRow.modelData.name)
                                }
                            }

                            MouseArea {
                                id: savedMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ════════════════════════════════════════
        // RIGHT · Link & tools
        // ════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout
                ? (contentGrid.width - SettingsTokens.columnGap) / 2
                : contentGrid.width
            implicitHeight: rightColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: rightColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 3
                        StyledText {
                            Layout.fillWidth: true
                            text: "Link & tools"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Network.connectionKind.length > 0
                                ? `${Network.connectionKind} on ${Network.primaryDevice || "—"}`
                                : "No active interface"
                            color: SettingsTokens.muted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: SettingsTokens.line
                }

                SettingsSection {
                    title: "Current link"

                    SettingsRow {
                        label: "Network"
                        value: Network.active?.ssid || Network.networkName || "—"
                        clickable: false
                    }
                    SettingsRow {
                        label: "IPv4"
                        value: Network.ipv4Address || "—"
                        clickable: false
                    }
                    SettingsRow {
                        label: "Gateway"
                        value: Network.ipv4Gateway || "—"
                        clickable: false
                    }
                    SettingsRow {
                        label: "DNS"
                        value: Network.ipv4Dns || "—"
                        clickable: false
                    }
                    SettingsRow {
                        visible: Network.connectionKind === "wifi"
                        label: "Band / freq"
                        value: {
                            const parts = []
                            if (Network.linkBand)
                                parts.push(Network.linkBand)
                            if (Network.linkFreqMHz)
                                parts.push(`${Network.linkFreqMHz} MHz`)
                            return parts.length > 0 ? parts.join(" · ") : "—"
                        }
                        clickable: false
                    }
                    SettingsRow {
                        visible: Network.connectionKind === "wifi"
                        label: "Link rate"
                        value: {
                            if (Network.linkTxRate)
                                return `TX ${Network.linkTxRate}`
                            return "—"
                        }
                        description: Network.linkRxRate ? `RX ${Network.linkRxRate}` : ""
                        clickable: false
                    }
                    SettingsRow {
                        visible: Network.connectionKind === "wifi"
                        label: "Signal"
                        value: Network.linkSignalDbm
                            || (Network.active ? `${Network.active.strength}%` : "—")
                        clickable: false
                    }

                    ButtonRow {
                        SettingsButton {
                            label: "Copy summary"
                            iconName: "content_copy"
                            onClicked: Network.copyConnectionSummary()
                        }
                        SettingsButton {
                            label: "Refresh"
                            iconName: "refresh"
                            onClicked: Network.update()
                        }
                    }
                }

                SettingsSection {
                    title: "Diagnostics"

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: Network.diagPhase === "idle"
                            ? "Ping the gateway and the public internet (1.1.1.1)."
                            : Network.diagMessage
                        color: Network.diagPhase === "error"
                            ? SettingsTokens.danger
                            : (Network.diagPhase === "done" ? SettingsTokens.accent : SettingsTokens.dim)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    SettingsRow {
                        visible: Network.diagPhase === "done" || Network.diagPhase === "error"
                        label: "Gateway RTT"
                        value: Network.diagGatewayMs ? `${Network.diagGatewayMs} ms` : "—"
                        clickable: false
                    }
                    SettingsRow {
                        visible: Network.diagPhase === "done" || Network.diagPhase === "error"
                        label: "Internet RTT"
                        value: Network.diagExternalMs ? `${Network.diagExternalMs} ms` : "—"
                        clickable: false
                    }

                    SettingsButton {
                        Layout.fillWidth: true
                        label: Network.diagPhase === "running" ? "Checking…" : "Run check"
                        iconName: "speed"
                        enabledState: Network.diagPhase !== "running"
                        active: Network.diagPhase === "running"
                        onClicked: Network.runLightDiagnostics()
                    }
                }

                SettingsSection {
                    title: "Suggested Wi‑Fi"
                    visible: Network.wifiEnabled

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: "Saved networks nearby, ranked by signal (5 GHz names preferred)."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: (Network.suggestedWifiList || []).slice(0, 4)
                        delegate: SettingsRow {
                            required property var modelData
                            iconName: "star"
                            label: modelData.ssid
                            description: `Saved · ${modelData.strength ?? 0}%`
                            value: "Connect"
                            valueColor: SettingsTokens.accent
                            showChevron: true
                            onClicked: Network.connectToWifiNetwork(modelData)
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: !Network.suggestedWifiList || Network.suggestedWifiList.length === 0
                        text: "No saved networks are visible right now."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                SettingsDisclosure {
                    title: "Advanced · firewall & tools"

                    SettingsRow {
                        label: "Firewall"
                        value: {
                            if (Network.firewallState === "running")
                                return "Active"
                            if (Network.firewallState === "inactive")
                                return "Inactive"
                            return "Unknown"
                        }
                        description: Network.firewallDetail.length > 0
                            ? `${Network.firewallBackend} · ${Network.firewallDetail}`
                            : (Network.firewallBackend || "—")
                        valueColor: Network.firewallState === "running"
                            ? SettingsTokens.accent
                            : SettingsTokens.muted
                        clickable: false
                    }

                    ButtonRow {
                        SettingsButton {
                            label: "Connection editor"
                            iconName: "open_in_new"
                            onClicked: {
                                pageRoot.settingsRoot.dismiss()
                                Quickshell.execDetached(["nm-connection-editor"])
                            }
                        }
                        SettingsButton {
                            label: "Network TUI"
                            iconName: "open_in_new"
                            onClicked: {
                                pageRoot.settingsRoot.dismiss()
                                Quickshell.execDetached([
                                    "foot", "--app-id=nmtui", "--title=nmtui",
                                    "--window-size-pixels=880x620", "-e", "nmtui"
                                ])
                            }
                        }
                    }

                    SettingsButton {
                        Layout.fillWidth: true
                        visible: Network.firewallBackend === "firewalld"
                        label: "Firewall config"
                        iconName: "open_in_new"
                        onClicked: {
                            pageRoot.settingsRoot.dismiss()
                            Quickshell.execDetached(["bash", "-c", "command -v firewall-config >/dev/null && firewall-config || true"])
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
