import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.settings
import qs.modules.settings.widgets
import qs.modules.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.popup-components

PopupColumn {
    id: sessionPanel
    readonly property string omdSession: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`
    readonly property string snapshotFile: `${Directories.sumikaStateHome}/session/last.json`
    property bool hasSnapshot: false
    property int snapshotCount: 0
    property bool canvasEmpty: ToplevelManager.toplevels.values.length === 0
    property string saveOutput: ""

    FileView {
        path: sessionPanel.snapshotFile
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const count = Array.isArray(data.clients) ? data.clients.length : 0;
                sessionPanel.hasSnapshot = count > 0;
                sessionPanel.snapshotCount = count;
            } catch (e) {
                sessionPanel.hasSnapshot = false;
                sessionPanel.snapshotCount = 0;
            }
        }
        onLoadFailed: {
            sessionPanel.hasSnapshot = false;
            sessionPanel.snapshotCount = 0;
        }
    }

    Process {
        id: sessionSaveProcess
        command: [sessionPanel.omdSession, "save"]

        stdout: StdioCollector {
            onStreamFinished: {
                sessionPanel.saveOutput = text;
            }
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
                const data = JSON.parse(sessionPanel.saveOutput);
                if (data.saved) {
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

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.workspaceSnapshot
        title: "Session"
        subtitle: sessionPanel.canvasEmpty ? "No windows open"
            : `${ToplevelManager.toplevels.values.length} window${ToplevelManager.toplevels.values.length === 1 ? "" : "s"} open`
        tone: sessionPanel.canvasEmpty ? TuiStyle.muted : TuiStyle.success
    }

    PopupInfoRow {
        label: "Saved snapshot"
        value: sessionPanel.hasSnapshot ? `${sessionPanel.snapshotCount} windows` : "None"
        valueColor: sessionPanel.hasSnapshot ? TuiStyle.accent : TuiStyle.dim
        showDivider: false
    }

    IconActionRow {
        PopupIconButton {
            icon: NerdIconMap.workspaceSnapshot
            label: "Save"
            accent: TuiStyle.info
            enabledState: !sessionPanel.canvasEmpty || sessionPanel.hasSnapshot
            onClicked: {
                root.close();
                if (!sessionSaveProcess.running)
                    sessionSaveProcess.running = true;
            }
        }
        PopupIconButton {
            icon: NerdIconMap.close
            label: "Save & Close"
            accent: TuiStyle.warning
            enabledState: !sessionPanel.canvasEmpty || sessionPanel.hasSnapshot
            onClicked: { root.close(); Quickshell.execDetached([sessionPanel.omdSession, "save-close"]); }
        }
        PopupIconButton {
            icon: NerdIconMap.refresh
            label: "Restore"
            accent: TuiStyle.accent
            enabledState: sessionPanel.hasSnapshot
            onClicked: { root.close(); Quickshell.execDetached([sessionPanel.omdSession, "restore"]); }
        }
    }
}
