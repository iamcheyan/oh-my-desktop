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
    readonly property int controlCount: 8
    readonly property var controlOrder: [0, 7, 1, 4, 2, 3, 5, 6]
    readonly property string selectedTitle: controlTitle(selectedControl)
    readonly property string selectedDescription: controlDescription(selectedControl)
    readonly property bool selectedIsToggle: selectedControl === 1 || selectedControl === 4 || selectedControl === 5 || selectedControl === 6
    readonly property bool selectedIsAction: selectedControl === 7
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
            "DISPLAY BRIGHTNESS",
            "NIGHT LIGHT",
            "TEMPERATURE",
            "GAMMA",
            "AUTO SCHEDULE",
            "CONTENT SHADER",
            "AUTO BRIGHTNESS",
            "RESET TONE"
        ][index] ?? "";
    }

    function controlKey(index) {
        return [
            "BRIGHT",
            "NIGHT",
            "TEMP",
            "GAMMA",
            "AUTO",
            "SHADER",
            "ABRIGHT",
            "RESET"
        ][index] ?? "";
    }

    function controlDescription(index) {
        return [
            "Current display brightness for the focused screen.",
            "Manual hyprsunset color temperature override.",
            "Warmer values reduce blue light more aggressively.",
            "Hyprsunset gamma curve for screen dimming.",
            `Automatic schedule ${Hyprsunset.from} -> ${Hyprsunset.to}.`,
            "Hyprland screen shader that dims bright content.",
            "Automatic physical brightness adjustment.",
            "Restore neutral temperature and gamma values."
        ][index] ?? "";
    }

    function controlStatus(index) {
        if (index === 0)
            return `${Math.round(root.brightnessMonitor.brightness * 100)}%`;
        if (index === 1)
            return Hyprsunset.temperatureActive ? "ON" : "OFF";
        if (index === 2)
            return `${Math.round(Config.options.light.night.colorTemperature)}K`;
        if (index === 3)
            return `${Math.round(Hyprsunset.gamma)}%`;
        if (index === 4)
            return Config.options.light.night.automatic ? "AUTO" : "MANUAL";
        if (index === 5)
            return HyprlandAntiFlashbangShader.enabled ? "ON" : "OFF";
        if (index === 6)
            return Config.options.light.antiFlashbang.enable ? "ON" : "OFF";
        if (index === 7)
            return "READY";
        return "";
    }

    function controlValue(index) {
        if (index === 0)
            return root.brightnessMonitor.brightness * 100;
        if (index === 1)
            return Hyprsunset.temperatureActive ? 100 : 0;
        if (index === 2)
            return (6500 - Config.options.light.night.colorTemperature) / (6500 - 1200) * 100;
        if (index === 3)
            return (Hyprsunset.gamma - Hyprsunset.gammaLowerLimit) / (100 - Hyprsunset.gammaLowerLimit) * 100;
        if (index === 4)
            return Config.options.light.night.automatic ? 100 : 0;
        if (index === 5)
            return HyprlandAntiFlashbangShader.enabled ? 100 : 0;
        if (index === 6)
            return Config.options.light.antiFlashbang.enable ? 100 : 0;
        if (index === 7)
            return 0;
        return 0;
    }

    function controlTone(index) {
        if (index === 0)
            return root.tuiBlue;
        if (index === 1)
            return Hyprsunset.temperatureActive ? root.tuiYellow : root.tuiDim;
        if (index === 2)
            return root.tuiYellow;
        if (index === 3)
            return root.tuiPurple;
        if (index === 4)
            return Config.options.light.night.automatic ? root.tuiBlue : root.tuiDim;
        if (index === 5)
            return HyprlandAntiFlashbangShader.enabled ? root.tuiAccent : root.tuiDim;
        if (index === 6)
            return Config.options.light.antiFlashbang.enable ? root.tuiAccent : root.tuiDim;
        if (index === 7)
            return root.tuiRed;
        return root.tuiFg;
    }

    function toggleControl(index) {
        if (index === 1) {
            Hyprsunset.toggleTemperature(!Hyprsunset.temperatureActive);
        } else if (index === 4) {
            Config.options.light.night.automatic = !Config.options.light.night.automatic;
        } else if (index === 5) {
            if (HyprlandAntiFlashbangShader.enabled)
                HyprlandAntiFlashbangShader.disable();
            else
                HyprlandAntiFlashbangShader.enable();
        } else if (index === 6) {
            Config.options.light.antiFlashbang.enable = !Config.options.light.antiFlashbang.enable;
        }
    }

    function resetTone() {
        Config.options.light.night.colorTemperature = Hyprsunset.defaultColorTemperature;
        Hyprsunset.setGamma(100);
        if (Hyprsunset.temperatureActive)
            Hyprsunset.disableTemperature();
    }

    function adjustControl(index, direction) {
        if (index === 0) {
            root.brightnessMonitor.setBrightness(clamp(root.brightnessMonitor.brightness + direction * 0.05, 0, 1));
        } else if (index === 1 || index === 4 || index === 5 || index === 6) {
            toggleControl(index);
        } else if (index === 2) {
            Config.options.light.night.colorTemperature = clamp(Config.options.light.night.colorTemperature - direction * 100, 1200, 6500);
        } else if (index === 3) {
            Hyprsunset.setGamma(clamp(Hyprsunset.gamma + direction * 5, Hyprsunset.gammaLowerLimit, 100));
        } else if (index === 7) {
            resetTone();
        }
    }

    function moveSelection(direction) {
        const currentPosition = controlOrder.indexOf(selectedControl);
        const nextPosition = clamp(currentPosition + direction, 0, controlOrder.length - 1);
        selectedControl = controlOrder[nextPosition];
    }

    function handleControlKey(event, index) {
        if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
            selectedControl = index;
            adjustControl(index, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
            selectedControl = index;
            adjustControl(index, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            selectedControl = index;
            if (selectedIsToggle)
                toggleControl(index);
            else if (selectedIsAction)
                resetTone();
            event.accepted = true;
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_G) {
            selectedControl = event.modifiers & Qt.ShiftModifier ? controlOrder[controlOrder.length - 1] : controlOrder[0];
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
            else if (selectedIsAction)
                resetTone();
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
                            text: "OMD DISPLAYCTL"
                            color: root.tuiBlue
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }

                        TuiText {
                            text: `brightness=${Math.round(root.brightnessMonitor.brightness * 100)}%  temp=${Math.round(Config.options.light.night.colorTemperature)}K  gamma=${Math.round(Hyprsunset.gamma)}%`
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    StatusText {
                        label: "SCREEN"
                        tone: root.tuiBlue
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                TuiPanel {
                    title: "SCREEN CONTROLS"
                    subtitle: "display deck"
                    Layout.preferredWidth: Math.min(530, Math.max(480, root.backgroundWidth * 0.58))
                    Layout.fillHeight: true
                    accent: root.tuiYellow

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 10

                                ControlGroup {
                                    title: "DISPLAY"
                                    accent: root.tuiBlue
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ControlTile {
                                        controlIndex: 0
                                        title: "Brightness"
                                        valueText: root.controlStatus(0)
                                        detail: "focused panel"
                                    }

                                    ControlTile {
                                        controlIndex: 7
                                        title: "Reset Tone"
                                        valueText: root.controlStatus(7)
                                        detail: "neutral color"
                                    }
                                }

                                ControlGroup {
                                    title: "NIGHT"
                                    accent: root.tuiYellow
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ControlTile {
                                        controlIndex: 1
                                        title: "Night Light"
                                        valueText: root.controlStatus(1)
                                        detail: "manual"
                                    }

                                    ControlTile {
                                        controlIndex: 4
                                        title: "Schedule"
                                        valueText: root.controlStatus(4)
                                        detail: `${Hyprsunset.from}-${Hyprsunset.to}`
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 10

                                ControlGroup {
                                    title: "TONE CURVE"
                                    accent: root.tuiPurple
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ControlTile {
                                        controlIndex: 2
                                        title: "Temp"
                                        valueText: root.controlStatus(2)
                                        detail: "1200-6500K"
                                    }

                                    ControlTile {
                                        controlIndex: 3
                                        title: "Gamma"
                                        valueText: root.controlStatus(3)
                                        detail: "25-100%"
                                    }
                                }

                                ControlGroup {
                                    title: "PROTECTION"
                                    accent: root.tuiAccent
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ControlTile {
                                        controlIndex: 5
                                        title: "Shader"
                                        valueText: root.controlStatus(5)
                                        detail: "content dim"
                                    }

                                    ControlTile {
                                        controlIndex: 6
                                        title: "Auto Bright"
                                        valueText: root.controlStatus(6)
                                        detail: "physical"
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#222222"
                                        radius: TuiStyle.radius
                                        border.width: 0

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 5

                                            TuiText {
                                                Layout.fillWidth: true
                                                text: "Quick Keys"
                                                color: root.tuiDim
                                                font.weight: Font.DemiBold
                                            }

                                            TuiText {
                                                Layout.fillWidth: true
                                                text: "h/l adjust"
                                                color: root.tuiPurple
                                            }

                                            TuiText {
                                                Layout.fillWidth: true
                                                text: "space toggle"
                                                color: root.tuiPurple
                                            }
                                        }
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
                        subtitle: root.selectedIsAction ? "action" : root.selectedIsToggle ? "toggle" : "analog"
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
                                    font.weight: Font.DemiBold
                                }

                                StatusText {
                                    label: root.controlStatus(root.selectedControl)
                                    tone: root.controlTone(root.selectedControl)
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
                                            text: root.selectedIsToggle ? "STATE" : "LEVEL"
                                            color: root.tuiDim
                                            font.weight: Font.DemiBold
                                        }

                                        TuiText {
                                            Layout.fillWidth: true
                                            text: root.controlStatus(root.selectedControl)
                                            color: root.controlTone(root.selectedControl)
                                            horizontalAlignment: Text.AlignRight
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    TuiMeterBar {
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
                                DetailKey { text: "NIGHT" }
                                DetailValue {
                                    text: Hyprsunset.temperatureActive ? "active" : "inactive"
                                    color: Hyprsunset.temperatureActive ? root.tuiYellow : root.tuiDim
                                }
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TuiActionButton {
                                    label: root.selectedIsAction ? "RESET" : root.selectedIsToggle ? "TOGGLE" : "- STEP"
                                    accent: root.selectedIsAction ? root.tuiRed : root.selectedIsToggle ? root.tuiYellow : root.tuiBlue
                                    onClicked: {
                                        if (root.selectedIsAction)
                                            root.resetTone();
                                        else if (root.selectedIsToggle)
                                            root.toggleControl(root.selectedControl);
                                        else
                                            root.adjustControl(root.selectedControl, -1);
                                    }
                                }

                                TuiActionButton {
                                    visible: !root.selectedIsToggle && !root.selectedIsAction
                                    label: "+ STEP"
                                    accent: root.tuiAccent
                                    onClicked: root.adjustControl(root.selectedControl, 1)
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "SCREEN STATE"
                        subtitle: Config.options.light.night.automatic ? "schedule armed" : "manual"
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
                            DetailKey { text: "BRIGHT" }
                            DetailValue {
                                text: `${Math.round(root.brightnessMonitor.brightness * 100)}%`
                                color: root.tuiBlue
                            }
                            DetailKey { text: "MODE" }
                            DetailValue {
                                text: Config.options.light.night.automatic ? "automatic" : "manual"
                                color: Config.options.light.night.automatic ? root.tuiBlue : root.tuiDim
                            }
                            DetailKey { text: "SHADER" }
                            DetailValue {
                                text: HyprlandAntiFlashbangShader.enabled ? "enabled" : "disabled"
                                color: HyprlandAntiFlashbangShader.enabled ? root.tuiAccent : root.tuiDim
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

    component TuiText: StyledText {
        color: root.tuiFg
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        textFormat: Text.PlainText
    }

    component ControlGroup: Rectangle {
        id: group

        required property string title
        property color accent: root.tuiYellow
        default property alias content: groupContent.data

        color: "#222222"
        radius: TuiStyle.radius
        border.width: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TuiText {
                    text: group.title
                    color: group.accent
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.tuiLine
                }
            }

            ColumnLayout {
                id: groupContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
            }
        }
    }

    component ControlTile: Rectangle {
        id: tile

        required property int controlIndex
        required property string title
        required property string valueText
        property string detail: ""
        readonly property bool selected: root.selectedControl === controlIndex

        Layout.fillWidth: true
        Layout.fillHeight: true
        focus: selected
        activeFocusOnTab: true
        color: selected ? root.tuiSelection : "#1a1a1a"
        radius: TuiStyle.radius
        border.width: 0

        Keys.onPressed: (event) => root.handleControlKey(event, tile.controlIndex)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.selectedControl = tile.controlIndex
            onClicked: {
                root.selectedControl = tile.controlIndex;
                tile.forceActiveFocus();
                if (root.selectedIsToggle)
                    root.toggleControl(tile.controlIndex);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TuiText {
                    text: tile.selected ? "::" : "--"
                    color: tile.selected ? root.controlTone(tile.controlIndex) : root.tuiDim
                    font.weight: Font.DemiBold
                }

                TuiText {
                    Layout.fillWidth: true
                    text: tile.title
                    color: tile.selected ? root.tuiFg : Qt.rgba(root.tuiFg.r, root.tuiFg.g, root.tuiFg.b, 0.78)
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                }

                TuiText {
                    text: tile.valueText
                    color: root.controlTone(tile.controlIndex)
                    horizontalAlignment: Text.AlignRight
                    font.weight: Font.DemiBold
                }
            }

            TuiMeterBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                value: root.controlValue(tile.controlIndex)
                accent: root.controlTone(tile.controlIndex)
            }

            TuiText {
                Layout.fillWidth: true
                text: tile.detail
                color: root.tuiDim
                elide: Text.ElideRight
            }
        }
    }

    component TuiPanel: Item {
        id: panel

        required property string title
        property string subtitle: ""
        property color accent: root.tuiYellow
        default property alias content: panelContent.data

        Rectangle {
            anchors.fill: parent
            color: "transparent"
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
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

}
