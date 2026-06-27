import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property string settingsQmlPath: Quickshell.shellPath("settings.qml")
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

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    Rectangle {
        id: sidebarRightBackground
        anchors.fill: parent
        implicitHeight: parent.height
        implicitWidth: parent.width
        color: root.tuiBg
        border.width: 1
        border.color: root.tuiLine
        radius: 0

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

                        StyledText {
                            text: "OMD NOTIFYCTL"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: root.tuiBlue
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `${Notifications.list.length} queued  unread=${Notifications.unread}  silent=${Notifications.silent ? "yes" : "no"}`
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.tuiDim
                            elide: Text.ElideRight
                        }
                    }

                    StatusText {
                        label: Notifications.silent ? "SILENT" : "READY"
                        tone: Notifications.silent ? root.tuiPurple : root.tuiGreen
                    }
                }
            }

            RowLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 12

                TuiPanel {
                    title: "NOTIFICATIONS"
                    subtitle: Notifications.list.length === 0 ? "empty" : `${Notifications.list.length} entries`
                    accent: root.tuiGreen
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    CenterWidgetGroup {
                        anchors.fill: parent
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: Math.min(300, Math.max(260, parent.width * 0.32))
                    Layout.fillHeight: true
                    spacing: 12

                    TuiPanel {
                        title: "SYSTEM"
                        subtitle: "commands"
                        accent: root.tuiPurple
                        Layout.fillWidth: true
                        Layout.preferredHeight: 250

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            CommandTile {
                                title: "Reload"
                                detail: "Hyprland + Quickshell"
                                iconName: "restart_alt"
                                accent: root.tuiYellow
                                onClicked: {
                                    Quickshell.execDetached(["hyprctl", "reload"])
                                    Quickshell.reload(true);
                                }
                            }

                            CommandTile {
                                title: "Settings"
                                detail: "Open Quickshell settings"
                                iconName: "settings"
                                accent: root.tuiBlue
                                onClicked: {
                                    GlobalStates.sidebarRightOpen = false;
                                    Quickshell.execDetached(["qs", "-p", root.settingsQmlPath]);
                                }
                            }

                            CommandTile {
                                title: "Session"
                                detail: "Lock, logout, power"
                                iconName: "power_settings_new"
                                accent: root.tuiRed
                                onClicked: {
                                    GlobalStates.sessionOpen = true;
                                }
                            }
                        }
                    }

                    TuiPanel {
                        title: "STATE"
                        subtitle: "notification bus"
                        accent: Notifications.silent ? root.tuiPurple : root.tuiGreen
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            DetailRow {
                                keyText: "UNREAD"
                                valueText: `${Notifications.unread}`
                                valueColor: Notifications.unread > 0 ? root.tuiYellow : root.tuiDim
                            }

                            DetailRow {
                                keyText: "TOTAL"
                                valueText: `${Notifications.list.length}`
                                valueColor: Notifications.list.length > 0 ? root.tuiGreen : root.tuiDim
                            }

                            DetailRow {
                                keyText: "MODE"
                                valueText: Notifications.silent ? "silent" : "normal"
                                valueColor: Notifications.silent ? root.tuiPurple : root.tuiGreen
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: root.tuiLine
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "q/esc close"
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.tuiPurple
                            }
                        }
                    }
                }
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

            StyledText {
                text: panel.title
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: panel.accent
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.tuiLine
            }

            StyledText {
                text: panel.subtitle
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
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

    component StatusText: Item {
        id: status

        property string label: ""
        property color tone: root.tuiYellow

        Layout.preferredWidth: Math.max(90, statusText.implicitWidth)
        Layout.preferredHeight: 26
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        StyledText {
            id: statusText
            anchors.fill: parent
            text: status.label
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Bold
            color: status.tone
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    component CommandTile: Rectangle {
        id: tile

        property string title: ""
        property string detail: ""
        property string iconName: ""
        property color accent: root.tuiYellow
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        color: commandMouse.pressed ? root.tuiSelection : commandMouse.containsMouse ? root.tuiPanelAlt : root.tuiBg
        border.width: 1
        border.color: commandMouse.containsMouse ? tile.accent : root.tuiLine

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            MaterialSymbol {
                text: tile.iconName
                iconSize: Appearance.font.pixelSize.huge
                color: tile.accent
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: tile.title
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    color: root.tuiFg
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.detail
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.tuiDim
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: commandMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component DetailRow: RowLayout {
        property string keyText: ""
        property string valueText: ""
        property color valueColor: root.tuiFg

        Layout.fillWidth: true
        spacing: 10

        StyledText {
            Layout.preferredWidth: 72
            text: keyText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Bold
            color: root.tuiDim
        }

        StyledText {
            Layout.fillWidth: true
            text: valueText
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Bold
            color: valueColor
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }
}
