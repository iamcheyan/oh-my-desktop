import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root

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
    readonly property color tuiSelection: "#2b2b2b"
    readonly property string tuiLauncher: `${FileUtils.trimFileProtocol(Directories.config)}/omd/scripts/launch-tui-tool`
    readonly property string activeName: Network.active?.ssid || Network.networkName || Translation.tr("none")
    readonly property string statusText: Network.wifiScanning ? Translation.tr("scanning") : Network.wifiStatus
    readonly property var previewNetwork: selectedNetwork || networkList.currentItem?.wifiNetwork || Network.active
    property WifiAccessPoint selectedNetwork: null
    property bool detailsOpen: false
    property string connectionPassword: ""
    property bool passwordVisible: false
    readonly property bool selectedNeedsPassword: (selectedNetwork?.isSecure ?? false)
        && !(selectedNetwork?.active ?? false)
        && ((selectedNetwork?.askingPassword ?? false) || !Network.isKnownWifi(selectedNetwork))

    backgroundWidth: Math.min(980, Math.max(860, width - 36))
    backgroundHeight: Math.min(680, Math.max(560, height - 96))
    anchorPosition: 0
    focus: true

    function signalBars(strength) {
        if (strength > 84) return "████";
        if (strength > 64) return "███░";
        if (strength > 44) return "██░░";
        if (strength > 24) return "█░░░";
        return "░░░░";
    }

    function frequencyBand(frequency) {
        if (frequency >= 5900) return "6 GHz";
        if (frequency >= 4900) return "5 GHz";
        if (frequency > 0) return "2.4 GHz";
        return "--";
    }

    function securityLabel(security) {
        const value = (security ?? "").trim();
        return value.length > 0 ? value : "Open network";
    }

    function bssidShort(bssid) {
        const value = (bssid ?? "").trim();
        if (value.length < 8)
            return value || "--";
        return `**:**:${value.slice(-8)}`;
    }

    function linkState(network) {
        if (!network)
            return "idle";
        if (Network.wifiConnectTarget === network)
            return "dialing";
        if (network.active)
            return "linked";
        if (network.askingPassword)
            return "auth needed";
        return "standby";
    }

    function selectedOrCurrentNetwork() {
        return networkList.currentItem?.wifiNetwork || Network.active;
    }

    function openDetails(network) {
        if (!network)
            return;
        selectedNetwork = network;
        detailsOpen = true;
        connectionPassword = "";
        passwordVisible = false;
        Qt.callLater(() => {
            detailLayer.forceActiveFocus();
            if (root.selectedNeedsPassword)
                passwordField.forceActiveFocus();
        });
    }

    function closeDetails() {
        detailsOpen = false;
        selectedNetwork = null;
        connectionPassword = "";
        passwordVisible = false;
        root.forceActiveFocus();
    }

    function connectSelected() {
        if (!selectedNetwork)
            return;
        const password = connectionPassword;
        if (root.selectedNeedsPassword && password.length === 0) {
            passwordField.forceActiveFocus();
            return;
        }
        if ((selectedNetwork.isSecure || selectedNetwork.askingPassword) && password.length > 0)
            Network.connectToWifiNetworkWithPassword(selectedNetwork, password);
        else
            Network.connectToWifiNetwork(selectedNetwork);
        closeDetails();
    }

    function openSettings() {
        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
    }

    function openWifiTui() {
        Quickshell.execDetached([root.tuiLauncher, "wifi"]);
    }

    function openConnectionEditor() {
        Quickshell.execDetached(["nm-connection-editor"]);
    }

    Keys.onPressed: (event) => {
        if (root.detailsOpen) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_H) {
                root.closeDetails();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.connectSelected();
                event.accepted = true;
            }
            return;
        }

        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            networkList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            networkList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            networkList.currentIndex = Math.min(networkList.count - 1, networkList.currentIndex + 5);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            networkList.currentIndex = Math.max(0, networkList.currentIndex - 5);
            event.accepted = true;
        } else if (event.key === Qt.Key_G) {
            networkList.currentIndex = event.modifiers & Qt.ShiftModifier ? networkList.count - 1 : 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            networkList.currentIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            networkList.currentIndex = networkList.count - 1;
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            Network.rescanWifi();
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            root.openSettings();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_L) {
            root.openDetails(root.selectedOrCurrentNetwork());
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_H) {
            root.dismiss();
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            selectedNetwork = null;
            root.forceActiveFocus();
            Network.rescanWifi();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "transparent"
        border.width: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                color: "transparent"
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        TuiText {
                            text: "OMD NETCTL"
                            color: root.tuiAccent
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }

                        TuiText {
                            text: `radio=${Network.wifiEnabled ? "on" : "off"}  scan=${Network.wifiScanning ? "running" : "ready"}  profile=${root.activeName}`
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    StatusPill {
                        label: root.statusText.toUpperCase()
                        tone: Network.wifiStatus === "connected" ? root.tuiAccent : Network.wifiStatus === "disabled" ? root.tuiRed : root.tuiYellow
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                TuiPanel {
                    title: "ACCESS POINTS"
                    subtitle: `${Network.friendlyWifiNetworks.length} visible`
                    Layout.preferredWidth: Math.min(530, Math.max(480, root.backgroundWidth * 0.58))
                    Layout.fillHeight: true
                    accent: root.tuiAccent

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            spacing: 8

                            HeaderCell {
                                Layout.preferredWidth: 22
                                text: ""
                            }
                            HeaderCell {
                                Layout.fillWidth: true
                                text: "SSID"
                                horizontalAlignment: Text.AlignLeft
                            }
                            HeaderCell {
                                Layout.preferredWidth: 64
                                text: "RSSI"
                            }
                            HeaderCell {
                                Layout.preferredWidth: 42
                                text: "%"
                                horizontalAlignment: Text.AlignRight
                            }
                            HeaderCell {
                                Layout.preferredWidth: 38
                                text: "BND"
                            }
                            HeaderCell {
                                Layout.preferredWidth: 72
                                text: "AUTH"
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
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
                                keyNavigationEnabled: false
                                highlightMoveDuration: 80
                                onCountChanged: {
                                    if (count > 0 && currentIndex < 0)
                                        currentIndex = 0;
                                }
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
                                    accentColor: root.tuiAccent
                                    yellowColor: root.tuiYellow
                                    blueColor: root.tuiBlue
                                    bgColor: "#1a1a1a"
                                    lineColor: root.tuiLine
                                    onActivated: network => root.openDetails(network)
                                }
                            }

                            Rectangle {
                                color: "transparent"

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    TuiText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Network.wifiScanning ? "SCANNING..." : "NO ACCESS POINTS"
                                        color: root.tuiYellow
                                        font.weight: Font.DemiBold
                                    }
                                    TuiText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "press r to rescan"
                                        color: root.tuiDim
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    TuiPanel {
                        title: "TARGET"
                        subtitle: root.previewNetwork ? root.linkState(root.previewNetwork) : "no selection"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        accent: root.previewNetwork?.active ? root.tuiAccent : root.tuiBlue

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                TuiText {
                                    Layout.fillWidth: true
                                    text: root.previewNetwork?.ssid ?? "NO TARGET"
                                    color: root.previewNetwork ? root.tuiFg : root.tuiDim
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                }

                                StatusPill {
                                    label: root.linkState(root.previewNetwork).toUpperCase()
                                    tone: root.previewNetwork?.active ? root.tuiAccent : root.tuiBlue
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                color: "#222222"
                                radius: TuiStyle.radius
                                border.width: 0

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        TuiText {
                                            text: "SIGNAL"
                                            color: root.tuiDim
                                            font.weight: Font.DemiBold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: root.previewNetwork ? `${root.signalBars(root.previewNetwork.strength)} ${root.previewNetwork.strength}%` : "---- --%"
                                            color: root.tuiAccent
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    TuiMeterBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18
                                        value: root.previewNetwork?.strength ?? 0
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 18
                                rowSpacing: 10

                                DetailKey { text: "BAND" }
                                DetailValue { text: root.frequencyBand(root.previewNetwork?.frequency ?? 0) }
                                DetailKey { text: "FREQ" }
                                DetailValue { text: root.previewNetwork?.frequency ? `${root.previewNetwork.frequency} MHz` : "--" }
                                DetailKey { text: "AUTH" }
                                DetailValue {
                                    text: root.securityLabel(root.previewNetwork?.security)
                                    color: root.previewNetwork?.isSecure ? root.tuiYellow : root.tuiDim
                                }
                                DetailKey { text: "BSSID" }
                                DetailValue { text: root.bssidShort(root.previewNetwork?.bssid) }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TuiActionButton {
                                    label: "MANAGE"
                                    accent: root.tuiAccent
                                    enabledState: root.previewNetwork !== null
                                    onClicked: root.openDetails(root.previewNetwork)
                                }

                                TuiActionButton {
                                    label: "RESCAN"
                                    accent: root.tuiBlue
                                    onClicked: Network.rescanWifi()
                                }

                                TuiActionButton {
                                    label: "IMPALA"
                                    accent: root.tuiPurple
                                    onClicked: root.openWifiTui()
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "ADAPTER"
                        subtitle: "wld0"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 184
                        accent: Network.wifiEnabled ? root.tuiAccent : root.tuiRed

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 9

                            DetailKey { text: "POWER" }
                            DetailValue {
                                text: Network.wifiEnabled ? "ON" : "OFF"
                                color: Network.wifiEnabled ? root.tuiAccent : root.tuiRed
                            }
                            DetailKey { text: "STATE" }
                            DetailValue {
                                text: root.statusText
                                color: Network.wifiStatus === "connected" ? root.tuiAccent : root.tuiYellow
                            }
                            DetailKey { text: "LINK" }
                            DetailValue { text: root.activeName }
                            DetailKey { text: "LEVEL" }
                            DetailValue {
                                text: Number.isFinite(Network.networkStrength) ? `${Network.networkStrength}%` : "--"
                                color: Network.wifiStatus === "connected" ? root.tuiAccent : root.tuiDim
                            }

                            Item {
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                            }

                            RowLayout {
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                spacing: 8

                                TuiActionButton {
                                    label: Network.wifiEnabled ? "DISABLE" : "ENABLE"
                                    accent: Network.wifiEnabled ? root.tuiRed : root.tuiAccent
                                    onClicked: Network.toggleWifi()
                                }

                                TuiActionButton {
                                    label: "EDITOR"
                                    accent: root.tuiDim
                                    onClicked: root.openConnectionEditor()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: "transparent"
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 18

                    FooterHint { text: "enter/space/l manage" }
                    FooterHint { text: "r rescan" }
                    FooterHint { text: "s settings" }
                    FooterHint { text: "j/k/↑/↓ navigate" }
                    FooterHint { text: "g/G jump" }
                    Item { Layout.fillWidth: true }
                    FooterHint {
                        text: "q/esc close"
                        color: root.tuiYellow
                    }
                }
            }
        }

        Item {
            id: detailLayer
            anchors.fill: parent
            visible: root.detailsOpen
            focus: visible
            z: 20

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_H) {
                    root.closeDetails();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.connectSelected();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#050505"
                opacity: 0.82

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeDetails()
                }
            }

            Rectangle {
                id: detailBox
                width: Math.min(620, parent.width - 74)
                height: root.selectedNeedsPassword ? 480 : 400
                anchors.centerIn: parent
                color: "#181818"
                radius: TuiStyle.radius
                border.width: 0

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 13

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        TuiText {
                            text: "NETCTL::ACTION"
                            color: root.tuiAccent
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
                        }

                        TuiText {
                            text: root.linkState(root.selectedNetwork).toUpperCase()
                            color: root.selectedNetwork?.active ? root.tuiAccent : root.tuiYellow
                            font.weight: Font.DemiBold
                        }
                    }

                    TuiText {
                        Layout.fillWidth: true
                        text: root.selectedNetwork?.ssid ?? ""
                        color: root.tuiFg
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 14
                        rowSpacing: 9

                        DetailKey { text: "SIGNAL" }
                        DetailValue { text: root.selectedNetwork ? `${root.signalBars(root.selectedNetwork.strength)} ${root.selectedNetwork.strength}%` : "--" }
                        DetailKey { text: "BAND" }
                        DetailValue { text: root.frequencyBand(root.selectedNetwork?.frequency ?? 0) }
                        DetailKey { text: "AUTH" }
                        DetailValue {
                            text: root.securityLabel(root.selectedNetwork?.security)
                            color: root.selectedNetwork?.isSecure ? root.tuiYellow : root.tuiDim
                        }
                        DetailKey { text: "BSSID" }
                        DetailValue { text: root.bssidShort(root.selectedNetwork?.bssid) }
                    }

                    AutoConnectRow {
                        Layout.fillWidth: true
                        network: root.selectedNetwork
                    }

                    Rectangle {
                        visible: root.selectedNeedsPassword
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: "#222222"
                        radius: TuiStyle.radius
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            TuiText {
                                text: "PSK"
                                color: root.tuiDim
                                font.weight: Font.DemiBold
                            }

                            TextInput {
                                id: passwordField
                                Layout.fillWidth: true
                                color: root.tuiFg
                                selectionColor: root.tuiSelection
                                selectedTextColor: root.tuiFg
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                                inputMethodHints: root.passwordVisible ? Qt.ImhNone : Qt.ImhSensitiveData
                                focus: detailLayer.visible && root.selectedNeedsPassword
                                text: root.connectionPassword
                                onTextChanged: root.connectionPassword = text
                                onAccepted: root.connectSelected()
                            }

                            RippleButton {
                                id: passwordVisibilityButton
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                buttonRadius: 6
                                colBackground: hovered ? root.tuiSelection : "transparent"
                                colBackgroundHover: root.tuiSelection
                                colRipple: Qt.rgba(root.tuiFg.r, root.tuiFg.g, root.tuiFg.b, 0.12)
                                onClicked: {
                                    root.passwordVisible = !root.passwordVisible;
                                    passwordField.forceActiveFocus();
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.passwordVisible ? "visibility_off" : "visibility"
                                    iconSize: 20
                                    color: passwordVisibilityButton.hovered ? root.tuiFg : root.tuiDim
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        TuiActionButton {
                            visible: !(root.selectedNetwork?.active ?? false)
                            label: "CONNECT"
                            accent: root.tuiAccent
                            onClicked: root.connectSelected()
                        }

                        TuiActionButton {
                            visible: root.selectedNetwork?.active ?? false
                            label: "DISCONNECT"
                            accent: root.tuiYellow
                            onClicked: {
                                Network.disconnectAccessPoint(root.selectedNetwork);
                                root.closeDetails();
                            }
                        }

                        TuiActionButton {
                            label: "FORGET"
                            accent: root.tuiRed
                            onClicked: {
                                Network.forgetWifiNetwork(root.selectedNetwork);
                                root.closeDetails();
                            }
                        }

                        Item { Layout.fillWidth: true }

                        TuiActionButton {
                            label: "CANCEL"
                            accent: root.tuiDim
                            onClicked: root.closeDetails()
                        }
                    }
                }
            }
        }
    }

    component TuiText: StyledText {
        color: root.tuiFg
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        textFormat: Text.PlainText
    }

    component TuiPanel: Item {
        id: panel

        required property string title
        property string subtitle: ""
        property color accent: root.tuiAccent
        default property alias content: panelContent.data

        Rectangle {
            anchors.fill: parent
            color: TuiStyle.surfaceRaised
            radius: TuiStyle.radius
            border.width: 0
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: panel.accent
            opacity: 0
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            height: 32
            spacing: 8

            TuiText {
                text: panel.title
                color: root.tuiFg
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.tuiLine
                opacity: 0.28
            }

            TuiText {
                text: panel.subtitle
                color: root.tuiDim
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            id: panelContent
            anchors.fill: parent
            anchors.topMargin: 42
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
        }
    }

    component HeaderCell: TuiText {
        color: root.tuiDim
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component DetailKey: TuiText {
        Layout.preferredWidth: 62
        color: root.tuiDim
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignLeft
    }

    component DetailValue: TuiText {
        Layout.fillWidth: true
        color: root.tuiFg
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
    }

    component FooterHint: TuiText {
        color: root.tuiPurple
        font.weight: Font.Medium
    }

    component AutoConnectRow: Item {
        id: autoRow

        property WifiAccessPoint network
        readonly property bool manageable: Network.isKnownWifi(network)
        readonly property bool checked: Network.isWifiAutoconnect(network)

        implicitHeight: 38
        opacity: manageable ? 1 : 0.46

        Rectangle {
            anchors.fill: parent
            radius: TuiStyle.radius
            color: autoMouse.containsMouse && autoRow.manageable ? root.tuiSelection : "#202020"
            border.width: autoMouse.containsMouse && autoRow.manageable ? 1 : 0
            border.color: root.tuiLine
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            TuiText {
                text: autoRow.checked ? "[x]" : "[ ]"
                color: autoRow.checked ? root.tuiAccent : root.tuiDim
                font.family: Appearance.font.family.monospace
                font.weight: Font.DemiBold
            }

            TuiText {
                Layout.fillWidth: true
                text: "AUTO CONNECT"
                color: root.tuiFg
                font.family: Appearance.font.family.monospace
                font.weight: Font.DemiBold
            }

            TuiText {
                text: autoRow.manageable ? (autoRow.checked ? "enabled" : "disabled") : "connect once to save"
                color: autoRow.checked ? root.tuiAccent : root.tuiDim
                font.family: Appearance.font.family.monospace
                horizontalAlignment: Text.AlignRight
            }
        }

        MouseArea {
            id: autoMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: autoRow.manageable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Network.setWifiAutoconnect(autoRow.network, !autoRow.checked)
        }
    }

    component StatusPill: Item {
        id: pill

        property string label: ""
        property color tone: root.tuiAccent

        Layout.preferredWidth: Math.max(110, pillText.implicitWidth)
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        TuiText {
            id: pillText
            anchors.fill: parent
            text: pill.label
            color: pill.tone
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

}
