pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

BarContextMenu {
    id: root
    menuName: "session"

    property bool hasSnapshot: false
    property int snapshotCount: 0
    property string snapshotLabel: snapshotCount > 0 ? `${snapshotCount} windows` : "No snapshot"
    property string sessionCommand: "omd-session"
    signal actionTriggered()

    BarContextMenuItem {
        iconName: root.hasSnapshot ? NerdIconMap.restart : NerdIconMap.download
        iconColor: root.hasSnapshot ? TuiStyle.success : TuiStyle.accent
        label: root.hasSnapshot ? `Restore Workspace Snapshot (${root.snapshotLabel})` : "Snapshot & Close Workspaces"
        releaseAction: () => {
            if (root.hasSnapshot) {
                Quickshell.execDetached([root.sessionCommand, "restore"]);
            } else {
                Quickshell.execDetached([root.sessionCommand, "save-close"]);
            }
            root.actionTriggered();
            root.close();
        }
    }

    BarContextMenuItem {
        visible: root.hasSnapshot
        iconName: NerdIconMap.close
        iconColor: TuiStyle.warning
        label: "Clear Snapshot"
        releaseAction: () => {
            Quickshell.execDetached([root.sessionCommand, "clear"]);
            root.actionTriggered();
            root.close();
        }
    }
}
