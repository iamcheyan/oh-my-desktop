import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets

ColumnLayout {
    id: root

    property var brightnessMonitor: ({ brightness: 0, setBrightness: function(){} })
    property var settingsRoot: null
    property string selectedOutputName: ""
    readonly property bool wideLayout: width >= 980
    readonly property var selectedOutput: configState.outputByName(selectedOutputName)

    readonly property bool hasPendingChanges: configState.hasPendingChanges
    readonly property bool applying: configState.applying
    function resetDrafts() { configState.resetDrafts() }
    function applyAll() { configState.applyAll() }

    width: parent ? parent.width : 900
    spacing: SettingsTokens.controlGap
    implicitHeight: {
        const viewportHeight = root.settingsRoot ? root.settingsRoot.height - 120 : 500;
        const contentHeight = contentGrid.implicitHeight + 50 + spacing + 12;
        return Math.max(viewportHeight, contentHeight);
    }

    function ensureSelection() {
        if (configState.outputByName(selectedOutputName))
            return;
        const focused = configState.outputs.find(output => output.focused);
        const fallback = focused || configState.outputs[0];
        selectedOutputName = fallback ? fallback.name : "";
    }

    DisplayConfigState {
        id: configState
    }

    Loader {
        active: configState.identifying
        sourceComponent: MonitorIdentifyOverlay {
            displayState: configState
        }
    }

    Connections {
        target: configState
        function onOutputsChanged() { root.ensureSelection(); }
    }

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: root.wideLayout ? 2 : 1
        columnSpacing: SettingsTokens.columnGap
        rowSpacing: SettingsTokens.columnGap

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: root.wideLayout ? (contentGrid.width - SettingsTokens.columnGap) / 2 : contentGrid.width
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    StyledText {
                        text: "Display layout"
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        text: configState.refreshing ? "Detecting displays..." : "Drag screens to match your physical arrangement."
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                MonitorCanvas {
                    Layout.fillWidth: true
                    Layout.preferredHeight: configState.visibleOutputs.length > 1 ? 300 : 220
                    displayState: configState
                    selectedOutputName: root.selectedOutputName
                    onOutputSelected: name => root.selectedOutputName = name
                }

                ButtonRow {

                    SettingsButton {
                        Layout.fillWidth: true
                        label: "Identify Displays"
                        iconName: "badge"
                        onClicked: configState.identify()
                    }

                    SettingsButton {
                        Layout.fillWidth: true
                        label: "Detect Displays"
                        iconName: "refresh"
                        enabledState: !configState.refreshing
                        onClicked: configState.refresh()
                    }
                }

                StyledText {
                    text: "Displays"
                    color: SettingsTokens.muted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: configState.visibleOutputs

                        OutputSummaryCard {
                            required property var modelData
                            displayState: configState
                            output: modelData
                            selected: modelData.name === root.selectedOutputName
                            onClicked: root.selectedOutputName = modelData.name
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: configState.errorText.length > 0
                    text: configState.errorText
                    color: SettingsTokens.danger
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        OutputDetailPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: root.wideLayout ? (contentGrid.width - SettingsTokens.columnGap) / 2 : contentGrid.width
            displayState: configState
            output: root.selectedOutput
            settingsRoot: root.settingsRoot
        }
    }

}
