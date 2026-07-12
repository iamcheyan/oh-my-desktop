pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: wrapper
    property bool hibernateAvailable: false
    property alias menu: powerMenu

    Process {
        command: ["bash", "-c", "grep -q disk /sys/power/state 2>/dev/null && echo YES || echo NO"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: wrapper.hibernateAvailable = text.trim() === "YES"
        }
    }

    BarContextMenu {
        id: powerMenu
        menuName: "power"

        BarContextMenuItem {
            iconName: NerdIconMap.download
            label: "Hibernate"
            visible: wrapper.hibernateAvailable
            releaseAction: () => { powerMenu.close(); Session.hibernate() }
        }

        Rectangle {
            Layout.fillWidth:    true
            implicitHeight:      1
            color:               TuiStyle.line
            opacity:             TuiStyle.dividerOpacity
            Layout.topMargin:    powerMenu.separatorMargin
            Layout.bottomMargin: powerMenu.separatorMargin
            visible: wrapper.hibernateAvailable
        }

        BarContextMenuItem {
            iconName: NerdIconMap.logout
            label: "Logout"
            releaseAction: () => { powerMenu.close(); Session.logout() }
        }

        BarContextMenuItem {
            iconName: NerdIconMap.restart
            label: "Reboot"
            releaseAction: () => { powerMenu.close(); Session.reboot() }
        }

        BarContextMenuItem {
            iconName: NerdIconMap.powerSettingsNew
            label: "Shutdown"
            releaseAction: () => { powerMenu.close(); Session.poweroff() }
        }

        Rectangle {
            Layout.fillWidth:    true
            implicitHeight:      1
            color:               TuiStyle.line
            opacity:             TuiStyle.dividerOpacity
            Layout.topMargin:    powerMenu.separatorMargin
            Layout.bottomMargin: powerMenu.separatorMargin
        }

        BarContextMenuItem {
            iconName: NerdIconMap.settings
            label: "Settings"
            releaseAction: () => {
                powerMenu.close();
                Quickshell.execDetached([`${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "overview"]);
            }
        }

        BarContextMenuItem {
            iconName: NerdIconMap.refresh
            label: "Reload Shell"
            releaseAction: () => {
                powerMenu.close();
                Quickshell.execDetached(["bash", `${FileUtils.trimFileProtocol(Directories.config)}/scripts/reload-quickshell`]);
            }
        }
    }
}
