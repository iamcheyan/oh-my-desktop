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
    // Parsed status output, kept on the root so every gate reads it once
    // instead of re-parsing statusOut.text on each branch.
    property var statusData: ({})

    Component.onCompleted: autoRestoreCheck.start()

    // A marker older than this many seconds is ignored so a stale marker
    // (left by a skipped restore on a previous reload) never restores a
    // long-expired desktop.
    readonly property int maxMarkerAge: 7 * 24 * 3600

    function disarmMarker() {
        disarmProc.running = true
    }

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
                    root.statusData = data;
                    if (data.autoRestore === true && data.saved === true) {
                        // Age gate: ignore a marker whose snapshot is older
                        // than maxMarkerAge so a stale marker never restores
                        // an expired desktop.
                        const now = Math.floor(Date.now() / 1000);
                        const age = now - (data.savedAt || 0);
                        if (age > root.maxMarkerAge) {
                            console.log("[SessionAutoRestore] Skipping auto-restore: snapshot is", age, "s old (max", root.maxMarkerAge + ")");
                            root.disarmMarker();
                            root.expectedCount = 0;
                            return;
                        }
                        // Count real app windows via the compositor-agnostic
                        // chain in clientCountProc.
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
                    // Empty/whitespace output means the tool is present but
                    // failed (broken compositor, jq parse error). Treat it
                    // as unknown (-1), not 0, so we never restore into a
                    // desktop we cannot prove is empty.
                    const openWindows = (raw === "" || raw === "-1") ? -1 : (parseInt(raw) || -1);
                    if (openWindows > 0) {
                        // Windows already open (a Quickshell reload with apps
                        // running). Consume the marker so a later cold boot
                        // does not restore this possibly stale snapshot.
                        console.log("[SessionAutoRestore] Skipping auto-restore:", openWindows, "app windows already open")
                        root.disarmMarker();
                        root.expectedCount = 0;
                        return;
                    }
                    if (openWindows === -1) {
                        // No window enumeration available on this compositor.
                        // Fail safe: never auto-restore into a desktop we
                        // cannot prove is empty. Consume the marker too so it
                        // does not linger.
                        console.log("[SessionAutoRestore] Skipping auto-restore: no reliable window enumeration")
                        root.disarmMarker();
                        root.expectedCount = 0;
                        return;
                    }
                    // Reuse the parsed status from the root property.
                    root.expectedCount = root.statusData.count || 0;
                    root.expectedMonitorCount = root.statusData.monitorCount || 0;
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
                    const currentCount = (raw === "" || raw === "-1") ? -1 : (parseInt(raw) || -1);
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

    // Consumes (unlinks) the restore marker without restoring. Used when a
    // gate skips restore so the marker does not linger and trigger a stale
    // restore on a later boot.
    Process {
        command: ["bash", "-c", root.sessionCommand + " disarm >/dev/null 2>&1 || true"]
        running: false
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
