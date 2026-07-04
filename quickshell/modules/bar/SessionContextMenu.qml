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
    property bool canvasEmpty: true
    property string snapshotLabel: snapshotCount > 0 ? `${snapshotCount} windows` : "No snapshot"
    property string sessionCommand: "omd-session"
    signal actionTriggered()
    signal previewRequested()
    signal restoreRequested()

    // Canvas has windows -> snapshot & close. Canvas empty -> restore.
    readonly property bool canRestore: canvasEmpty && hasSnapshot
    readonly property bool canSnapshot: !canvasEmpty

    BarContextMenuItem {
        visible: root.canSnapshot
        iconName: NerdIconMap.download
        iconColor: TuiStyle.accent
        label: `Snapshot & Close Workspaces (${root.snapshotLabel})`
        releaseAction: () => {
            root.previewRequested();
            root.close();
        }
    }

    BarContextMenuItem {
        visible: root.canRestore
        iconName: NerdIconMap.restart
        iconColor: TuiStyle.success
        label: `Restore Workspace Snapshot (${root.snapshotLabel})`
        releaseAction: () => {
            root.restoreRequested();
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
