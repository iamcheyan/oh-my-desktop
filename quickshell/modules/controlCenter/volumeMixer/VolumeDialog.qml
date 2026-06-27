pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

WindowDialog {
    id: root
    property bool isSink: true
    property int selectedApp: 0
    readonly property string modeLabel: isSink ? "OUTPUT" : "MIC"
    readonly property string streamLabel: isSink ? "APP MIXER" : "INPUT STREAMS"
    readonly property string deviceLabel: isSink ? "OUTPUT DEVICE" : "INPUT DEVICE"
    readonly property string masterLabel: isSink ? "MASTER OUTPUT" : "MASTER MIC"

    readonly property color tuiBg: TuiStyle.bg
    readonly property color tuiPanel: TuiStyle.panel
    readonly property color tuiPanelAlt: TuiStyle.panelAlt
    readonly property color tuiFg: TuiStyle.fg
    readonly property color tuiDim: TuiStyle.dim
    readonly property color tuiLine: TuiStyle.line
    readonly property color tuiGreen: TuiStyle.green
    readonly property color tuiYellow: TuiStyle.yellow
    readonly property color tuiBlue: TuiStyle.blue
    readonly property color tuiPurple: TuiStyle.purple
    readonly property color tuiRed: TuiStyle.red
    readonly property color tuiSelection: "#123a32"

    readonly property list<var> appPwNodes: isSink ? Audio.outputAppNodes : Audio.inputAppNodes
    readonly property list<var> devices: isSink ? Audio.outputDevices : Audio.inputDevices
    readonly property PwNode defaultNode: isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
    readonly property real masterVolume: defaultNode?.audio.volume ?? 0
    readonly property bool masterMuted: defaultNode?.audio.muted ?? false

    backgroundWidth: Math.min(980, Math.max(860, width - 36))
    backgroundHeight: Math.min(680, Math.max(560, height - 96))
    anchorPosition: 0
    focus: true

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function appDisplayName(node) {
        const app = Audio.appNodeDisplayName(node);
        const media = node.properties["media.name"];
        return media != undefined ? `${app} • ${media}` : app;
    }

    function adjustMaster(direction) {
        if (defaultNode)
            defaultNode.audio.volume = clamp(masterVolume + direction * 0.05, 0, 1);
    }

    function toggleMasterMute() {
        if (defaultNode)
            defaultNode.audio.muted = !defaultNode.audio.muted;
    }

    function adjustAppVolume(index, direction) {
        if (index < 0 || index >= appPwNodes.length)
            return;
        const node = appPwNodes[index];
        node.audio.volume = clamp(node.audio.volume + direction * 0.05, 0, 1);
    }

    function toggleAppMute(index) {
        if (index < 0 || index >= appPwNodes.length)
            return;
        const node = appPwNodes[index];
        node.audio.muted = !node.audio.muted;
    }

    function moveSelection(direction) {
        if (appPwNodes.length === 0)
            return;
        selectedApp = clamp(selectedApp + direction, 0, appPwNodes.length - 1);
    }

    function selectDevice(index) {
        if (index < 0 || index >= devices.length)
            return;
        if (isSink)
            Audio.setDefaultSink(devices[index]);
        else
            Audio.setDefaultSource(devices[index]);
    }

    function switchMode(nextIsSink) {
        if (isSink === nextIsSink)
            return;
        isSink = nextIsSink;
        selectedApp = 0;
    }

    function currentDeviceIndex() {
        return devices.findIndex(item => item.id === defaultNode?.id);
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            adjustMaster(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            adjustMaster(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            toggleMasterMute();
            event.accepted = true;
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (appPwNodes.length > 0)
                toggleAppMute(selectedApp);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            switchMode(!isSink);
            event.accepted = true;
        } else if (event.key === Qt.Key_D) {
            const devIdx = currentDeviceIndex();
            if (devices.length > 0)
                selectDevice((devIdx + 1) % devices.length);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismiss();
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            isSink = GlobalStates.barAudioIsSink;
            selectedApp = 0;
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
                            text: "OMD AUDIOCTL"
                            color: root.tuiBlue
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                        }

                        TuiText {
                            text: `mode=${root.modeLabel.toLowerCase()}  level=${Math.round(root.masterVolume * 100)}%  mute=${root.masterMuted ? "on" : "off"}  streams=${root.appPwNodes.length}  devices=${root.devices.length}`
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 8

                        ModeButton {
                            label: "OUTPUT"
                            active: root.isSink
                            accent: root.tuiBlue
                            onClicked: root.switchMode(true)
                        }

                        ModeButton {
                            label: "MIC"
                            active: !root.isSink
                            accent: root.tuiPurple
                            onClicked: root.switchMode(false)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                TuiPanel {
                    title: root.masterLabel
                    subtitle: root.masterMuted ? "muted" : "active"
                    Layout.preferredWidth: Math.min(530, Math.max(480, root.backgroundWidth * 0.58))
                    Layout.fillHeight: true
                    accent: root.masterMuted ? root.tuiRed : root.tuiBlue

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 14

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
                                        text: "LEVEL"
                                        color: root.tuiDim
                                        font.weight: Font.Bold
                                    }

                                    TuiText {
                                        Layout.fillWidth: true
                                        text: `${Math.round(root.masterVolume * 100)}%`
                                        color: root.masterMuted ? root.tuiRed : root.tuiBlue
                                        horizontalAlignment: Text.AlignRight
                                        font.weight: Font.Bold
                                    }
                                }

                                MeterBar {
                                    id: masterMeter
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    value: root.masterMuted ? 0 : root.masterVolume * 100
                                    accent: root.masterMuted ? root.tuiRed : root.tuiBlue
                                    interactive: !root.masterMuted
                                    focus: true
                                    onValueModified: function(newValue) {
                                        if (root.defaultNode)
                                            root.defaultNode.audio.volume = newValue / 100;
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TuiActionButton {
                                label: root.masterMuted ? "UNMUTE" : "MUTE"
                                accent: root.masterMuted ? root.tuiGreen : root.tuiRed
                                onClicked: root.toggleMasterMute()
                            }

                            TuiActionButton {
                                label: "- 5%"
                                accent: root.tuiBlue
                                onClicked: root.adjustMaster(-1)
                            }

                            TuiActionButton {
                                label: "+ 5%"
                                accent: root.tuiGreen
                                onClicked: root.adjustMaster(1)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: root.tuiPanelAlt
                            border.width: 1
                            border.color: root.tuiLine

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 5

                                TuiText {
                                    Layout.fillWidth: true
                                    text: "Quick Keys"
                                    color: root.tuiDim
                                    font.weight: Font.Bold
                                }

                                TuiText {
                                    Layout.fillWidth: true
                                    text: "h/l master volume"
                                    color: root.tuiPurple
                                }

                                TuiText {
                                    Layout.fillWidth: true
                                    text: "m toggle mute"
                                    color: root.tuiPurple
                                }

                                TuiText {
                                    Layout.fillWidth: true
                                    text: "tab output/mic"
                                    color: root.tuiPurple
                                }

                                TuiText {
                                    Layout.fillWidth: true
                                    text: "d cycle device"
                                    color: root.tuiPurple
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
                        title: root.deviceLabel
                        subtitle: `${root.devices.length} available`
                        Layout.fillWidth: true
                        Layout.preferredHeight: 146
                        accent: root.tuiYellow

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            Repeater {
                                model: root.devices

                                delegate: Rectangle {
                                    id: deviceRow
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: root.defaultNode?.id === modelData.id

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    color: active ? Qt.rgba(root.tuiYellow.r, root.tuiYellow.g, root.tuiYellow.b, 0.12) : "transparent"
                                    border.width: 1
                                    border.color: active ? root.tuiYellow : root.tuiLine

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        TuiText {
                                            text: deviceRow.active ? "::" : "--"
                                            color: deviceRow.active ? root.tuiYellow : root.tuiDim
                                            font.weight: Font.Bold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: Audio.friendlyDeviceName(deviceRow.modelData)
                                            color: deviceRow.active ? root.tuiFg : Qt.rgba(root.tuiFg.r, root.tuiFg.g, root.tuiFg.b, 0.78)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectDevice(deviceRow.index)
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    TuiPanel {
                        title: root.streamLabel
                        subtitle: root.appPwNodes.length === 0 ? "empty" : `${root.appPwNodes.length} apps`
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        accent: root.tuiGreen

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            Repeater {
                                model: root.appPwNodes

                                delegate: Rectangle {
                                    id: appRow
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: root.selectedApp === index
                                    readonly property bool muted: modelData.audio.muted
                                    readonly property real volume: modelData.audio.volume

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 52
                                    color: selected ? root.tuiSelection : root.tuiBg
                                    border.width: 1
                                    border.color: selected ? root.tuiGreen : root.tuiLine

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.selectedApp = appRow.index
                                        onClicked: root.toggleAppMute(appRow.index)
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            TuiText {
                                                text: appRow.selected ? "::" : "--"
                                                color: appRow.selected ? root.tuiGreen : root.tuiDim
                                                font.weight: Font.Bold
                                            }

                                            TuiText {
                                                Layout.fillWidth: true
                                                text: root.appDisplayName(appRow.modelData)
                                                color: appRow.muted ? root.tuiRed : (appRow.selected ? root.tuiFg : Qt.rgba(root.tuiFg.r, root.tuiFg.g, root.tuiFg.b, 0.78))
                                                elide: Text.ElideRight
                                                font.weight: Font.Bold
                                            }

                                            TuiText {
                                                text: appRow.muted ? "MUTE" : `${Math.round(appRow.volume * 100)}%`
                                                color: appRow.muted ? root.tuiRed : root.tuiGreen
                                                horizontalAlignment: Text.AlignRight
                                                font.weight: Font.Bold
                                            }
                                        }

                                        MeterBar {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 10
                                            value: appRow.muted ? 0 : appRow.volume * 100
                                            accent: appRow.muted ? root.tuiRed : root.tuiGreen
                                            interactive: !appRow.muted
                                            onValueModified: function(newValue) {
                                                appRow.modelData.audio.volume = newValue / 100;
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: root.appPwNodes.length === 0
                                color: root.tuiPanelAlt
                                border.width: 1
                                border.color: root.tuiLine

                                TuiText {
                                    anchors.centerIn: parent
                                    text: root.isSink ? "NO ACTIVE APPS" : "NO INPUT STREAMS"
                                    color: root.tuiDim
                                    font.weight: Font.Bold
                                }
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

                    FooterHint { text: "h/l master vol" }
                    FooterHint { text: "m mute" }
                    FooterHint { text: "j/k navigate" }
                    FooterHint { text: "space toggle app" }
                    FooterHint { text: "tab output/mic" }
                    FooterHint { text: "d cycle device" }
                    Item { Layout.fillWidth: true }
                    FooterHint {
                        text: "q/esc close"
                        color: root.tuiYellow
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

    component StatusText: Item {
        id: status

        property string label: ""
        property color tone: root.tuiYellow

        Layout.preferredWidth: Math.max(110, statusText.implicitWidth)
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        TuiText {
            id: statusText
            anchors.fill: parent
            text: status.label
            color: status.tone
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    component ModeButton: Rectangle {
        id: modeButton

        required property string label
        property bool active: false
        property color accent: root.tuiBlue
        signal clicked()

        Layout.preferredWidth: 86
        Layout.preferredHeight: 28
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            : modeMouse.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.10)
            : "transparent"
        border.width: 1
        border.color: active || modeMouse.containsMouse ? accent : root.tuiLine

        TuiText {
            anchors.centerIn: parent
            text: modeButton.label
            color: modeButton.active ? modeButton.accent : root.tuiDim
            font.weight: Font.Bold
        }

        MouseArea {
            id: modeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modeButton.clicked()
        }
    }

    component MeterBar: Item {
        id: meter

        property real value: 0
        property color accent: root.tuiGreen
        property bool interactive: false
        signal valueModified(real newValue)

        implicitWidth: meterRow.implicitWidth
        implicitHeight: meterRow.implicitHeight

        function valueFromX(mouseX) {
            const ratio = clamp(mouseX / meter.width, 0, 1);
            return ratio * 100;
        }

        function applyValue(newValue) {
            const clamped = clamp(newValue, 0, 100);
            if (interactive)
                meter.valueModified(clamped);
        }

        Row {
            id: meterRow
            anchors.fill: parent
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

        MouseArea {
            id: meterMouse
            anchors.fill: parent
            enabled: meter.interactive
            hoverEnabled: meter.interactive
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: meter.interactive ? (pressed ? Qt.DragMoveCursor : Qt.PointingHandCursor) : Qt.ArrowCursor
            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton)
                    meter.applyValue(meter.valueFromX(mouse.x));
                else if (mouse.button === Qt.RightButton)
                    meter.applyValue(meter.value - 10);
                mouse.accepted = true;
            }
            onPositionChanged: function(mouse) {
                if (pressedButtons & Qt.LeftButton)
                    meter.applyValue(meter.valueFromX(mouse.x));
            }
            onWheel: function(wheel) {
                if (!meter.interactive)
                    return;
                meter.applyValue(meter.value + (wheel.angleDelta.y > 0 ? 5 : -5));
                wheel.accepted = true;
            }
        }

        Keys.onPressed: function(event) {
            if (!meter.interactive)
                return;
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                meter.applyValue(meter.value - 5);
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
                meter.applyValue(meter.value + 5);
            else
                return;
            event.accepted = true;
        }
    }

}
