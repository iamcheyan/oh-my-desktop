pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root
    property real popupBackgroundMargin: 0
    signal menuClosed

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
    implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

    function open() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
    }

    Component.onDestruction: {
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.close()

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            readonly property real padding: 4
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.padding
            }

            color: TuiStyle.bg
            radius: TuiStyle.radius
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.line
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: columnLayout.implicitWidth + popupBackground.padding * 2
            implicitHeight: columnLayout.implicitHeight + popupBackground.padding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            ColumnLayout {
                id: columnLayout
                anchors {
                    fill: parent
                    margins: popupBackground.padding
                }
                spacing: 0

                // 语音设置
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        VoiceInput.openSettings();
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: parent.parent.horizontalPadding
                            rightMargin: parent.parent.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "categories/preferences-system-symbolic"
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("语音设置")
                        }
                    }
                }

                // 测试录音
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true
                    enabled: VoiceInput.state === "idle" || VoiceInput.state === "setup"
                    opacity: enabled ? 1 : 0.4

                    releaseAction: () => {
                        if (VoiceInput.state === "setup") {
                            VoiceInput.setup();
                        } else {
                            VoiceInput.testRecording();
                        }
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: parent.parent.horizontalPadding
                            rightMargin: parent.parent.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "actions/media-record-symbolic"
                            color: enabled ? TuiStyle.info : TuiStyle.dim
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: VoiceInput.state === "setup" ? Translation.tr("安装并测试") : Translation.tr("测试录音 (3秒)")
                            color: enabled ? Appearance.colors.colOnLayer0 : TuiStyle.dim
                        }
                    }
                }

                // 清除历史
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true
                    enabled: VoiceInput.history.length > 0
                    opacity: enabled ? 1 : 0.4

                    releaseAction: () => {
                        VoiceInput.clearHistory();
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: parent.parent.horizontalPadding
                            rightMargin: parent.parent.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "actions/edit-clear-symbolic"
                            color: enabled ? TuiStyle.danger : TuiStyle.dim
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("清除历史") + (VoiceInput.history.length > 0 ? ` (${VoiceInput.history.length})` : "")
                            color: enabled ? TuiStyle.danger : TuiStyle.dim
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: TuiStyle.line
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // 重新检查状态
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        VoiceInput.checkState();
                        VoiceInput.refreshModelInfo();
                        VoiceInput.refreshDaemonStatus();
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: parent.parent.horizontalPadding
                            rightMargin: parent.parent.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "actions/view-refresh-symbolic"
                            color: TuiStyle.accent
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("重新检查状态")
                            color: TuiStyle.accent
                        }
                    }
                }
            }
        }
    }
}
