//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/common"
import "services"

import qs.modules.bar
import qs.modules.common.widgets

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    ReloadPopup {}

    IpcHandler {
        target: "clipboard"

        function toggle() {
            GlobalStates.clipboardOpen = !GlobalStates.clipboardOpen;
        }
        function open() {
            GlobalStates.clipboardOpen = true;
        }
        function close() {
            GlobalStates.clipboardOpen = false;
        }
    }

    Loader {
        id: clipboardLoader
        active: GlobalStates.clipboardOpen

        sourceComponent: PanelWindow {
            id: clipboardWindow
            visible: clipboardLoader.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:clipboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            function close() {
                GlobalStates.clipboardOpen = false;
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(clipboardWindow);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(clipboardWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    clipboardWindow.close();
                }
            }

            ClipboardDialog {
                id: dialog
                anchors.centerIn: parent
                visible: true
                show: true
                onDismiss: clipboardWindow.close()
            }
        }
    }

    LazyLoader {
        active: Config.ready
        component: Item {}
    }
}