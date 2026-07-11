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

    onActionChanged: {
        if (action === RegionSelection.SnipAction.Search && Config.options.search.imageSearch.useCircleSelection) {
            selectionMode = RegionSelection.SelectionMode.Circle;
        } else {
            selectionMode = RegionSelection.SelectionMode.RectCorners;
        }
    }

    Variants {
        model: Quickshell.screens
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
