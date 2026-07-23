pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import qs.core.runtime
import qs.services as Services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs.modules.bar

Scope {
    id: root

    readonly property string omdSessionCommand: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`
    property string sessionSaveOutput: ""
    readonly property string activeType: GlobalStates.barPopupType || ""
    readonly property bool open: activeType.length > 0 && !GlobalStates.screenLocked
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null
    // Prefer the bar/screen that opened the popup (multi-monitor), else focused.
    readonly property var popupScreen: {
        const name = GlobalStates.barPopupAnchorScreen || "";
        if (name.length)
            return Quickshell.screens.find(s => s.name === name) ?? focusedScreen;
        return focusedScreen;
    }

    onActiveTypeChanged: popupFlick.contentY = 0

    function close() {
        GlobalStates.barPopupEphemeral = false;
        GlobalStates.barPopupType = "";
        GlobalStates.barPopupAnchorScreen = "";
    }

    function openDialog(dialogType) {
        root.close();
        ActionManager.invoke("settings.open", {section: dialogType});
    }

    function saveSessionSnapshot() {
        if (sessionSaveProcess.running)
            return;
        root.sessionSaveOutput = "";
        sessionSaveProcess.running = true;
        root.close();
    }

    function sessionSaveNotification(data) {
        const windows = data.count ?? 0;
        const workspaces = data.workspaceCount ?? 0;
        const monitors = data.monitorCount ?? 0;
        const terminalSessions = data.terminalSessionCount ?? 0;
        const summary = `Saved ${windows} window${windows === 1 ? "" : "s"} across ${workspaces} workspace${workspaces === 1 ? "" : "s"} on ${monitors} display${monitors === 1 ? "" : "s"}.`;
        let details = "Includes app launch commands, workspace/display placement, window geometry and state, and focus.";
        if (terminalSessions > 0)
            details += ` Captured ${terminalSessions} restorable terminal session${terminalSessions === 1 ? "" : "s"}.`;
        Quickshell.execDetached([
            "notify-send", "-a", "OMD Session", "-i", "document-save",
            "Session snapshot saved", `${summary}\n${details}`
        ]);
    }

    Process {
        id: sessionSaveProcess
        command: [root.omdSessionCommand, "save"]

        stdout: StdioCollector {
            id: sessionSaveStdout
            onStreamFinished: root.sessionSaveOutput = sessionSaveStdout.text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([
                    "notify-send", "-u", "critical", "-a", "OMD Session",
                    "Session snapshot failed", "The current workspace state could not be saved."
                ]);
                return;
            }
            try {
                const data = JSON.parse(root.sessionSaveOutput);
                if (data.saved) {
                    root.sessionSaveNotification(data);
                } else if (data.skipped && data.reason === "empty") {
                    Quickshell.execDetached([
                        "notify-send", "-a", "OMD Session", "Session snapshot unchanged",
                        "No windows are open, so the last usable snapshot was kept."
                    ]);
                }
            } catch (error) {
                Quickshell.execDetached([
                    "notify-send", "-u", "critical", "-a", "OMD Session",
                    "Session snapshot failed", "The save command returned an unreadable result."
                ]);
            }
        }
    }

    IpcHandler {
        target: "barPopup"

        function toggle(type: string): void {
            GlobalStates.barPopupType = GlobalStates.barPopupType === type ? "" : type;
        }

        function close(): void {
            GlobalStates.barPopupType = "";
        }

        function open(type: string): void {
            GlobalStates.barPopupType = type;
        }
    }

    PanelWindow {
        id: popupWindow
        screen: root.popupScreen
        visible: root.open && root.popupScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:barstatus"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.activeType === "inputMethod"
            ? WlrKeyboardFocus.None
            : WlrKeyboardFocus.OnDemand

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        readonly property bool barOnBottom: Config.options.bar.bottom
        readonly property int panelWidth: Math.min(440, (screen?.width ?? 1920) - 32)

        anchors {
            top: !barOnBottom
            bottom: barOnBottom
            right: true
        }

        margins {
            top: barOnBottom ? 0 : Appearance.sizes.barHeight + 4
            bottom: barOnBottom ? Appearance.sizes.barHeight + 4 : 0
            right: 4
        }

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        Behavior on implicitHeight { }  // Disable height animation
        Behavior on implicitWidth { }   // Disable width animation

        Timer {
            id: dismissGuard
            interval: 300
            repeat: false
            onTriggered: GlobalFocusGrab.addDismissable(popupWindow)
        }

        onVisibleChanged: {
            if (visible) {
                popupWindow.screen = root.popupScreen;
                popupFlick.contentY = 0;
                dismissGuard.restart();
            } else {
                dismissGuard.stop();
                GlobalFocusGrab.removeDismissable(popupWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                console.log("[BARPOPUP] onDismissed, screenshotActive=" + BarRuntime.screenshotActive + " activeType=" + root.activeType);
                if (!BarRuntime.screenshotActive) root.close();
            }
        }

        Item {
            id: panel
            anchors {
                top: parent.top
                right: parent.right
            }
            readonly property real shadowMargin: Appearance.sizes.elevationMargin
            readonly property real maxContentHeight: (popupWindow.screen?.height ?? 1080) * 0.75
            readonly property real calcHeight: Math.min(panelContent.implicitHeight + shadowMargin * 2, maxContentHeight)
            implicitWidth: panelBg.implicitWidth + shadowMargin * 2
            implicitHeight: calcHeight
            width: implicitWidth
            height: calcHeight

            StyledRectangularShadow {
                target: panelBg
                visible: true
            }

            TuiShell {
                id: panelBg
                anchors.fill: parent
                anchors.margins: panel.shadowMargin
                implicitWidth: popupWindow.panelWidth
                implicitHeight: panelContent.implicitHeight
                contentPadding: 0
                useLayerMask: false
                color: TuiStyle.bg
                border.width: TuiStyle.borderWidth
                border.color: TuiStyle.menuBorder
                radius: TuiStyle.shellRadius
                clip: true

                StyledFlickable {
                    id: popupFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: panelContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: panelContent
                        width: parent.width
                        spacing: 0

                        // Module popup sections — shown when root.activeType matches the popup section type
                        Repeater {
                            model: ModuleLoader.popupSections
                            delegate: Loader {
                                required property var modelData
                                active: root.activeType === modelData.type
                                source: active ? modelData.component : ""
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                onStatusChanged: if (status === Loader.Error) {
                                    console.warn("[Module] Popup section load failed:", modelData.component)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
