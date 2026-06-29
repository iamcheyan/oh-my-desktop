pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

BarContextMenu {
    id: root
    menuName: "screenshot"

    BarContextMenuItem {
        iconName:  NerdIconMap.crop
        label:     Translation.tr("Capture Area")
        releaseAction: () => {
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
            root.close();
        }
    }

    BarContextMenuItem {
        iconName:  NerdIconMap.camera
        label:     Translation.tr("Capture Fullscreen")
        releaseAction: () => {
            Quickshell.execDetached(["bash", "-c",
                "grim -o $(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name') - | wl-copy && notify-send -i camera-photo Screenshot \"Full screen copied to clipboard\""
            ]);
            root.close();
        }
    }

    BarContextMenuItem {
        iconName:  NerdIconMap.desktop
        label:     Translation.tr("Capture Monitor (3s delay)")
        releaseAction: () => {
            Quickshell.execDetached(["bash", "-c",
                "monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'); notify-send -i camera-photo Screenshot \"Capturing current monitor in 3 seconds\"; sleep 3; grim -o \"$monitor\" - | wl-copy && notify-send -i camera-photo Screenshot \"Current monitor copied to clipboard\""
            ]);
            root.close();
        }
    }

    Rectangle {
        Layout.fillWidth:    true
        implicitHeight:      1
        color:               TuiStyle.line
        opacity:             TuiStyle.dividerOpacity
        Layout.topMargin:    root.separatorMargin
        Layout.bottomMargin: root.separatorMargin
    }

    BarContextMenuItem {
        iconName:  NerdIconMap.eyeDropper
        label:     Translation.tr("Color Picker")
        releaseAction: () => { Quickshell.execDetached(["hyprpicker", "-a"]); root.close() }
    }

    BarContextMenuItem {
        iconName:  NerdIconMap.video
        label:     Translation.tr("Record Screen")
        releaseAction: () => { Quickshell.execDetached([Directories.recordScriptPath]); root.close() }
    }

    Rectangle {
        Layout.fillWidth:    true
        implicitHeight:      1
        color:               TuiStyle.line
        opacity:             TuiStyle.dividerOpacity
        Layout.topMargin:    root.separatorMargin
        Layout.bottomMargin: root.separatorMargin
    }

    BarContextMenuItem {
        iconName:  NerdIconMap.desktop
        label:     Translation.tr("Display Settings")
        releaseAction: () => {
            root.close();
            Quickshell.execDetached([
                "qs", "-p", `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-bar`,
                "ipc", "call", "barDialog", "open", "nightlight"
            ]);
        }
    }
}
