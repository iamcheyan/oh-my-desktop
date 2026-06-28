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

                // 1. 语音识别
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        VoiceInput.toggle();
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
                            name: "status/microphone-sensitivity-high-symbolic"
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("语音识别")
                        }
                    }
                }

                // 2. 测试
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["omarchy-launch-tui", "/home/tetsuya/development/OMD/scripts/voice-test-tui"]);
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
                            color: TuiStyle.info
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("测试语音输入")
                        }
                    }
                }

                // 3. 按键捕获
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["omarchy-launch-tui", "/home/tetsuya/development/OMD/scripts/key-test"]);
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
                            name: "devices/input-keyboard-symbolic"
                            color: TuiStyle.warning
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("按键捕获")
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

                // 4. 状态测试
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["omarchy-launch-tui", "/home/tetsuya/development/OMD/scripts/voice-diagnose"]);
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
                            color: TuiStyle.accent
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("状态测试")
                            color: TuiStyle.accent
                        }
                    }
                }
            }
        }
    }
}
