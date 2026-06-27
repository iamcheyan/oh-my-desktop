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

    readonly property color tuiBg: "#030806"
    readonly property color tuiPanel: "#06110e"
    readonly property color tuiPanelAlt: "#091814"
    readonly property color tuiFg: "#e8fff3"
    readonly property color tuiDim: "#65736e"
    readonly property color tuiLine: "#174339"
    readonly property color tuiGreen: "#36ff8b"
    readonly property color tuiYellow: "#e8ff82"
    readonly property color tuiBlue: "#7bc7ff"
    readonly property color tuiPurple: "#c792ea"
    readonly property color tuiRed: "#ff6b8b"
    readonly property color tuiSelection: "#123a32"
    readonly property string activeName: Network.active?.ssid || Network.networkName || Translation.tr("none")
    readonly property string statusText: Network.wifiScanning ? Translation.tr("scanning") : Network.wifiStatus
    readonly property var previewNetwork: selectedNetwork || networkList.currentItem?.wifiNetwork || Network.active
    property WifiAccessPoint selectedNetwork: null
    property bool detailsOpen: false
    property string connectionPassword: ""

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
        detailLayer.forceActiveFocus();
    }

    function closeDetails() {
        detailsOpen = false;
        selectedNetwork = null;
        connectionPassword = "";
        root.forceActiveFocus();
    }

    function connectSelected() {
        if (!selectedNetwork)
            return;
        const password = connectionPassword;
        if ((selectedNetwork.isSecure || selectedNetwork.askingPassword) && password.length > 0)
            Network.connectToWifiNetworkWithPassword(selectedNetwork, password);
        else
            Network.connectToWifiNetwork(selectedNetwork);
        closeDetails();
    }

    function openSettings() {
        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
    }

    Keys.onPressed: (event) => {
        if (root.detailsOpen) {
            if (event.key === Qt.Key_Escape) {
                root.closeDetails();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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
        } else if (event.key === Qt.Key_R) {
            Network.rescanWifi();
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            root.openSettings();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.openDetails(root.selectedOrCurrentNetwork());
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
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
        color: root.tuiBg
        border.width: 1
        border.color: root.tuiLine

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                color: root.tuiPanel
                border.width: 1
                border.color: root.tuiGreen

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
                            color: root.tuiGreen
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                        }

                        TuiText {
                            text: `radio=${Network.wifiEnabled ? "on" : "off"}  scan=${Network.wifiScanning ? "running" : "ready"}  profile=${root.activeName}`
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    StatusPill {
                        label: root.statusText.toUpperCase()
                        tone: Network.wifiStatus === "connected" ? root.tuiGreen : Network.wifiStatus === "disabled" ? root.tuiRed : root.tuiYellow
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
                    accent: root.tuiGreen

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
                                    greenColor: root.tuiGreen
                                    yellowColor: root.tuiYellow
                                    blueColor: root.tuiBlue
                                    bgColor: root.tuiBg
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
                                        font.weight: Font.Bold
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
                        accent: root.previewNetwork?.active ? root.tuiGreen : root.tuiBlue

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
                                    font.weight: Font.Bold
                                }

                                StatusPill {
                                    label: root.linkState(root.previewNetwork).toUpperCase()
                                    tone: root.previewNetwork?.active ? root.tuiGreen : root.tuiBlue
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 82
                                color: root.tuiPanelAlt
                                border.width: 1
                                border.color: root.tuiLine

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
                                            font.weight: Font.Bold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: root.previewNetwork ? `${root.signalBars(root.previewNetwork.strength)} ${root.previewNetwork.strength}%` : "---- --%"
                                            color: root.tuiGreen
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.Bold
                                        }
                                    }

                                    MeterBar {
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

                                ActionButton {
                                    label: "MANAGE"
                                    accent: root.tuiGreen
                                    enabledState: root.previewNetwork !== null
                                    onClicked: root.openDetails(root.previewNetwork)
                                }

                                ActionButton {
                                    label: "RESCAN"
                                    accent: root.tuiBlue
                                    onClicked: Network.rescanWifi()
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "ADAPTER"
                        subtitle: "wld0"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 146
                        accent: Network.wifiEnabled ? root.tuiGreen : root.tuiRed

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 9

                            DetailKey { text: "POWER" }
                            DetailValue {
                                text: Network.wifiEnabled ? "ON" : "OFF"
                                color: Network.wifiEnabled ? root.tuiGreen : root.tuiRed
                            }
                            DetailKey { text: "STATE" }
                            DetailValue {
                                text: root.statusText
                                color: Network.wifiStatus === "connected" ? root.tuiGreen : root.tuiYellow
                            }
                            DetailKey { text: "LINK" }
                            DetailValue { text: root.activeName }
                            DetailKey { text: "LEVEL" }
                            DetailValue {
                                text: Number.isFinite(Network.networkStrength) ? `${Network.networkStrength}%` : "--"
                                color: Network.wifiStatus === "connected" ? root.tuiGreen : root.tuiDim
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: root.tuiPanel
                border.width: 1
                border.color: root.tuiLine

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 18

                    FooterHint { text: "enter manage" }
                    FooterHint { text: "r rescan" }
                    FooterHint { text: "s settings" }
                    FooterHint { text: "j/k navigate" }
                    Item { Layout.fillWidth: true }
                    FooterHint {
                        text: "esc close"
                        color: root.tuiYellow
                    }
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
            if (event.key === Qt.Key_Escape) {
                root.closeDetails();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.connectSelected();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#010302"
            opacity: 0.82

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeDetails()
            }
        }

        Rectangle {
            id: detailBox
            width: Math.min(620, parent.width - 74)
            height: root.selectedNetwork?.isSecure && !(root.selectedNetwork?.active ?? false) ? 420 : 350
            anchors.centerIn: parent
            color: root.tuiBg
            border.width: 1
            border.color: root.tuiGreen

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
                        color: root.tuiGreen
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    TuiText {
                        text: root.linkState(root.selectedNetwork).toUpperCase()
                        color: root.selectedNetwork?.active ? root.tuiGreen : root.tuiYellow
                        font.weight: Font.Bold
                    }
                }

                TuiText {
                    Layout.fillWidth: true
                    text: root.selectedNetwork?.ssid ?? ""
                    color: root.tuiFg
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
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

                Rectangle {
                    visible: root.selectedNetwork?.isSecure && !(root.selectedNetwork?.active ?? false)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: root.tuiPanel
                    border.width: 1
                    border.color: passwordField.activeFocus ? root.tuiGreen : root.tuiLine

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        TuiText {
                            text: "PSK"
                            color: root.tuiDim
                            font.weight: Font.Bold
                        }

                        TextInput {
                            id: passwordField
                            Layout.fillWidth: true
                            color: root.tuiFg
                            selectionColor: root.tuiSelection
                            selectedTextColor: root.tuiFg
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhSensitiveData
                            focus: detailLayer.visible && root.selectedNetwork?.isSecure && !(root.selectedNetwork?.active ?? false)
                            text: root.connectionPassword
                            onTextChanged: root.connectionPassword = text
                            onAccepted: root.connectSelected()
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ActionButton {
                        visible: !(root.selectedNetwork?.active ?? false)
                        label: "CONNECT"
                        accent: root.tuiGreen
                        onClicked: root.connectSelected()
                    }

                    ActionButton {
                        visible: root.selectedNetwork?.active ?? false
                        label: "DISCONNECT"
                        accent: root.tuiYellow
                        onClicked: {
                            Network.disconnectAccessPoint(root.selectedNetwork);
                            root.closeDetails();
                        }
                    }

                    ActionButton {
                        label: "FORGET"
                        accent: root.tuiRed
                        onClicked: {
                            Network.forgetWifiNetwork(root.selectedNetwork);
                            root.closeDetails();
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ActionButton {
                        label: "CANCEL"
                        accent: root.tuiDim
                        onClicked: root.closeDetails()
                    }
                }
            }
        }
    }

    component TuiText: StyledText {
        color: root.tuiFg
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        textFormat: Text.PlainText
    }

    component TuiPanel: Item {
        id: panel

        required property string title
        property string subtitle: ""
        property color accent: root.tuiGreen
        default property alias content: panelContent.data

        Rectangle {
            anchors.fill: parent
            color: root.tuiPanel
            border.width: 1
            border.color: root.tuiLine
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: panel.accent
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
                color: panel.accent
                font.weight: Font.Bold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.tuiLine
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
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component DetailKey: TuiText {
        Layout.preferredWidth: 62
        color: root.tuiDim
        font.weight: Font.Bold
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
        font.weight: Font.Bold
    }

    component StatusPill: Rectangle {
        id: pill

        property string label: ""
        property color tone: root.tuiGreen

        Layout.preferredWidth: Math.max(92, pillText.implicitWidth + 22)
        Layout.preferredHeight: 26
        color: Qt.rgba(pill.tone.r, pill.tone.g, pill.tone.b, 0.10)
        border.width: 1
        border.color: pill.tone

        TuiText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.tone
            font.weight: Font.Bold
        }
    }

    component MeterBar: Row {
        id: meter

        property int value: 0

        spacing: 3
        Repeater {
            model: 12
            Rectangle {
                required property int index
                width: Math.max(8, (meter.width - 33) / 12)
                height: meter.height
                color: index < Math.ceil(Math.max(0, Math.min(100, meter.value)) / 100 * 12) ? root.tuiGreen : root.tuiLine
            }
        }
    }

    component ActionButton: Rectangle {
        id: action

        property string label: ""
        property color accent: root.tuiGreen
        property bool enabledState: true
        signal clicked()

        Layout.preferredWidth: Math.max(92, actionText.implicitWidth + 24)
        Layout.preferredHeight: 32
        color: action.enabledState && actionMouse.containsMouse ? Qt.rgba(action.accent.r, action.accent.g, action.accent.b, 0.16) : root.tuiPanel
        border.width: 1
        border.color: action.enabledState ? action.accent : root.tuiLine
        opacity: action.enabledState ? 1 : 0.45

        TuiText {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            color: action.accent
            font.weight: Font.Bold
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: action.enabledState
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }
}
