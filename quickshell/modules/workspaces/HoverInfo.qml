pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts

Item {
    readonly property int _activeWsId: ServiceManager.workspace?.activeWorkspace?.id ?? 0

    implicitWidth: Math.min(280, contentLayout.implicitWidth + 16)
    implicitHeight: contentLayout.implicitHeight + 16

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: _dummy = !_dummy
    }
    property bool _dummy: false

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        StyledPopupValueRow {
            icon: NerdIconMap.desktop
            label: "Current workspace"
            value: String(root._activeWsId)
        }
        StyledPopupValueRow {
            icon: NerdIconMap.windows
            label: "Windows on workspace"
            value: {
                const wsId = root._activeWsId;
                if (wsId < 1) return "-";
                const wsData = ServiceManager.workspace?.workspaceById?.[wsId];
                if (wsData && typeof wsData.windows === "number")
                    return String(wsData.windows);
                const clients = ServiceManager.workspace?.hyprlandClientsForWorkspace?.(wsId) ?? [];
                return String(clients.filter(c => c.mapped && !c.hidden).length);
            }
        }
        StyledPopupValueRow {
            icon: NerdIconMap.expandMore
            label: "Total workspaces"
            value: {
                const entries = ServiceManager.workspace?.overviewWorkspaceEntries ?? [];
                return String(entries.length);
            }
        }
    }
}
