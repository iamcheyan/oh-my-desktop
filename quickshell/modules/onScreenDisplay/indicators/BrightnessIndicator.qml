pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    readonly property color tuiBg: TuiStyle.bg
    readonly property color tuiPanel: TuiStyle.panel
    readonly property color tuiFg: TuiStyle.fg
    readonly property color tuiDim: TuiStyle.dim
    readonly property color tuiLine: TuiStyle.line
    readonly property color tuiYellow: TuiStyle.yellow

    // Prefer the monitor that was actually adjusted (pinned by OSD trigger).
    property string targetScreenName: GlobalStates.osdBrightnessScreen
        || (Hyprland.focusedMonitor?.name ?? "")
    property var targetScreen: Quickshell.screens.find(s => s.name === root.targetScreenName)
        ?? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? null
    property var brightnessMonitor: Brightness.getMonitorForScreen(targetScreen)
    readonly property real brightnessValue: GlobalStates.osdBrightnessValue >= 0
        ? GlobalStates.osdBrightnessValue / 100
        : brightnessMonitor?.brightness ?? 0

    implicitWidth: 300 + Appearance.sizes.elevationMargin * 2
    implicitHeight: popupBg.implicitHeight + Appearance.sizes.elevationMargin * 2

    StyledRectangularShadow {
        target: popupBg
    }

    Rectangle {
        id: popupBg
        readonly property real innerPad: 12
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }

        color: root.tuiBg
        radius: TuiStyle.radius
        border.width: TuiStyle.borderWidth
        border.color: root.tuiLine
        clip: true

        implicitWidth: 300 + innerPad * 2
        implicitHeight: popupCol.implicitHeight + innerPad * 2

        ColumnLayout {
            id: popupCol
            anchors {
                fill: parent
                margins: popupBg.innerPad
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                CosmicIcon {
                    Layout.alignment: Qt.AlignVCenter
                    name: "status/display-brightness-symbolic"
                    iconSize: 24
                    color: root.tuiYellow
                }

                StyledText {
                    text: `${Math.round(root.brightnessValue * 100)}%`
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: root.tuiFg
                }

                Item { Layout.fillWidth: true }
            }

            TuiMeterBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                Layout.topMargin: 10
                Layout.bottomMargin: 14
                value: root.brightnessValue * 100
                accent: root.tuiYellow
            }
        }
    }

}
