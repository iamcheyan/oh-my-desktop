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

    readonly property string sessionCommand: Directories.root + "/bin/sumika-session"
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
                        // Reload (not cold boot): count real app windows via
                        // the compositor-agnostic chain in clientCountProc.
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
        // Compositor-agnostic app-window count:
        //   Hyprland -> hyprctl (guarded by HYPRLAND_INSTANCE_SIGNATURE)
        //   wlroots  -> wlrctl toplevel list (foreign-toplevel protocol;
        //               excludes layer-shell surfaces such as the bar's
        //               own panels and popups)
        //   neither  -> -1 (unknown — caller treats this as "do not restore")
        command: ["bash", "-c",
            "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && command -v hyprctl >/dev/null 2>&1; then " +
            "  hyprctl -j clients | jq 'length' 2>/dev/null; " +
            "elif command -v wlrctl >/dev/null 2>&1; then " +
            "  wlrctl toplevel list 2>/dev/null | wc -l; " +
            "else echo -1; fi"]
        running: false
        stdout: StdioCollector {
            id: clientCountOut
            onStreamFinished: {
                try {
                    const raw = (clientCountOut.text || "").trim();
                    const openWindows = raw === "-1" ? -1 : parseInt(raw) || 0;
                    if (openWindows > 0) {
                        console.log("[SessionAutoRestore] Skipping auto-restore:", openWindows, "app windows already open")
                        return;
                    }
                    if (openWindows === -1) {
                        // No window enumeration available on this compositor.
                        // Fail safe: never auto-restore into a desktop we
                        // cannot prove is empty.
                        console.log("[SessionAutoRestore] Skipping auto-restore: no window enumeration tool available")
                        return;
                    }
                    // Re-read status for expected counts (statusProc already ran).
                    const statusData = JSON.parse(statusOut.text);
                    root.expectedCount = statusData.count || 0;
                    root.expectedMonitorCount = statusData.monitorCount || 0;
                    root.monitorReadyAttempts = 0;
                    monitorReadyCheck.start();
                } catch (e) {
                    console.log("[SessionAutoRestore] client count failed:", e)
                    root.expectedCount = 0;
                }
            }
        }
    }

    Process {
        id: monitorCountProc
        // Same fallback chain as clientCountProc: Hyprland -> hyprctl,
        // wlroots -> wlr-randr, neither -> -1 (accepted after max attempts).
        command: ["bash", "-c",
            "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && command -v hyprctl >/dev/null 2>&1; then " +
            "  hyprctl -j monitors | jq 'length' 2>/dev/null; " +
            "elif command -v wlr-randr >/dev/null 2>&1; then " +
            "  wlr-randr --json 2>/dev/null | jq 'length' 2>/dev/null; " +
            "else echo -1; fi"]
        running: false
        stdout: StdioCollector {
            id: monitorCountOut
            onStreamFinished: {
                try {
                    const raw = (monitorCountOut.text || "").trim();
                    const currentCount = raw === "-1" ? -1 : parseInt(raw) || 0;
                    root.monitorReadyAttempts += 1;
                    // Accept if monitors match expected count, or after 5
                    // attempts (~4s) as a fallback so we don't block forever.
                    if (currentCount >= root.expectedMonitorCount || root.monitorReadyAttempts >= 5) {
                        monitorReadyCheck.stop();
                        restoreLoader.active = true;
                    }
                } catch (e) {
                    // If the count fails, just proceed after max attempts.
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
            item.startRestore();
        }
    }
}
