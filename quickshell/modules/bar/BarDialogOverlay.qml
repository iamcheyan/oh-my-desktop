import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.controlCenter.bluetoothDevices
import qs.modules.controlCenter.wifiNetworks
import qs.modules.controlCenter.nightLight
import qs.modules.controlCenter.volumeMixer
import qs.modules.settings
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

    IpcHandler {
        target: "barDialog"

        function open(type: string): void {
            root.openDialog(type);
        }

        function close(): void {
            GlobalStates.barDialogOpen = false;
            GlobalStates.barDialogType = "";
        }

        function toggle(type: string): void {
            if (GlobalStates.barDialogOpen && GlobalStates.barDialogType === type) {
                close();
            } else {
                open(type);
            }
        }
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
            }

            Item {
                id: dialogContainer
                anchors.fill: parent

                SettingsCenter {
                    id: settingsCenter
                    anchors.fill: parent
                    requestedPage: GlobalStates.barDialogType
                    visible: true
                    show: true
                    onDismiss: overlayWindow.close()
                }
            }
        }
    }

}
