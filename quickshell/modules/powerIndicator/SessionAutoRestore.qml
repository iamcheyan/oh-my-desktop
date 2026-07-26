pragma ComponentBehavior: Bound

import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string sessionCommand: Directories.root + "/bin/omd-session"
    property int expectedCount: 0
    property int expectedMonitorCount: 0
    property int monitorReadyAttempts: 0

    Component.onCompleted: autoRestoreCheck.start()

    Timer {
        id: autoRestoreCheck
        interval: 1800
        repeat: false
        onTriggered: statusProc.running = true
    }

    // After status confirms auto-restore is armed, wait until the number of
    // monitors reported by Hyprland matches the snapshot. This avoids
    // restoring before all displays are ready after a reboot.
    Timer {
        id: monitorReadyCheck
        interval: 800
        repeat: true
        onTriggered: {
            monitorCountProc.running = false;
            monitorCountProc.running = true;
        }
    }

    Process {
        id: statusProc
        command: [root.sessionCommand, "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(statusOut.text);
                    if (data.autoRestore === true && data.saved === true) {
                        // Check if real app windows are already open (reload,
                        // not cold boot). Use hyprctl clients — NOT
                        // ToplevelManager.toplevels, which also counts the
                        // bar's own PanelWindow, polkit, notification popup,
                        // OSD, and other shell surfaces.
                        clientCountProc.running = true;
                    } else {
                        root.expectedCount = 0;
                    }
                } catch (e) {
                    root.expectedCount = 0;
                }
            }
        }
    }

    Process {
        id: clientCountProc
        command: ["bash", "-c", "hyprctl -j clients | jq 'length'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const openWindows = parseInt(clientCountOut.text.trim()) ?? 0;
                    if (openWindows > 0) {
                        console.log("[SessionAutoRestore] Skipping auto-restore:", openWindows, "app windows already open")
                        return;
                    }
                    // Re-read status for expected counts (statusProc already ran).
                    const statusData = JSON.parse(statusOut.text);
                    root.expectedCount = statusData.count || 0;
                    root.expectedMonitorCount = statusData.monitorCount || 0;
                    root.monitorReadyAttempts = 0;
                    monitorReadyCheck.start();
                } catch (e) {
                    root.expectedCount = 0;
                }
            }
        }
    }

    Process {
        id: monitorCountProc
        command: ["bash", "-c", "hyprctl -j monitors | jq 'length'"]
        running: false
        stdout: StdioCollector {
            id: monitorCountOut
            onStreamFinished: {
                try {
                    const currentCount = parseInt(monitorCountOut.text.trim()) || 0;
                    root.monitorReadyAttempts += 1;
                    // Accept if monitors match expected count, or after 5
                    // attempts (~4s) as a fallback so we don't block forever.
                    if (currentCount >= root.expectedMonitorCount || root.monitorReadyAttempts >= 5) {
                        monitorReadyCheck.stop();
                        restoreLoader.active = true;
                    }
                } catch (e) {
                    // If jq fails, just proceed after max attempts.
                    if (root.monitorReadyAttempts >= 5) {
                        monitorReadyCheck.stop();
                        restoreLoader.active = true;
                    }
                }
            }
        }
    }

    Loader {
        id: restoreLoader
        active: false
        source: "SessionRestoreOverlay.qml"
        onLoaded: {
            item.sessionCommand = root.sessionCommand;
            item.restoreAction = "restore-auto";
            item.expectedCount = root.expectedCount;
            item.finished.connect(function() { restoreLoader.active = false });
        }
    }
}
