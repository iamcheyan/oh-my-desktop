pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false

    property var runningSet: ({})

    function updateRunningSet(clients) {
        const set = {};
        const wl = clients || [];
        for (let i = 0; i < wl.length; i++) {
            const w = wl[i];
            if (!w || !w.mapped || w.hidden) continue;
            const cls = (w.class || "").toLowerCase();
            const initial = (w.initialClass || "").toLowerCase();
            if (cls) set[cls] = true;
            if (initial) set[initial] = true;
        }
        root.runningSet = set;
    }

    function refresh() {
        clientsProc.running = false;
        clientsProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    root.updateRunningSet(JSON.parse(clientsCollector.text || "[]"));
                } catch (err) {
                    console.warn("[AppLauncher] Failed to parse running apps:", err);
                    root.runningSet = {};
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.runningSet = {};
        }
    }
}
