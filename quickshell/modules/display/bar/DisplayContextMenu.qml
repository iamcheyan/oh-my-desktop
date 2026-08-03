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
        shortcutKey: "M"
        onClicked: {
            root.close();
            Quickshell.execDetached([`${Directories.root}/bin/sumika-settings`, "open", "display"]);
        }
    }

    ContextMenuSeparator {
        visible: root.wallpaperMode === "folder"
    }

    // ── Next wallpaper (folder mode only) ──
    ContextMenuItem {
        visible: root.wallpaperMode === "folder"
        nerdIcon: NerdIconMap.imageMultiple
        labelText: "Next wallpaper"
        shortcutKey: "N"
        onClicked: {
            root.close();
            Quickshell.execDetached([
                "sumika-settings-theme", "wallpaper-next"
            ]);
        }
    }

    // ── Delete current wallpaper (folder mode only) ──
    ContextMenuItem {
        visible: root.wallpaperMode === "folder"
        nerdIcon: NerdIconMap.trashCan
        labelText: "Delete current wallpaper"
        shortcutKey: "D"
        onClicked: {
            root.close();
            Quickshell.execDetached([
                "sumika-wallpaper", "delete-current"
            ]);
        }
    }
}
