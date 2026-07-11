import QtQuick
import Quickshell.Hyprland

Item {
    id: root
    visible: false

    property var runningSet: ({})

    function updateRunningSet() {
        const set = {};
        const wl = HyprlandData.windowList || [];
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

    Component.onCompleted: updateRunningSet()

    Connections {
        target: HyprlandData
        function onWindowListChanged() {
            root.updateRunningSet();
        }
    }
}
