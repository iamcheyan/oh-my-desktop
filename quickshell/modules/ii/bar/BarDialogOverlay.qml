import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.bluetoothDevices
import qs.modules.ii.sidebarRight.wifiNetworks
import qs.modules.ii.sidebarRight.nightLight
import qs.modules.ii.sidebarRight.volumeMixer
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Hyprland

Scope {
    id: root

    function openDialog(type: string) {
        GlobalStates.barDialogType = type;
        GlobalStates.barDialogOpen = true;
    }

    Loader {
        id: overlayLoader
        active: GlobalStates.barDialogOpen

        sourceComponent: PanelWindow {
            id: overlayWindow
            visible: overlayLoader.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:bardialog"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            function close() {
                GlobalStates.barDialogOpen = false;
                GlobalStates.barDialogType = "";
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(overlayWindow);
                if (GlobalStates.barDialogType === "bluetooth") {
                    Bluetooth.defaultAdapter.enabled = true;
                    Bluetooth.defaultAdapter.discovering = true;
                } else if (GlobalStates.barDialogType === "wifi") {
                    Network.enableWifi();
                    Network.rescanWifi();
                }
            }
            Component.onDestruction: {
                if (GlobalStates.barDialogType === "bluetooth") {
                    Bluetooth.defaultAdapter.discovering = false;
                }
                GlobalFocusGrab.removeDismissable(overlayWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    overlayWindow.close();
                }
            }

            Item {
                id: dialogContainer
                anchors.fill: parent

                BluetoothDialog {
                    id: bluetoothDialog
                    anchors.fill: parent
                    visible: GlobalStates.barDialogType === "bluetooth"
                    show: visible
                    onDismiss: overlayWindow.close()
                }

                WifiDialog {
                    id: wifiDialog
                    anchors.fill: parent
                    visible: GlobalStates.barDialogType === "wifi"
                    show: visible
                    onDismiss: overlayWindow.close()
                }

                NightLightDialog {
                    id: nightLightDialog
                    anchors.fill: parent
                    visible: GlobalStates.barDialogType === "nightlight"
                    show: visible
                    onDismiss: overlayWindow.close()
                }

                ClipboardDialog {
                    id: clipboardDialog
                    anchors.fill: parent
                    visible: GlobalStates.barDialogType === "clipboard"
                    show: visible
                    onDismiss: overlayWindow.close()
                }

                VolumeDialog {
                    id: volumeDialog
                    anchors.fill: parent
                    visible: GlobalStates.barDialogType === "audio"
                    show: visible
                    onDismiss: overlayWindow.close()
                }

                BatteryDialog {
                    id: batteryDialog
                    anchors.fill: parent
                    visible: GlobalStates.barDialogType === "battery"
                    show: visible
                    onDismiss: overlayWindow.close()
                }
            }
        }
    }

    IpcHandler {
        target: "barDialog"

        function clipboard() {
            root.openDialog("clipboard");
        }
    }

    GlobalShortcut {
        name: "barClipboardToggle"
        description: "Toggle clipboard history from the bar"
        onPressed: {
            if (GlobalStates.barDialogOpen && GlobalStates.barDialogType === "clipboard") {
                GlobalStates.barDialogOpen = false;
                GlobalStates.barDialogType = "";
            } else {
                root.openDialog("clipboard");
            }
        }
    }
}
