import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell

Item {
    id: root

    function toggleOverview() {
        ActionManager.invoke("overview.open");
    }

    implicitWidth: workspacesButton.implicitWidth
    implicitHeight: workspacesButton.implicitHeight

    BarTextButton {
        id: workspacesButton
        text: "Workspaces"
        onTriggered: root.toggleOverview()
    }
}
