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

    readonly property string initialPage: Quickshell.env("OMD_SETTINGS_PAGE") ?? "overview"
    readonly property bool onDemand: (Quickshell.env("OMD_SETTINGS_ON_DEMAND") ?? "0") === "1"

    Component.onCompleted: {
        if (root.onDemand) {
            root.showSettings(root.initialPage);
        }
    }

    function showSettings(page: string) {
        settingsWindow.openPage(page);
    }

    function closeSettings() {
        settingsWindow.hidePage();
        if (root.onDemand) {
            Qt.callLater(Qt.quit);
        }
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
            if (settingsWindow.isOpen) {
                root.closeSettings();
            } else {
                root.showSettings(page);
            }
        }
    }

    PanelWindow {
        id: settingsWindow
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: settingsDialog.show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        visible: true

        property bool isOpen: settingsDialog.show

        function close() {
            root.closeSettings();
        }

        function openPage(page: string) {
            settingsDialog.requestedPage = page || "overview";
            settingsDialog.show = true;
        }

        function hidePage() {
            settingsDialog.show = false;
        }

        SettingsDialog {
            id: settingsDialog
            anchors.fill: parent
            requestedPage: root.initialPage
            visible: settingsDialog.show
            show: false
            onDismiss: settingsWindow.close()
        }
    }
}
