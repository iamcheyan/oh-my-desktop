//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import "modules/clipboard"
import "services"
import "modules/clipboard/widgets"

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    readonly property bool onDemand: (Quickshell.env("OMD_CLIPBOARD_ON_DEMAND") ?? "") === "1"

    Component.onCompleted: {
        if (onDemand) {
            GlobalStates.clipboardOpen = true;
        }
    }

    Connections {
        target: GlobalStates
        function onClipboardOpenChanged() {
            if (onDemand && !GlobalStates.clipboardOpen) {
                Qt.quit();
            }
        }
    }

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

    PanelWindow {
        id: clipboardWindow
        visible: GlobalStates.clipboardOpen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        implicitWidth: screen?.width ?? 1280
        implicitHeight: screen?.height ?? 720
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.clipboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        function close() {
            GlobalStates.clipboardOpen = false;
        }

        Timer {
            id: dismissGuard
            interval: 150
            repeat: false
            onTriggered: {
                // Since we decoupled from the global GlobalFocusGrab,
                // we can dismiss directly when clicking outside or losing focus.
            }
        }

        // Handle Escape key to close the window
        Keys.onEscapePressed: {
            clipboardWindow.close();
        }

        // Close on clicking the empty outer space
        MouseArea {
            anchors.fill: parent
            onClicked: {
                clipboardWindow.close();
            }
        }

        ClipboardDialog {
            id: dialog
            anchors.centerIn: parent
            visible: GlobalStates.clipboardOpen
            show: GlobalStates.clipboardOpen
            onDismiss: clipboardWindow.close()
        }
    }
}
