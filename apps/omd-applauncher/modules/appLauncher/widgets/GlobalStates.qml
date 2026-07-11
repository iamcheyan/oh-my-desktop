pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Minimal GlobalStates for the omd-applauncher process.
// The full version (quickshell/GlobalStates.qml) is used by omd-bar and
// other processes. This standalone copy only exposes the single property
// that AppLauncher.qml reads, avoiding the GlobalShortcut/
// OverviewSwitchingController chain that the full version pulls in.
Singleton {
    id: root

    // AppLauncher.isAppRunning() checks this to detect whether the
    // Settings Center (opened via omd-bar IPC) is currently visible.
    property bool barDialogOpen: false
}
