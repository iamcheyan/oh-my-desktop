pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io

ContextMenuWindow {
    id: root

    property string wallpaperMode: ""

    // Read wallpaper mode from runtime state file
    FileView {
        id: modeFile
        path: `${Directories.sumikaStateHome}/wallpaper/mode`
        watchChanges: true

        onLoaded: root.wallpaperMode = text.trim()
        onLoadFailed: root.wallpaperMode = ""
    }

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
