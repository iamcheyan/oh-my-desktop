import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets

ColumnLayout {
    id: root

    property var brightnessMonitor: ({ brightness: 0, setBrightness: function(){} })
    property var settingsRoot: null

    width: parent ? parent.width : 760
    spacing: 18
    implicitHeight: content.implicitHeight

    DisplayConfigState {
        id: configState
    }

    property string optimizationMode: ""

    ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: 18

        PanelCard {
            Layout.fillWidth: true
            title: "Display layout"
            subtitle: configState.refreshing ? "Reading Hyprland outputs..." : `${configState.outputs.length} output(s)`

            MonitorCanvas {
                Layout.fillWidth: true
                displayState: configState
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Identify"
                    iconName: "badge"
                    onClicked: configState.identify()
                }
                SmallButton {
                    text: "Refresh"
                    iconName: "refresh"
                    onClicked: configState.refresh()
                }
                Item { Layout.fillWidth: true }
                SmallButton {
                    text: "Apply all"
                    iconName: "check"
                    primary: true
                    enabled: configState.hasPendingChanges && !configState.applying
                    onClicked: configState.applyAll()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: configState.errorText.length > 0
                text: configState.errorText
                color: SettingsTokens.fg
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Outputs"
            subtitle: configState.hasPendingChanges ? "Pending changes" : "Current configuration"

            Repeater {
                model: configState.outputs

                OutputCard {
                    required property var modelData
                    displayState: configState
                    output: modelData
                }
            }
        }

        PanelCard {
            Layout.fillWidth: true
            title: "Display Tools"

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "wlr-randr"
                    iconName: "open_in_new"
                    onClicked: { pageRoot.settingsRoot.dismiss(); Quickshell.execDetached(["foot", "--app-id=wlr-randr", "--title=wlr-randr", "--window-size-pixels=880x620", "-e", "wlr-randr"]) }
                }
            }
        }

    }

    component PanelCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        default property alias content: body.data

        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 34
        radius: 0
        color: SettingsTokens.card
        border.width: 1
        border.color: SettingsTokens.line

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 17
            spacing: 14

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 14
            }
        }
    }

    component SmallButton: Rectangle {
        id: button
        property string text: ""
        property string iconName: ""
        property bool primary: false
        signal clicked

        Layout.preferredHeight: 42
        implicitWidth: label.implicitWidth + 64
        radius: 13
        color: !enabled ? SettingsTokens.bg : primary ? TuiStyle.accentWash(TuiStyle.accent) : (mouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button)
        border.width: 1
        border.color: primary ? SettingsTokens.accent : SettingsTokens.buttonBorder
        opacity: enabled ? 1 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 9
            MaterialSymbol {
                text: button.iconName
                iconSize: 19
                color: primary ? SettingsTokens.accent : SettingsTokens.fg
            }
            StyledText {
                id: label
                text: button.text
                color: SettingsTokens.fg
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    component ToggleLine: RowLayout {
        id: toggleLine
        property string title: ""
        property string description: ""
        property bool checked: false
        signal toggled

        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText { text: toggleLine.title; color: SettingsTokens.fg; font.pixelSize: 14; font.weight: Font.DemiBold }
            StyledText { text: toggleLine.description; color: SettingsTokens.dim; font.pixelSize: 13 }
        }
        Switch {
            id: control
            checked: toggleLine.checked
            onToggled: toggleLine.toggled()

            indicator: Rectangle {
                implicitWidth: 46
                implicitHeight: 26
                x: control.leftPadding
                y: parent.height / 2 - height / 2
                radius: height / 2
                color: control.checked ? SettingsTokens.accent : SettingsTokens.line

                Rectangle {
                    x: control.checked ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: control.checked ? "#111111" : "#dedede"
                    Behavior on x { NumberAnimation { duration: 110 } }
                }
            }
        }
    }
}
