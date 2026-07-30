pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

ContextMenuWindow {
    id: root

    /// Wallpaper mode passed from DisplayButton (long-lived FileView watcher)
    property string wallpaperMode: ""

    // ── Monitor settings ──
    ContextMenuItem {
        nerdIcon: NerdIconMap.settings
        labelText: "Monitor settings"
        onClicked: {
            root.close();
            Quickshell.execDetached([`${Directories.root}/bin/sumika-settings`, "open", "display"]);
        }
    }

    // ── Next wallpaper (folder mode only) ──
    ContextMenuItem {
        visible: root.wallpaperMode === "folder"
        nerdIcon: NerdIconMap.shuffle
        labelText: "Next wallpaper"
        onClicked: {
            root.close();
            Quickshell.execDetached([
                "sumika-settings-theme", "wallpaper-next"
            ]);
        }
    }
}
