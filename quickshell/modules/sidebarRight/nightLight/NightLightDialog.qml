import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen) ?? ({ brightness: 0, setBrightness: function(){} })
    property int selectedControl: 0

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
    readonly property int controlCount: 7
    readonly property string selectedTitle: controlTitle(selectedControl)
    readonly property string selectedDescription: controlDescription(selectedControl)
    readonly property bool selectedIsToggle: selectedControl === 0 || selectedControl === 1 || selectedControl === 4 || selectedControl === 5
    readonly property real selectedValue: controlValue(selectedControl)

    backgroundWidth: Math.min(980, Math.max(860, width - 36))
    backgroundHeight: Math.min(680, Math.max(560, height - 96))
    anchorPosition: 0
    focus: true

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function controlTitle(index) {
        return [
            "NIGHT LIGHT",
            "AUTO SCHEDULE",
            "TEMPERATURE",
            "GAMMA",
            "CONTENT SHADER",
            "AUTO BRIGHTNESS",
            "DISPLAY BRIGHTNESS"
        ][index] ?? "";
    }

    function controlKey(index) {
        return [
            "NLIGHT",
            "AUTO",
            "TEMP",
            "GAMMA",
            "SHADER",
            "ABRIGHT",
            "BRIGHT"
        ][index] ?? "";
    }

    function controlDescription(index) {
        return [
            "Manual hyprsunset color temperature override.",
            `Automatic schedule ${Hyprsunset.from} -> ${Hyprsunset.to}.`,
            "Warmer values reduce blue light more aggressively.",
            "Hyprsunset gamma curve for screen dimming.",
            "Hyprland screen shader that dims bright content.",
            "Automatic physical brightness adjustment.",
            "Current display brightness for the focused screen."
        ][index] ?? "";
    }

    function controlStatus(index) {
        if (index === 0)
            return Hyprsunset.temperatureActive ? "ON" : "OFF";
        if (index === 1)
            return Config.options.light.night.automatic ? "AUTO" : "MANUAL";
        if (index === 2)
            return `${Math.round(Config.options.light.night.colorTemperature)}K`;
        if (index === 3)
            return `${Math.round(Hyprsunset.gamma)}%`;
        if (index === 4)
            return HyprlandAntiFlashbangShader.enabled ? "ON" : "OFF";
        if (index === 5)
            return Config.options.light.antiFlashbang.enable ? "ON" : "OFF";
        if (index === 6)
            return `${Math.round(root.brightnessMonitor.brightness * 100)}%`;
        return "";
    }

    function controlValue(index) {
        if (index === 0)
            return Hyprsunset.temperatureActive ? 100 : 0;
        if (index === 1)
            return Config.options.light.night.automatic ? 100 : 0;
        if (index === 2)
            return (6500 - Config.options.light.night.colorTemperature) / (6500 - 1200) * 100;
        if (index === 3)
            return (Hyprsunset.gamma - Hyprsunset.gammaLowerLimit) / (100 - Hyprsunset.gammaLowerLimit) * 100;
        if (index === 4)
            return HyprlandAntiFlashbangShader.enabled ? 100 : 0;
        if (index === 5)
            return Config.options.light.antiFlashbang.enable ? 100 : 0;
        if (index === 6)
            return root.brightnessMonitor.brightness * 100;
        return 0;
    }

    function controlTone(index) {
        if (index === 0)
            return Hyprsunset.temperatureActive ? root.tuiYellow : root.tuiDim;
        if (index === 1)
            return Config.options.light.night.automatic ? root.tuiBlue : root.tuiDim;
        if (index === 2)
            return root.tuiYellow;
        if (index === 3)
            return root.tuiPurple;
        if (index === 4)
            return HyprlandAntiFlashbangShader.enabled ? root.tuiGreen : root.tuiDim;
        if (index === 5)
            return Config.options.light.antiFlashbang.enable ? root.tuiGreen : root.tuiDim;
        if (index === 6)
            return root.tuiBlue;
        return root.tuiFg;
    }

    function toggleControl(index) {
        if (index === 0) {
            Hyprsunset.toggleTemperature(!Hyprsunset.temperatureActive);
        } else if (index === 1) {
            Config.options.light.night.automatic = !Config.options.light.night.automatic;
        } else if (index === 4) {
            if (HyprlandAntiFlashbangShader.enabled)
                HyprlandAntiFlashbangShader.disable();
            else
                HyprlandAntiFlashbangShader.enable();
        } else if (index === 5) {
            Config.options.light.antiFlashbang.enable = !Config.options.light.antiFlashbang.enable;
        }
    }

    function adjustControl(index, direction) {
        if (index === 0 || index === 1 || index === 4 || index === 5) {
            toggleControl(index);
        } else if (index === 2) {
            Config.options.light.night.colorTemperature = clamp(Config.options.light.night.colorTemperature - direction * 100, 1200, 6500);
        } else if (index === 3) {
            Hyprsunset.setGamma(clamp(Hyprsunset.gamma + direction * 5, Hyprsunset.gammaLowerLimit, 100));
        } else if (index === 6) {
            root.brightnessMonitor.setBrightness(clamp(root.brightnessMonitor.brightness + direction * 0.05, 0, 1));
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            selectedControl = Math.min(controlCount - 1, selectedControl + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            selectedControl = Math.max(0, selectedControl - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_G) {
            selectedControl = event.modifiers & Qt.ShiftModifier ? controlCount - 1 : 0;
            event.accepted = true;
        } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            adjustControl(selectedControl, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            adjustControl(selectedControl, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (selectedIsToggle)
                toggleControl(selectedControl);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismiss();
            event.accepted = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            selectedControl = 0;
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
                border.color: root.tuiYellow

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        TuiText {
                            text: "OMD LIGHTCTL"
                            color: root.tuiYellow
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                        }

                        TuiText {
                            text: `night=${Hyprsunset.temperatureActive ? "on" : "off"}  auto=${Config.options.light.night.automatic ? "on" : "off"}  temp=${Math.round(Config.options.light.night.colorTemperature)}K`
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    StatusText {
                        label: Hyprsunset.temperatureActive ? "ACTIVE" : "READY"
                        tone: Hyprsunset.temperatureActive ? root.tuiYellow : root.tuiBlue
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                TuiPanel {
                    title: "CONTROL BUS"
                    subtitle: `${root.controlCount} channels`
                    Layout.preferredWidth: Math.min(530, Math.max(480, root.backgroundWidth * 0.58))
                    Layout.fillHeight: true
                    accent: root.tuiYellow

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
                                Layout.preferredWidth: 78
                                text: "KEY"
                                horizontalAlignment: Text.AlignLeft
                            }
                            HeaderCell {
                                Layout.fillWidth: true
                                text: "CONTROL"
                                horizontalAlignment: Text.AlignLeft
                            }
                            HeaderCell {
                                Layout.preferredWidth: 92
                                text: "STATE"
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.tuiLine
                        }

                        Repeater {
                            model: root.controlCount
                            delegate: ControlRow {
                                required property int index
                                controlIndex: index
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
                        subtitle: root.selectedIsToggle ? "toggle" : "analog"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        accent: root.controlTone(root.selectedControl)

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                TuiText {
                                    Layout.fillWidth: true
                                    text: root.selectedTitle
                                    color: root.tuiFg
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.Bold
                                }

                                StatusText {
                                    label: root.controlStatus(root.selectedControl)
                                    tone: root.controlTone(root.selectedControl)
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
                                            text: root.selectedIsToggle ? "STATE" : "LEVEL"
                                            color: root.tuiDim
                                            font.weight: Font.Bold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: root.controlStatus(root.selectedControl)
                                            color: root.controlTone(root.selectedControl)
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.Bold
                                        }
                                    }

                                    MeterBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 18
                                        value: root.selectedValue
                                        accent: root.controlTone(root.selectedControl)
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 18
                                rowSpacing: 10

                                DetailKey { text: "DESC" }
                                DetailValue { text: root.selectedDescription }
                                DetailKey { text: "TEMP" }
                                DetailValue { text: `${Math.round(Config.options.light.night.colorTemperature)}K` }
                                DetailKey { text: "GAMMA" }
                                DetailValue { text: `${Math.round(Hyprsunset.gamma)}%` }
                                DetailKey { text: "BRIGHT" }
                                DetailValue { text: `${Math.round(root.brightnessMonitor.brightness * 100)}%` }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ActionButton {
                                    label: root.selectedIsToggle ? "TOGGLE" : "- STEP"
                                    accent: root.selectedIsToggle ? root.tuiYellow : root.tuiBlue
                                    onClicked: {
                                        if (root.selectedIsToggle)
                                            root.toggleControl(root.selectedControl);
                                        else
                                            root.adjustControl(root.selectedControl, -1);
                                    }
                                }

                                ActionButton {
                                    visible: !root.selectedIsToggle
                                    label: "+ STEP"
                                    accent: root.tuiGreen
                                    onClicked: root.adjustControl(root.selectedControl, 1)
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "SCHEDULE"
                        subtitle: Config.options.light.night.automatic ? "armed" : "manual"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 146
                        accent: Config.options.light.night.automatic ? root.tuiBlue : root.tuiDim

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 9

                            DetailKey { text: "FROM" }
                            DetailValue { text: Hyprsunset.from }
                            DetailKey { text: "TO" }
                            DetailValue { text: Hyprsunset.to }
                            DetailKey { text: "MODE" }
                            DetailValue {
                                text: Config.options.light.night.automatic ? "automatic" : "manual"
                                color: Config.options.light.night.automatic ? root.tuiBlue : root.tuiDim
                            }
                            DetailKey { text: "SHADER" }
                            DetailValue {
                                text: HyprlandAntiFlashbangShader.enabled ? "enabled" : "disabled"
                                color: HyprlandAntiFlashbangShader.enabled ? root.tuiGreen : root.tuiDim
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

                    FooterHint { text: "enter/space toggle" }
                    FooterHint { text: "h/l adjust" }
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
    }

    component ControlRow: Rectangle {
        id: row

        required property int controlIndex
        readonly property bool selected: root.selectedControl === controlIndex

        Layout.fillWidth: true
        Layout.preferredHeight: 38
        color: selected ? root.tuiSelection : "transparent"
        border.width: selected ? 1 : 0
        border.color: selected ? root.controlTone(controlIndex) : "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.selectedControl = row.controlIndex;
                if (root.selectedIsToggle)
                    root.toggleControl(row.controlIndex);
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            TuiText {
                Layout.preferredWidth: 22
                text: row.selected ? ":" : " "
                color: row.selected ? root.controlTone(row.controlIndex) : root.tuiDim
                horizontalAlignment: Text.AlignHCenter
            }

            TuiText {
                Layout.preferredWidth: 78
                text: root.controlKey(row.controlIndex)
                color: row.selected ? root.tuiFg : root.tuiDim
                font.weight: Font.Bold
            }

            TuiText {
                Layout.fillWidth: true
                text: root.controlTitle(row.controlIndex)
                color: row.selected ? root.tuiFg : Qt.rgba(root.tuiFg.r, root.tuiFg.g, root.tuiFg.b, 0.78)
                elide: Text.ElideRight
            }

            TuiText {
                Layout.preferredWidth: 92
                text: root.controlStatus(row.controlIndex)
                color: row.selected ? root.tuiFg : root.controlTone(row.controlIndex)
                horizontalAlignment: Text.AlignRight
                font.weight: row.selected ? Font.Bold : Font.Normal
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.tuiLine
            opacity: row.selected ? 0 : 0.55
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
        property color accent: root.tuiYellow
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

    component MeterBar: Row {
        id: meter

        property real value: 0
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
        property color accent: root.tuiYellow
        signal clicked()

        Layout.preferredWidth: Math.max(92, actionText.implicitWidth + 24)
        Layout.preferredHeight: 32
        color: actionMouse.containsMouse ? Qt.rgba(action.accent.r, action.accent.g, action.accent.b, 0.16) : root.tuiPanel
        border.width: 1
        border.color: action.accent

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
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }
}
