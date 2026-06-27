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

    Keys.onPressed: (event) => {
        if (root.actionOpen) {
            if (event.key === Qt.Key_Escape) {
                root.closeAction();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.openAction(root.selectedOrCurrentDevice());
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
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
                border.color: root.tuiBlue

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        TuiText {
                            text: "OMD BTCTL"
                            color: root.tuiBlue
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                        }

                        TuiText {
                            text: `radio=${BluetoothStatus.enabled ? "on" : "off"}  scan=${Bluetooth.defaultAdapter?.discovering ? "running" : "ready"}  linked=${BluetoothStatus.activeDeviceCount}`
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    StatusPill {
                        label: Bluetooth.defaultAdapter?.discovering ? "SCANNING" : BluetoothStatus.connected ? "LINKED" : BluetoothStatus.enabled ? "READY" : "OFFLINE"
                        tone: Bluetooth.defaultAdapter?.discovering ? root.tuiYellow : BluetoothStatus.connected ? root.tuiGreen : BluetoothStatus.enabled ? root.tuiBlue : root.tuiRed
                    }
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
                                    greenColor: root.tuiGreen
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
                                        font.weight: Font.Bold
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
                        accent: root.previewDevice?.connected ? root.tuiGreen : root.tuiBlue

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
                                    color: root.previewDevice?.connected ? root.tuiGreen : root.tuiBlue
                                }

                                TuiText {
                                    Layout.fillWidth: true
                                    text: root.previewDevice ? root.deviceName(root.previewDevice) : "NO TARGET"
                                    color: root.previewDevice ? root.tuiFg : root.tuiDim
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.Bold
                                }

                                StatusPill {
                                    label: root.deviceState(root.previewDevice).toUpperCase()
                                    tone: root.previewDevice?.connected ? root.tuiGreen : root.tuiBlue
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
                                            text: "BATTERY"
                                            color: root.tuiDim
                                            font.weight: Font.Bold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: root.batteryLabel(root.previewDevice)
                                            color: root.previewDevice?.batteryAvailable ? root.tuiYellow : root.tuiDim
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.Bold
                                        }
                                    }

                                    MeterBar {
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
                                    color: root.previewDevice?.connected ? root.tuiGreen : root.tuiDim
                                }
                                DetailKey { text: "BATT" }
                                DetailValue { text: root.batteryLabel(root.previewDevice) }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ActionButton {
                                    label: "MANAGE"
                                    accent: root.tuiBlue
                                    enabledState: root.previewDevice !== null
                                    onClicked: root.openAction(root.previewDevice)
                                }

                                ActionButton {
                                    label: "SCAN"
                                    accent: root.tuiGreen
                                    onClicked: {
                                        if (Bluetooth.defaultAdapter) {
                                            Bluetooth.defaultAdapter.enabled = true;
                                            Bluetooth.defaultAdapter.discovering = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "ADAPTER"
                        subtitle: "hci0"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 146
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
                                color: BluetoothStatus.activeDeviceCount > 0 ? root.tuiGreen : root.tuiDim
                            }
                            DetailKey { text: "TOTAL" }
                            DetailValue { text: `${BluetoothStatus.friendlyDeviceList.length}` }
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
                    FooterHint { text: "r scan" }
                    FooterHint { text: "p power" }
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

        Item {
            id: actionLayer
            anchors.fill: parent
            visible: root.actionOpen
            focus: visible
            z: 20

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.closeAction();
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
                    onClicked: root.closeAction()
                }
            }

            Rectangle {
                width: Math.min(620, parent.width - 74)
                height: 350
                anchors.centerIn: parent
                color: root.tuiBg
                border.width: 1
                border.color: root.tuiBlue

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
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
                        }

                        TuiText {
                            text: root.deviceState(root.selectedDevice).toUpperCase()
                            color: root.selectedDevice?.connected ? root.tuiGreen : root.tuiYellow
                            font.weight: Font.Bold
                        }
                    }

                    TuiText {
                        Layout.fillWidth: true
                        text: root.deviceName(root.selectedDevice)
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
                            color: root.selectedDevice?.connected ? root.tuiGreen : root.tuiDim
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ActionButton {
                            label: root.selectedDevice?.connected ? "DISCONNECT" : "CONNECT"
                            accent: root.selectedDevice?.connected ? root.tuiYellow : root.tuiGreen
                            onClicked: root.connectSelected()
                        }

                        ActionButton {
                            label: root.selectedDevice?.paired ? "FORGET" : "PAIR"
                            accent: root.selectedDevice?.paired ? root.tuiRed : root.tuiBlue
                            onClicked: root.pairSelected()
                        }

                        Item { Layout.fillWidth: true }

                        ActionButton {
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
        font.family: Appearance.font.family.monospace
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

    component StatusPill: Item {
        id: pill

        property string label: ""
        property color tone: root.tuiBlue

        Layout.preferredWidth: Math.max(110, pillText.implicitWidth)
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        TuiText {
            id: pillText
            anchors.fill: parent
            text: pill.label
            color: pill.tone
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    component MeterBar: Row {
        id: meter

        property int value: 0
        property color accent: root.tuiYellow

        spacing: 3
        Repeater {
            model: 12
            Rectangle {
                required property int index
                width: Math.max(8, (meter.width - 33) / 12)
                height: meter.height
                color: index < Math.ceil(Math.max(0, Math.min(100, meter.value)) / 100 * 12) ? meter.accent : root.tuiLine
            }
        }
    }

    component ActionButton: Rectangle {
        id: action

        property string label: ""
        property color accent: root.tuiBlue
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
