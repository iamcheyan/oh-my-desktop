import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.notifications
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property string settingsQmlPath: Quickshell.shellPath("settings.qml")

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

    function formatBatteryTime(seconds) {
        if (!Battery.available || seconds <= 0)
            return "--";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    function batteryStateLabel() {
        if (!Battery.available)
            return "unavailable";
        if (Battery.isCharging)
            return "charging";
        if (Battery.isPluggedIn)
            return "plugged";
        return "battery";
    }

    function profileTone(profile) {
        if (profile === "performance")
            return root.tuiRed;
        if (profile === "balanced")
            return root.tuiYellow;
        if (profile === "power-saver")
            return root.tuiGreen;
        return root.tuiDim;
    }

    implicitHeight: controlCenterBackground.implicitHeight
    implicitWidth: controlCenterBackground.implicitWidth

    Rectangle {
        id: controlCenterBackground
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: contentColumn.implicitHeight + 32
        implicitWidth: parent.width
        color: root.tuiBg
        border.width: 1
        border.color: root.tuiLine
        radius: 0

        ColumnLayout {
            id: contentColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
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
                            text: "OMD CONTROLCTL"
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: root.tuiBlue
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: `battery=${Battery.available ? Math.round(Battery.percentage * 100) + "%" : "--"}  profile=${PowerProfiles.currentProfile}  sleep=${Idle.inhibit ? "blocked" : "allowed"}  notifications=${Notifications.list.length}`
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
                                GlobalStates.controlCenterOpen = false;
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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                spacing: 12

                ControlPanel {
                    title: "BATTERY"
                    subtitle: root.batteryStateLabel()
                    accent: Battery.isLowAndNotCharging ? root.tuiRed : Battery.isCharging ? root.tuiYellow : root.tuiGreen
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 14

                        ColumnLayout {
                            Layout.preferredWidth: 150
                            Layout.fillHeight: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                MaterialSymbol {
                                    text: Battery.isCharging ? "bolt" : "battery_android_full"
                                    iconSize: 38
                                    color: Battery.isLowAndNotCharging ? root.tuiRed : root.tuiGreen
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--"
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.huge
                                    font.weight: Font.Bold
                                    color: Battery.isLowAndNotCharging ? root.tuiRed : root.tuiFg
                                }
                            }

                            TuiMeterBar {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                value: Battery.available ? Battery.percentage * 100 : 0
                                accent: Battery.isLowAndNotCharging ? root.tuiRed : Battery.isCharging ? root.tuiYellow : root.tuiGreen
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            TuiDetailRow {
                                keyText: "STATE"
                                valueText: root.batteryStateLabel()
                                valueColor: Battery.isCharging ? root.tuiYellow : root.tuiGreen
                            }

                            TuiDetailRow {
                                keyText: Battery.isCharging ? "TO FULL" : "TO EMPTY"
                                valueText: root.formatBatteryTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty)
                                valueColor: root.tuiFg
                            }

                            TuiDetailRow {
                                keyText: "POWER"
                                valueText: Battery.available && Battery.energyRate > 0.01 ? `${Battery.energyRate.toFixed(1)}W` : "--"
                                valueColor: root.tuiBlue
                            }

                            TuiDetailRow {
                                keyText: "HEALTH"
                                valueText: Battery.available && Battery.health > 0 ? `${Battery.health.toFixed(1)}%` : "--"
                                valueColor: Battery.health > 0 && Battery.health < 80 ? root.tuiYellow : root.tuiGreen
                            }
                        }
                    }
                }

                ControlPanel {
                    title: "POWER PROFILE"
                    subtitle: PowerProfiles.available ? PowerProfiles.currentProfile : "unavailable"
                    accent: root.profileTone(PowerProfiles.currentProfile)
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ProfileButton {
                                profile: "power-saver"
                                label: "SAVE"
                                accent: root.tuiGreen
                            }

                            ProfileButton {
                                profile: "balanced"
                                label: "BAL"
                                accent: root.tuiYellow
                            }

                            ProfileButton {
                                profile: "performance"
                                label: "PERF"
                                accent: root.tuiRed
                            }
                        }

                        TuiDetailRow {
                            keyText: "CURRENT"
                            valueText: PowerProfiles.available ? PowerProfiles.currentProfile : "missing powerprofilesctl"
                            valueColor: root.profileTone(PowerProfiles.currentProfile)
                        }

                        TuiDetailRow {
                            keyText: "AVAILABLE"
                            valueText: PowerProfiles.available ? PowerProfiles.profiles.join(" / ") : "--"
                            valueColor: root.tuiDim
                        }

                        TuiDetailRow {
                            keyText: "SLEEP"
                            valueText: Idle.inhibit ? "blocked" : "allowed"
                            valueColor: Idle.inhibit ? root.tuiYellow : root.tuiGreen
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TuiActionButton {
                                label: "cycle"
                                accent: root.tuiBlue
                                enabled: PowerProfiles.available
                                onClicked: PowerProfiles.cycleProfile()
                            }

                            TuiActionButton {
                                label: "refresh"
                                accent: root.tuiPurple
                                onClicked: PowerProfiles.refresh()
                            }

                            TuiActionButton {
                                label: Idle.inhibit ? "allow sleep" : "keep awake"
                                accent: Idle.inhibit ? root.tuiGreen : root.tuiYellow
                                onClicked: Idle.toggleInhibit()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(notificationList.implicitHeight + 56, 500)
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
                    id: notificationList
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        topMargin: 42
                        leftMargin: 14
                        rightMargin: 12
                        bottomMargin: 12
                    }
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

    component ControlPanel: Item {
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
            height: 30
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
                elide: Text.ElideRight
            }
        }

        Item {
            id: panelContent
            anchors.fill: parent
            anchors.topMargin: 40
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            anchors.bottomMargin: 12
        }
    }

    component ProfileButton: Rectangle {
        id: button

        required property string profile
        property string label: profile
        property color accent: root.tuiGreen
        readonly property bool active: PowerProfiles.currentProfile === profile
        readonly property bool available: PowerProfiles.available && PowerProfiles.profiles.indexOf(profile) >= 0

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        opacity: available ? 1 : 0.4
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
            : profileMouse.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.10)
            : "transparent"
        border.width: 1
        border.color: active || profileMouse.containsMouse ? accent : root.tuiLine

        StyledText {
            anchors.centerIn: parent
            text: button.label
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Bold
            color: button.active ? button.accent : root.tuiFg
        }

        MouseArea {
            id: profileMouse
            anchors.fill: parent
            enabled: button.available
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerProfiles.setProfile(button.profile)
        }
    }

}
