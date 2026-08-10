pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.core.runtime
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ContextMenuWindow {
    id: root

    property bool hibernateAvailable: false

    Process {
        command: ["bash", "-c", "grep -q disk /sys/power/state 2>/dev/null && echo YES || echo NO"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hibernateAvailable = text.trim() === "YES"
        }
    }

    // ── Snapshot group ──
    ContextMenuItem {
        nerdIcon: NerdIconMap.archive
        labelText: "Save Snapshot"
        shortcutKey: "V"
        onClicked: {
            root.close();
            Quickshell.execDetached([`${Directories.root}/bin/sumika-session`, "save"]);
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.unarchive
        labelText: "Restore Snapshot"
        shortcutKey: "R"
        onClicked: {
            root.close();
            Session.restoreIfEmpty();
        }
    }

    ContextMenuSeparator {}

    // ── Power actions ──
    ContextMenuItem {
        visible: root.hibernateAvailable
        nerdIcon: NerdIconMap.download
        labelText: "Hibernate"
        shortcutKey: "H"
        onClicked: {
            Session.hibernate(GlobalStates.sessionSaveOnExit);
        }
    }

    ContextMenuSeparator {
        visible: root.hibernateAvailable
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.logout
        labelText: "Logout"
        shortcutKey: "L"
        onClicked: {
            root.close();
            Session.logout(GlobalStates.sessionSaveOnExit);
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.restart
        labelText: "Reboot"
        shortcutKey: "B"
        onClicked: {
            root.close();
            Session.reboot(GlobalStates.sessionSaveOnExit);
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.powerSettingsNew
        labelText: "Shutdown"
        shortcutKey: "U"
        onClicked: {
            root.close();
            Session.poweroff(GlobalStates.sessionSaveOnExit);
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.refresh
        labelText: "Reload Shell"
        shortcutKey: "A"
        onClicked: {
            root.close();
            Quickshell.execDetached(["bash", `${Directories.root}/bin/sumika-restart`]);
        }
    }
}
