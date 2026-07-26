import qs
import qs.services
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell

Item {
    id: root
    property string moduleId: "workspaces"

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

    Component {
        id: hoverComponent
        HoverInfo {}
    }

    Component.onCompleted: HoverInfoService.register(root.moduleId, hoverComponent)
    Component.onDestruction: HoverInfoService.unregister(root.moduleId)

    HoverInfoPopup {
        moduleId: root.moduleId
        hoverTarget: workspacesButton
    }
}
