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

    readonly property string tuiLauncher: `${FileUtils.trimFileProtocol(Directories.config)}/omd/scripts/launch-tui-tool`

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

                // BlueTUI (TUI)
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached([root.tuiLauncher, "bluetooth"]);
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
                            name: "devices/bluetooth-symbolic"
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("BlueTUI (TUI)")
                        }
                    }
                }

                // Blueman Manager (GUI)
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["blueman-manager"]);
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
                            text: Translation.tr("Blueman Manager")
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

                // Toggle Bluetooth
                RippleButton {
                    buttonRadius: popupBackground.radius - popupBackground.padding
                    horizontalPadding: 12
                    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                    implicitHeight: 36
                    Layout.fillWidth: true

                    releaseAction: () => {
                        Quickshell.execDetached(["bash", "-c", "bluetoothctl power " + (BluetoothStatus.enabled ? "off" : "on")]);
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
                            name: BluetoothStatus.enabled ? "actions/system-shutdown-symbolic" : "actions/system-run-symbolic"
                            color: BluetoothStatus.enabled ? Appearance.tiling.error : Appearance.tiling.success
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: BluetoothStatus.enabled ? Translation.tr("Disable Bluetooth") : Translation.tr("Enable Bluetooth")
                            color: BluetoothStatus.enabled ? Appearance.tiling.error : Appearance.tiling.success
                        }
                    }
                }
            }
        }
    }
}
