pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    readonly property string action: GlobalStates.sessionConfirmAction
    readonly property string label: GlobalStates.sessionConfirmLabel || action
    readonly property bool canSaveSession: action === "logout" || action === "reboot" || action === "poweroff"

    function actionTitle() {
        if (action === "logout") return "Log out of this session?";
        if (action === "reboot") return "Restart this computer?";
        if (action === "poweroff") return "Shut down this computer?";
        return `Confirm ${label}`;
    }

    function actionBody() {
        if (action === "logout")
            return "Open applications will be closed and the current Hyprland session will end.";
        if (action === "reboot")
            return "The system will restart after running the selected session action.";
        if (action === "poweroff")
            return "The system will power off after running the selected session action.";
        return "This system action will run immediately after confirmation.";
    }

    function confirmText() {
        if (action === "logout") return "LOG OUT";
        if (action === "reboot") return "RESTART";
        if (action === "poweroff") return "SHUT DOWN";
        return "CONFIRM";
    }

    function runAction(saveCurrentSession) {
        const currentAction = action;
        GlobalStates.closeSessionConfirm();
        if (currentAction === "logout") {
            Session.logout(saveCurrentSession);
        } else if (currentAction === "reboot") {
            Session.reboot(saveCurrentSession);
        } else if (currentAction === "poweroff") {
            Session.poweroff(saveCurrentSession);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow
            required property var modelData
            readonly property bool focusedScreen: Hyprland.focusedMonitor?.name
                ? modelData.name === Hyprland.focusedMonitor.name
                : modelData === Quickshell.screens[0]

            screen: modelData
            visible: GlobalStates.sessionConfirmOpen && !GlobalStates.screenLocked
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "quickshell:session-confirm"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.closeSessionConfirm();
                    event.accepted = true;
                }
            }

            onVisibleChanged: {
                if (visible && overlayWindow.focusedScreen)
                    Qt.callLater(() => { keyHandler.forceActiveFocus(); });
            }
            Component.onCompleted: {
                if (overlayWindow.focusedScreen)
                    Qt.callLater(() => { keyHandler.forceActiveFocus(); });
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.58)
            }

            Item {
                id: keyHandler
                anchors.fill: parent
                focus: overlayWindow.focusedScreen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.closeSessionConfirm();
                        event.accepted = true;
                    }
                }

                Rectangle {
                    id: dialog
                    width: Math.min(parent.width - 96, 560)
                    implicitHeight: dialogContent.implicitHeight + 48
                    anchors.centerIn: parent
                    radius: TuiStyle.shellRadius
                    color: TuiStyle.bg
                    border.width: TuiStyle.borderWidth
                    border.color: TuiStyle.shellBorder
                    visible: overlayWindow.focusedScreen
                    clip: true

                    StyledRectangularShadow {
                        target: dialog
                        opacity: 0.72
                    }

                    ColumnLayout {
                        id: dialogContent
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 18

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 23
                                color: TuiStyle.accentWash(TuiStyle.danger)
                                border.width: TuiStyle.borderWidth
                                border.color: TuiStyle.shellBorder

                                NerdIcon {
                                    anchors.centerIn: parent
                                    text: root.action === "logout" ? NerdIconMap.logout
                                        : root.action === "reboot" ? NerdIconMap.restart
                                        : NerdIconMap.powerSettingsNew
                                    iconSize: 22
                                    color: TuiStyle.fg
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.actionTitle()
                                    color: TuiStyle.fg
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.actionBody()
                                    color: TuiStyle.muted
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: TuiStyle.line
                            opacity: TuiStyle.dividerOpacity
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: saveSessionRow.implicitHeight
                            visible: root.canSaveSession

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: saveSession.checked = !saveSession.checked
                            }

                            RowLayout {
                                id: saveSessionRow
                                anchors.fill: parent
                                spacing: 12

                                Rectangle {
                                    id: saveSession
                                    property bool checked: false
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: 5
                                    color: checked ? TuiStyle.accentWash(TuiStyle.accent) : TuiStyle.surfaceSubtle
                                    border.width: TuiStyle.borderWidth
                                    border.color: checked ? TuiStyle.accent : TuiStyle.line

                                    NerdIcon {
                                        anchors.centerIn: parent
                                        text: NerdIconMap.check
                                        iconSize: 14
                                        color: TuiStyle.fg
                                        visible: saveSession.checked
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: "保存本次桌面会话，下次启动后自动恢复"
                                        color: TuiStyle.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: "会保存当前工作区、窗口位置和可恢复的终端会话。下次进入桌面时会自动加载这些窗口。"
                                        color: TuiStyle.muted
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 12

                            TuiActionButton {
                                Layout.fillWidth: true
                                label: "CANCEL"
                                accent: TuiStyle.dim
                                onClicked: GlobalStates.closeSessionConfirm()
                            }

                            TuiActionButton {
                                Layout.fillWidth: true
                                label: root.confirmText()
                                accent: TuiStyle.danger
                                onClicked: root.runAction(saveSession.checked)
                            }
                        }
                    }
                }
            }
        }
    }
}
