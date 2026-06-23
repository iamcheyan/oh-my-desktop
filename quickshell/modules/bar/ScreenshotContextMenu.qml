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

    // Click outside to dismiss
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

            color: Appearance.tiling.bg
            radius: Appearance.tiling.dialogRadius
            border.width: Appearance.tiling.borderWidth
            border.color: Appearance.tiling.border
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

                // Region Screenshot
                RippleButton {
                    id: regionScreenshotButton
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: regionScreenshotButton.horizontalPadding
                            rightMargin: regionScreenshotButton.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "apps/accessories-screenshot-symbolic"
                            color: "#ffffff"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("截取部分")
                        }
                    }
                }

                // Full Screen Screenshot
                RippleButton {
                    id: fullscreenScreenshotButton
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["bash", "-c", "grim -o $(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name') - | wl-copy && notify-send -i camera-photo Screenshot \"Full screen copied to clipboard\""]);
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: fullscreenScreenshotButton.horizontalPadding
                            rightMargin: fullscreenScreenshotButton.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "apps/accessories-screenshot-symbolic"
                            color: "#ffffff"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("截取全屏")
                        }
                    }
                }

                // Delayed Current Monitor Screenshot
                RippleButton {
                    id: delayedMonitorScreenshotButton
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["bash", "-c", "monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); notify-send -i camera-photo Screenshot \"Capturing current monitor in 3 seconds\"; sleep 3; grim -o \"$monitor\" - | wl-copy && notify-send -i camera-photo Screenshot \"Current monitor copied to clipboard\""]);
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: delayedMonitorScreenshotButton.horizontalPadding
                            rightMargin: delayedMonitorScreenshotButton.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "apps/accessories-screenshot-symbolic"
                            color: "#ffffff"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("延迟 3 秒截取当前显示器")
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.tiling.border
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // Color Picker
                RippleButton {
                    id: colorPickerButton
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["hyprpicker", "-a"]);
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: colorPickerButton.horizontalPadding
                            rightMargin: colorPickerButton.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "actions/pencil-symbolic"
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("取色")
                        }
                    }
                }

                // Screen Recording
                RippleButton {
                    id: screenRecordButton
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached([Directories.recordScriptPath]);
                        root.close();
                    }

                    contentItem: RowLayout {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: screenRecordButton.horizontalPadding
                            rightMargin: screenRecordButton.horizontalPadding
                        }
                        spacing: 8

                        CosmicIcon {
                            iconSize: 16
                            name: "devices/camera-video-symbolic"
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("录屏")
                        }
                    }
                }
            }
        }
    }
}
