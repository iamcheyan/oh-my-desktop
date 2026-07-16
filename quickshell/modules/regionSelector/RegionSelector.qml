pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    function dismiss() {
        GlobalStates.regionSelectorOpen = false
        GlobalStates.screenshotActive = false
        Quickshell.execDetached(["rm", "-f", "/tmp/omd-screenshot-active"])
        // Release the bar process from screenshot mode so it can resume
        // normal popup/menu dismiss behavior. This mirrors the `screenshot
        // begin` IPC call made in bin/omd-screenshot before launch.
        // NOTE: FileUtils/Directories are not available in omd-screenshot process;
        // use OMD_REPO_ROOT (set by bin/omd-screenshot) to build the bar path.
        const barDir = (Quickshell.env("OMD_REPO_ROOT") ?? "") + "/apps/omd-bar"
        Quickshell.execDetached([
            "qs", "-p", barDir,
            "ipc", "call", "screenshot", "end"
        ])
    }

    property var action: {
        const envAction = Quickshell.env("OMD_SCREENSHOT_ACTION") ?? "screenshot";
        switch (envAction) {
            case "edit": return RegionSelection.SnipAction.Edit;
            case "search": return RegionSelection.SnipAction.Search;
            case "ocr": return RegionSelection.SnipAction.CharRecognition;
            case "record": return RegionSelection.SnipAction.Record;
            case "recordWithSound": return RegionSelection.SnipAction.RecordWithSound;
            default: return RegionSelection.SnipAction.Copy;
        }
    }
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    readonly property string targetMonitor: Quickshell.env("OMD_SCREENSHOT_MONITOR") ?? ""

    function targetScreens() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return [];
        if (root.targetMonitor === "") return [screens[0]];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === root.targetMonitor) return [screens[i]];
        }
        return [screens[0]];
    }

    onActionChanged: {
        if (action === RegionSelection.SnipAction.Search && Config.options.search.imageSearch.useCircleSelection) {
            selectionMode = RegionSelection.SelectionMode.Circle;
        } else {
            selectionMode = RegionSelection.SelectionMode.RectCorners;
        }
    }

    Variants {
        model: root.targetScreens()
        delegate: Loader {
            id: regionSelectorLoader
            required property var modelData
            active: GlobalStates.regionSelectorOpen

            sourceComponent: RegionSelection {
                screen: regionSelectorLoader.modelData
                onDismiss: root.dismiss()
                action: root.action
                selectionMode: root.selectionMode
            }
        }
    }
}
