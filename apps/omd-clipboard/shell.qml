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
    property real cursorX: 0
    property real cursorY: 0
    property real monitorX: 0
    property real monitorY: 0
    property bool positionReady: false

    function updateCursorPosition() {
        positionReady = false;
        cursorPositionProc.running = false;
        cursorPositionProc.running = true;
    }

    Component.onCompleted: {
        if (onDemand) {
            GlobalStates.clipboardOpen = true;
        }
    }

    Process {
        id: cursorPositionProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const position = JSON.parse(text);
                    root.cursorX = Number(position.x) || 0;
                    root.cursorY = Number(position.y) || 0;
                    monitorProc.running = false;
                    monitorProc.running = true;
                } catch (error) {
                    console.warn("[Clipboard] Could not read cursor position:", error);
                    root.positionReady = true;
                }
            }
        }
    }

    Process {
        id: monitorProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const monitors = JSON.parse(text);
                    const monitor = monitors.find(candidate => {
                        const rotated = candidate.transform === 1 || candidate.transform === 3
                            || candidate.transform === 5 || candidate.transform === 7;
                        const scale = Number(candidate.scale) || 1;
                        const logicalWidth = (rotated ? candidate.height : candidate.width) / scale;
                        const logicalHeight = (rotated ? candidate.width : candidate.height) / scale;
                        return root.cursorX >= candidate.x
                            && root.cursorX < candidate.x + logicalWidth
                            && root.cursorY >= candidate.y
                            && root.cursorY < candidate.y + logicalHeight;
                    });
                    if (monitor) {
                        root.monitorX = Number(monitor.x) || 0;
                        root.monitorY = Number(monitor.y) || 0;
                        const screens = Quickshell.screens;
                        for (let index = 0; index < screens.length; index++) {
                            if (screens[index].name === monitor.name) {
                                clipboardWindow.screen = screens[index];
                                break;
                            }
                        }
                    }
                } catch (error) {
                    console.warn("[Clipboard] Could not resolve cursor monitor:", error);
                }
                root.positionReady = true;
                Qt.callLater(() => dialog.placeAtCursor());
            }
        }
    }

    Connections {
        target: GlobalStates
        function onClipboardOpenChanged() {
            if (GlobalStates.clipboardOpen)
                root.updateCursorPosition();
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
        visible: GlobalStates.clipboardOpen && root.positionReady

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

        onVisibleChanged: {
            if (visible)
                root.updateCursorPosition();
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
            anchors.fill: parent
            visible: GlobalStates.clipboardOpen
            show: GlobalStates.clipboardOpen
            cursorGlobalX: root.cursorX
            cursorGlobalY: root.cursorY
            screenGlobalX: root.monitorX
            screenGlobalY: root.monitorY
            screen: clipboardWindow.screen
            onDismiss: clipboardWindow.close()
        }
    }
}
