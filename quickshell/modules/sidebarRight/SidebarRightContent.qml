import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notifications
import QtQuick
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
                    anchors.rightMargin: 10
                    spacing: 12

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
                            text: `${Notifications.list.length} queued  unread=${Notifications.unread}  mode=${Notifications.silent ? "silent" : "normal"}`
                            font.family: Appearance.font.family.monospace
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
                                Quickshell.execDetached(["hyprctl", "reload"])
                                Quickshell.reload(true);
                            }
                        }

                        HeaderButton {
                            iconName: "settings"
                            accent: root.tuiBlue
                            onClicked: {
                                GlobalStates.sidebarRightOpen = false;
                                Quickshell.execDetached(["qs", "-p", root.settingsQmlPath]);
                            }
                        }

                        HeaderButton {
                            iconName: "power_settings_new"
                            accent: root.tuiRed
                            onClicked: {
                                GlobalStates.sessionOpen = true;
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.tuiPanel
                border.width: 1
                border.color: root.tuiLine

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    color: root.tuiGreen
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
                        text: "NOTIFICATIONS"
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: root.tuiGreen
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.tuiLine
                    }

                    StyledText {
                        text: Notifications.list.length === 0 ? "empty" : `${Notifications.list.length} entries`
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.tuiDim
                        horizontalAlignment: Text.AlignRight
                    }
                }

                TuiNotificationList {
                    anchors.fill: parent
                    anchors.topMargin: 42
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    anchors.bottomMargin: 12
                }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: button

        property string iconName: ""
        property color accent: root.tuiYellow
        signal clicked()

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        color: buttonMouse.pressed ? root.tuiPanelAlt : buttonMouse.containsMouse ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.14) : "transparent"
        border.width: 1
        border.color: buttonMouse.containsMouse ? button.accent : root.tuiLine

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.iconName
            iconSize: Appearance.font.pixelSize.huge
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
