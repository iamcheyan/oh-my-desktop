import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

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
    readonly property var previewDevice: selectedDevice || deviceList.currentItem?.device || BluetoothStatus.firstActiveDevice
    property var selectedDevice: null
    property bool actionOpen: false

    backgroundWidth: Math.min(980, Math.max(860, width - 36))
    backgroundHeight: Math.min(680, Math.max(560, height - 96))
    anchorPosition: 0
    focus: true

    function deviceName(device) {
        return device?.name || Translation.tr("Unknown device");
    }

    function batteryLabel(device) {
        if (!(device?.batteryAvailable ?? false))
            return "--";
        return `${Math.round((device?.battery ?? 0) * 100)}%`;
    }

    function deviceState(device) {
        if (!device)
            return "idle";
        if (device.connected)
            return "linked";
        if (device.paired)
            return "paired";
        return "new";
    }

    function deviceClass(device) {
        const icon = (device?.icon || "").toLowerCase();
        if (icon.includes("keyboard"))
            return "keyboard";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("head") || icon.includes("audio"))
            return "audio";
        if (icon.includes("phone"))
            return "phone";
        return icon.length > 0 ? icon : "device";
    }

    function selectedOrCurrentDevice() {
        return deviceList.currentItem?.device || BluetoothStatus.firstActiveDevice;
    }

    function openAction(device) {
        if (!device)
            return;
        selectedDevice = device;
        actionOpen = true;
        actionLayer.forceActiveFocus();
    }

    function closeAction() {
        actionOpen = false;
        selectedDevice = null;
        root.forceActiveFocus();
    }

    function connectSelected() {
        if (!selectedDevice)
            return;
        if (selectedDevice.connected)
            selectedDevice.disconnect();
        else
            selectedDevice.connect();
        closeAction();
    }

    function pairSelected() {
        if (!selectedDevice)
            return;
        if (selectedDevice.paired)
            selectedDevice.forget();
        else
            selectedDevice.pair();
        closeAction();
    }

    function openSettings() {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`]);
    }

    function openBluetoothTui() {
        Quickshell.execDetached([root.tuiLauncher, "bluetooth"]);
    }

    function openBluemanManager() {
        Quickshell.execDetached(["blueman-manager"]);
    }

    function toggleBluetoothPower() {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
    }

    Keys.onPressed: (event) => {
        if (root.actionOpen) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_H) {
                root.closeAction();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.connectSelected();
                event.accepted = true;
            }
            return;
        }

        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            deviceList.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            deviceList.decrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            deviceList.currentIndex = Math.min(deviceList.count - 1, deviceList.currentIndex + 5);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            deviceList.currentIndex = Math.max(0, deviceList.currentIndex - 5);
            event.accepted = true;
        } else if (event.key === Qt.Key_G) {
            deviceList.currentIndex = event.modifiers & Qt.ShiftModifier ? deviceList.count - 1 : 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            deviceList.currentIndex = 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            deviceList.currentIndex = deviceList.count - 1;
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            if (Bluetooth.defaultAdapter) {
                Bluetooth.defaultAdapter.enabled = true;
                Bluetooth.defaultAdapter.discovering = true;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_P) {
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            root.openSettings();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_L) {
            root.openAction(root.selectedOrCurrentDevice());
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_H) {
            root.dismiss();
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            selectedDevice = null;
            root.forceActiveFocus();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "transparent"
        border.width: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                color: "transparent"
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 6
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "OMD BTCTL"
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: root.tuiFg
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `radio=${BluetoothStatus.enabled ? "on" : "off"}  scan=${Bluetooth.defaultAdapter?.discovering ? "running" : "ready"}  linked=${BluetoothStatus.activeDeviceCount}`
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 6

                        HeaderButton {
                            iconName: "restart_alt"
                            accent: root.tuiYellow
                            onClicked: {
                                if (Bluetooth.defaultAdapter) {
                                    Bluetooth.defaultAdapter.enabled = true;
                                    Bluetooth.defaultAdapter.discovering = true;
                                }
                            }
                        }

                        HeaderButton {
                            iconName: "power_settings_new"
                            accent: root.tuiRed
                            onClicked: root.dismiss()
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: root.tuiLine
                    opacity: 0.35
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                TuiPanel {
                    title: "DEVICES"
                    subtitle: `${BluetoothStatus.friendlyDeviceList.length} visible`
                    Layout.preferredWidth: Math.min(530, Math.max(480, root.backgroundWidth * 0.58))
                    Layout.fillHeight: true
                    accent: root.tuiBlue

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
                                Layout.preferredWidth: 20
                                text: ""
                            }
                            HeaderCell {
                                Layout.fillWidth: true
                                text: "NAME"
                                horizontalAlignment: Text.AlignLeft
                            }
                            HeaderCell {
                                Layout.preferredWidth: 64
                                text: "BATT"
                                horizontalAlignment: Text.AlignRight
                            }
                            HeaderCell {
                                Layout.preferredWidth: 72
                                text: "PAIR"
                            }
                            HeaderCell {
                                Layout.preferredWidth: 76
                                text: "STATE"
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
                            currentIndex: BluetoothStatus.friendlyDeviceList.length > 0 ? 0 : 1

                            ListView {
                                id: deviceList
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
                                    values: BluetoothStatus.friendlyDeviceList
                                }
                                delegate: BluetoothDeviceItem {
                                    required property var modelData
                                    device: modelData
                                    width: ListView.view.width
                                    selectionColor: root.tuiSelection
                                    foregroundColor: root.tuiFg
                                    dimColor: root.tuiDim
                                    accentColor: root.tuiAccent
                                    yellowColor: root.tuiYellow
                                    blueColor: root.tuiBlue
                                    lineColor: root.tuiLine
                                    onActivated: device => root.openAction(device)
                                }
                            }

                            Rectangle {
                                color: "transparent"

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    TuiText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Bluetooth.defaultAdapter?.discovering ? "SCANNING..." : "NO DEVICES"
                                        color: root.tuiYellow
                                        font.weight: Font.DemiBold
                                    }
                                    TuiText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "press r to scan"
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
                        subtitle: root.previewDevice ? root.deviceState(root.previewDevice) : "no selection"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        accent: root.previewDevice?.connected ? root.tuiAccent : root.tuiBlue

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                CosmicIcon {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    iconSize: 26
                                    name: Icons.getBluetoothDeviceCosmicIcon(root.previewDevice?.icon || "")
                                    color: root.previewDevice?.connected ? root.tuiAccent : root.tuiBlue
                                }

                                TuiText {
                                    Layout.fillWidth: true
                                    text: root.previewDevice ? root.deviceName(root.previewDevice) : "NO TARGET"
                                    color: root.previewDevice ? root.tuiFg : root.tuiDim
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                }

                                StatusPill {
                                    label: root.deviceState(root.previewDevice).toUpperCase()
                                    tone: root.previewDevice?.connected ? root.tuiAccent : root.tuiBlue
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
                                            text: "BATTERY"
                                            color: root.tuiDim
                                            font.weight: Font.DemiBold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: root.batteryLabel(root.previewDevice)
                                            color: root.previewDevice?.batteryAvailable ? root.tuiYellow : root.tuiDim
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    TuiMeterBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18
                                        value: root.previewDevice?.batteryAvailable ? Math.round((root.previewDevice?.battery ?? 0) * 100) : 0
                                        accent: root.previewDevice?.batteryAvailable ? root.tuiYellow : root.tuiLine
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 18
                                rowSpacing: 10

                                DetailKey { text: "CLASS" }
                                DetailValue { text: root.deviceClass(root.previewDevice) }
                                DetailKey { text: "PAIR" }
                                DetailValue {
                                    text: root.previewDevice?.paired ? "yes" : "no"
                                    color: root.previewDevice?.paired ? root.tuiBlue : root.tuiDim
                                }
                                DetailKey { text: "LINK" }
                                DetailValue {
                                    text: root.previewDevice?.connected ? "connected" : "disconnected"
                                    color: root.previewDevice?.connected ? root.tuiAccent : root.tuiDim
                                }
                                DetailKey { text: "BATT" }
                                DetailValue { text: root.batteryLabel(root.previewDevice) }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TuiActionButton {
                                    label: "MANAGE"
                                    accent: root.tuiBlue
                                    enabledState: root.previewDevice !== null
                                    onClicked: root.openAction(root.previewDevice)
                                }

                                TuiActionButton {
                                    label: "SCAN"
                                    accent: root.tuiAccent
                                    onClicked: {
                                        if (Bluetooth.defaultAdapter) {
                                            Bluetooth.defaultAdapter.enabled = true;
                                            Bluetooth.defaultAdapter.discovering = true;
                                        }
                                    }
                                }

                                TuiActionButton {
                                    label: "BLUETUI"
                                    accent: root.tuiPurple
                                    onClicked: root.openBluetoothTui()
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "ADAPTER"
                        subtitle: "hci0"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 184
                        accent: BluetoothStatus.enabled ? root.tuiBlue : root.tuiRed

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 9

                            DetailKey { text: "POWER" }
                            DetailValue {
                                text: BluetoothStatus.enabled ? "ON" : "OFF"
                                color: BluetoothStatus.enabled ? root.tuiBlue : root.tuiRed
                            }
                            DetailKey { text: "SCAN" }
                            DetailValue {
                                text: Bluetooth.defaultAdapter?.discovering ? "running" : "idle"
                                color: Bluetooth.defaultAdapter?.discovering ? root.tuiYellow : root.tuiDim
                            }
                            DetailKey { text: "LINKED" }
                            DetailValue {
                                text: `${BluetoothStatus.activeDeviceCount}`
                                color: BluetoothStatus.activeDeviceCount > 0 ? root.tuiAccent : root.tuiDim
                            }
                            DetailKey { text: "TOTAL" }
                            DetailValue { text: `${BluetoothStatus.friendlyDeviceList.length}` }

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
                                    label: BluetoothStatus.enabled ? "DISABLE" : "ENABLE"
                                    accent: BluetoothStatus.enabled ? root.tuiRed : root.tuiBlue
                                    onClicked: root.toggleBluetoothPower()
                                }

                                TuiActionButton {
                                    label: "BLUEMAN"
                                    accent: root.tuiDim
                                    onClicked: root.openBluemanManager()
                                }
                            }
                        }
                    }
                }
            }

            // Footer
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: "transparent"
                border.width: 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: root.tuiLine
                    opacity: 0.28
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.leftMargin: 4
                    anchors.rightMargin: 6
                    spacing: 18

                    FooterHint { text: "enter/space/l manage" }
                    FooterHint { text: "r scan" }
                    FooterHint { text: "p power" }
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
            id: actionLayer
            anchors.fill: parent
            visible: root.actionOpen
            focus: visible
            z: 20

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q || event.key === Qt.Key_H) {
                    root.closeAction();
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
                    onClicked: root.closeAction()
                }
            }

            Rectangle {
                width: Math.min(620, parent.width - 74)
                height: 350
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
                            text: "BTCTL::ACTION"
                            color: root.tuiBlue
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
                        }

                        TuiText {
                            text: root.deviceState(root.selectedDevice).toUpperCase()
                            color: root.selectedDevice?.connected ? root.tuiAccent : root.tuiYellow
                            font.weight: Font.DemiBold
                        }
                    }

                    TuiText {
                        Layout.fillWidth: true
                        text: root.deviceName(root.selectedDevice)
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

                        DetailKey { text: "CLASS" }
                        DetailValue { text: root.deviceClass(root.selectedDevice) }
                        DetailKey { text: "BATT" }
                        DetailValue { text: root.batteryLabel(root.selectedDevice) }
                        DetailKey { text: "PAIR" }
                        DetailValue {
                            text: root.selectedDevice?.paired ? "yes" : "no"
                            color: root.selectedDevice?.paired ? root.tuiBlue : root.tuiDim
                        }
                        DetailKey { text: "LINK" }
                        DetailValue {
                            text: root.selectedDevice?.connected ? "connected" : "disconnected"
                            color: root.selectedDevice?.connected ? root.tuiAccent : root.tuiDim
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        TuiActionButton {
                            label: root.selectedDevice?.connected ? "DISCONNECT" : "CONNECT"
                            accent: root.selectedDevice?.connected ? root.tuiYellow : root.tuiAccent
                            onClicked: root.connectSelected()
                        }

                        TuiActionButton {
                            label: root.selectedDevice?.paired ? "FORGET" : "PAIR"
                            accent: root.selectedDevice?.paired ? root.tuiRed : root.tuiBlue
                            onClicked: root.pairSelected()
                        }

                        Item { Layout.fillWidth: true }

                        TuiActionButton {
                            label: "CANCEL"
                            accent: root.tuiDim
                            onClicked: root.closeAction()
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
        property color accent: root.tuiBlue
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
            height: 30
            spacing: 8

            StyledText {
                text: panel.title
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: root.tuiFg
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.tuiLine
                opacity: 0.28
            }

            StyledText {
                text: panel.subtitle
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.tuiDim
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        Item {
            id: panelContent
            anchors.fill: parent
            anchors.topMargin: 40
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
        font.weight: Font.DemiBold
    }

    component StatusPill: Item {
        id: pill

        property string label: ""
        property color tone: root.tuiBlue

        Layout.preferredWidth: Math.max(110, pillText.implicitWidth)
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        StyledText {
            id: pillText
            anchors.fill: parent
            text: pill.label
            color: pill.tone
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    component HeaderButton: Rectangle {
        id: button

        property string iconName: ""
        property color accent: root.tuiYellow
        signal clicked()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        color: buttonMouse.pressed ? "#4d4d4d" : buttonMouse.containsMouse ? "#3a3a3a" : "transparent"
        radius: TuiStyle.radius
        border.width: 0

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.iconName
            iconSize: 22
            color: button.accent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

}
