import qs
import qs.modules.common
import QtQuick
import Quickshell

Item {
    id: root

    property bool vertical: false
    property int widgetPadding: 0

    implicitWidth: workspacesButton.implicitWidth
    implicitHeight: workspacesButton.implicitHeight

    BarTextButton {
        id: workspacesButton
        text: "Workspaces"
        onTriggered: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    }
}