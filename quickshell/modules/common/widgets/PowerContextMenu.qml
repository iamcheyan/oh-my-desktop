pragma ComponentBehavior: Bound
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
            // Consistent with SessionAutoRestore: only restore when no app
            // windows are open. Hyprland counts via hyprctl; labwc via
            // wlrctl (wlr-foreign-toplevel lists app toplevels only, not
            // shell surfaces like the bar itself).
            Quickshell.execDetached(["bash", "-c", `if pgrep -x labwc >/dev/null 2>&1; then `
                                     + `  clients=$(wlrctl toplevel list 2>/dev/null | wc -l); ` + `else `
                                     + `  clients=$(hyprctl -j clients | jq 'length' 2>/dev/null || echo 0); `
                                     + `fi; ` + `if [ "$clients" -gt 0 ]; then `
                                     + `echo "Workspace not empty ($clients windows) — restore cancelled"; `
                                     + `else ${Directories.root}/bin/sumika-session restore; fi`]);
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
            root.close();
            Session.hibernate(true);
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
            Session.logout(true);
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.restart
        labelText: "Reboot"
        shortcutKey: "B"
        onClicked: {
            root.close();
            Session.reboot(true);
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.powerSettingsNew
        labelText: "Shutdown"
        shortcutKey: "U"
        onClicked: {
            root.close();
            Session.poweroff(true);
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
