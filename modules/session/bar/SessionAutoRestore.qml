pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string sessionCommand: `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-session`
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
            id: statusOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(statusOut.text);
                    if (data.autoRestore === true && data.saved === true) {
                        root.expectedCount = data.count || 0;
                        root.expectedMonitorCount = data.monitorCount || 0;
                        // Start monitor readiness check.
                        root.monitorReadyAttempts = 0;
                        monitorReadyCheck.start();
                    }
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
        sourceComponent: SessionRestoreOverlay {
            sessionCommand: root.sessionCommand
            restoreAction: "restore-auto"
            expectedCount: root.expectedCount
            onFinished: restoreLoader.active = false
        }
    }
}
