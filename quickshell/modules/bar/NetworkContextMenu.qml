pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

BarContextMenu {
    id: root
    menuName: "network"

    BarContextMenuItem {
        iconName: NerdIconMap.wifi
        label: Translation.tr("Wi-Fi Settings")
        releaseAction: () => {
            root.close();
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "network"]);
        }
    }

    BarContextMenuItem {
        iconName: NerdIconMap.wifi
        label: Translation.tr("Network Manager")
        releaseAction: () => {
            root.close();
            Quickshell.execDetached(["nm-connection-editor"]);
        }
    }

    BarContextMenuItem {
        iconName: NerdIconMap.wifi
        label: Translation.tr("Network TUI")
        releaseAction: () => {
            root.close();
            Quickshell.execDetached(["foot", "--app-id=nmtui", "--title=nmtui", "--window-size-pixels=880x620", "-e", "nmtui"]);
        }
    }

    BarContextMenuItem {
        iconName: NerdIconMap.bluetooth
        label: Translation.tr("Bluetooth Manager")
        releaseAction: () => {
            root.close();
            Quickshell.execDetached(["blueman-manager"]);
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
        iconName: NerdIconMap.settings
        label: Translation.tr("Device Settings")
        releaseAction: () => {
            root.close();
            Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "network"]);
        }
    }
}
