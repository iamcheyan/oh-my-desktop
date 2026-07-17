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
    readonly property string initialPosition: (Quickshell.env("OMD_CLIPBOARD_POSITION") ?? "") === "bar" ? "bar" : "cursor"
    readonly property real initialBarHeight: Number(Quickshell.env("OMD_CLIPBOARD_BAR_HEIGHT") ?? "") || 32
    property real cursorX: 0
    property real cursorY: 0
    property real monitorX: 0
    property real monitorY: 0
    property bool positionReady: false
    property var cachedMonitors: []

    Component.onCompleted: {
        monitorProc.running = true;
        if (onDemand) {
            GlobalStates.clipboardOpen = true;
            dialog.positionMode = root.initialPosition;
            dialog.barHeight = root.initialBarHeight;
        }
    }

    function updateCursorPosition() {
        positionReady = false;
        cursorPositionProc.running = false;
        cursorPositionProc.running = true;
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
                    root.resolveMonitor();
                } catch (error) {
                    console.warn("[Clipboard] Could not read cursor position:", error);
                    root.positionReady = true;
                }
            }
        }
    }

    function resolveMonitor() {
        if (root.cachedMonitors.length === 0) {
            monitorProc.running = false;
            monitorProc.running = true;
            return;
        }
        root.applyMonitor(root.cachedMonitors);
    }

    function applyMonitor(monitors) {
        try {
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
        Qt.callLater(() => dialog.place());
    }

    Process {
        id: monitorProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.cachedMonitors = JSON.parse(text);
                } catch (error) {
                    console.warn("[Clipboard] Could not parse monitors:", error);
                }
                root.applyMonitor(root.cachedMonitors);
            }
        }
    }

    // Close-after-warmup: hide on close, quit only if not reopened
    // within the warmup window. This avoids the Quickshell cold-start
    // cost when the clipboard is opened/closed repeatedly.
    readonly property int warmupMs: 25000

    Connections {
        target: GlobalStates
        function onClipboardOpenChanged() {
            if (GlobalStates.clipboardOpen) {
                warmupTimer.stop();
                root.updateCursorPosition();
            } else if (onDemand) {
                warmupTimer.restart();
            }
        }
    }

    Timer {
        id: warmupTimer
        interval: root.warmupMs
        repeat: false
        onTriggered: {
            if (onDemand && !GlobalStates.clipboardOpen)
                Qt.quit();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            GlobalStates.clipboardOpen = !GlobalStates.clipboardOpen;
            dialog.positionMode = "cursor";
        }
        function open() {
            GlobalStates.clipboardOpen = true;
            dialog.positionMode = "cursor";
        }
        function toggleAtBar(barHeight: real) {
            if (GlobalStates.clipboardOpen && dialog.positionMode === "bar") {
                GlobalStates.clipboardOpen = false;
            } else {
                GlobalStates.clipboardOpen = true;
                dialog.positionMode = "bar";
                if (barHeight > 0)
                    dialog.barHeight = barHeight;
            }
        }
        function openAtBar(barHeight: real) {
            GlobalStates.clipboardOpen = true;
            dialog.positionMode = "bar";
            if (barHeight > 0)
                dialog.barHeight = barHeight;
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

        Keys.onEscapePressed: {
            clipboardWindow.close();
        }

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
