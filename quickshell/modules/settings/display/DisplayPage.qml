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

    width: parent ? parent.width : 900
    spacing: 12
    implicitHeight: {
        const viewportHeight = (parent && parent.parent) ? parent.parent.height - 24 : 500;
        const contentHeight = contentGrid.implicitHeight + footerRow.implicitHeight + spacing + 12;
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

    Connections {
        target: configState
        function onOutputsChanged() { root.ensureSelection(); }
    }

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: root.wideLayout ? 2 : 1
        columnSpacing: 16
        rowSpacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: root.wideLayout ? Math.max(350, contentGrid.width * 0.38) : contentGrid.width
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "Display layout"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            text: configState.refreshing ? "Reading connected displays..." : `${configState.visibleOutputs.length} connected`
                            color: SettingsTokens.muted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    SettingsButton {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 42
                        label: ""
                        iconName: "badge"
                        onClicked: configState.identify()
                    }

                    SettingsButton {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 42
                        label: ""
                        iconName: "refresh"
                        enabledState: !configState.refreshing
                        onClicked: configState.refresh()
                    }
                }

                MonitorCanvas {
                    Layout.fillWidth: true
                    Layout.preferredHeight: configState.visibleOutputs.length > 1 ? 240 : 140
                    displayState: configState
                    selectedOutputName: root.selectedOutputName
                    onOutputSelected: name => root.selectedOutputName = name
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
            Layout.preferredWidth: root.wideLayout ? Math.max(500, contentGrid.width * 0.62 - 16) : contentGrid.width
            displayState: configState
            output: root.selectedOutput
            settingsRoot: root.settingsRoot
        }
    }

    RowLayout {
        id: footerRow
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 12

        SettingsButton {
            Layout.fillWidth: false
            Layout.preferredWidth: 110
            label: "Close"
            iconName: "close"
            onClicked: {
                if (root.settingsRoot)
                    root.settingsRoot.dismiss();
            }
        }

        Item { Layout.fillWidth: true }

        SettingsButton {
            Layout.fillWidth: false
            Layout.preferredWidth: 120
            label: "Discard"
            iconName: "undo"
            enabledState: configState.hasPendingChanges && !configState.applying
            onClicked: configState.resetDrafts()
        }

        SettingsButton {
            Layout.fillWidth: false
            Layout.preferredWidth: 120
            label: configState.applying ? "Applying..." : "Apply"
            iconName: "check"
            active: configState.hasPendingChanges
            enabledState: configState.hasPendingChanges && !configState.applying
            onClicked: configState.applyAll()
        }
    }
}
