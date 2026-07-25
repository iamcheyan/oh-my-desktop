pragma ComponentBehavior: Bound
import qs.modules.common
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

    ContextMenuItem {
        visible: root.hibernateAvailable
        nerdIcon: NerdIconMap.download
        labelText: "Hibernate"
        onClicked: {
            root.close();
            ActionManager.invoke("session.hibernate");
        }
    }

    ContextMenuSeparator {
        visible: root.hibernateAvailable
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.logout
        labelText: "Logout"
        onClicked: {
            root.close();
            ActionManager.invoke("session.logout");
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.restart
        labelText: "Reboot"
        onClicked: {
            root.close();
            ActionManager.invoke("session.reboot");
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.powerSettingsNew
        labelText: "Shutdown"
        onClicked: {
            root.close();
            ActionManager.invoke("session.shutdown");
        }
    }

    ContextMenuSeparator {}

    ContextMenuItem {
        nerdIcon: NerdIconMap.settings
        labelText: "Settings"
        onClicked: {
            root.close();
            ActionManager.invoke("settings.open", {section: "overview"});
        }
    }

    ContextMenuItem {
        nerdIcon: NerdIconMap.refresh
        labelText: "Reload Shell"
        onClicked: {
            root.close();
            ActionManager.invoke("shell.reload");
        }
    }
}
