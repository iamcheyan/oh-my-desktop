import qs
import qs.modules.common
import QtQuick
import Quickshell

Item {
    id: root

    property bool vertical: false
    property int widgetPadding: 0
    readonly property string overviewApp: `${Directories.config}/omd/apps/omd-overview`

    function toggleOverview() {
        Quickshell.execDetached([
            "qs", "-p", root.overviewApp, "ipc", "call", "overview", "toggle"
        ]);
    }

    implicitWidth: workspacesButton.implicitWidth
    implicitHeight: workspacesButton.implicitHeight

    BarTextButton {
        id: workspacesButton
        text: "Workspaces"
        onTriggered: root.toggleOverview()
    }
}
