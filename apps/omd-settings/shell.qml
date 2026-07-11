//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import "services"

import qs.modules.settings
import qs.modules.settings.widgets
import qs.modules.settings.pages

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Hyprland

ShellRoot {
    id: root

    readonly property string initialPage: EnvVar.string("OMD_SETTINGS_PAGE", "overview")

    Component.onCompleted: {
        if (EnvVar.string("OMD_SETTINGS_ON_DEMAND", "0") === "1") {
            root.showSettings(root.initialPage);
        }
    }

    function showSettings(page: string) {
        settingsLoader.active = true;
        settingsCenter.requestedPage = page;
        settingsCenter.show = true;
    }

    function closeSettings() {
        settingsCenter.show = false;
        Qt.quit();
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            root.showSettings(page);
        }

        function close(): void {
            root.closeSettings();
        }

        function toggle(page: string): void {
            if (settingsCenter.show) {
                root.closeSettings();
            } else {
                root.showSettings(page);
            }
        }
    }

    Loader {
        id: settingsLoader
        active: false

        sourceComponent: PanelWindow {
            id: overlayWindow
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:bardialog"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            function close() {
                root.closeSettings();
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    close();
                    event.accepted = true;
                }
            }

            SettingsCenter {
                id: settingsCenter
                anchors.fill: parent
                requestedPage: root.initialPage
                visible: true
                show: true
                onDismiss: overlayWindow.close()
            }
        }
    }
}
