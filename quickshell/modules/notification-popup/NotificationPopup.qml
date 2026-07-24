import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: notificationPopup

    PanelWindow {
        id: root
        visible: (ServiceManager.notification.popupList.length > 0) && !GlobalStates.screenLocked
        screen: Quickshell.screens.find(s => Config.options.notifications.forceMonitor.enable ? s.name === Config.options.notifications.forceMonitor.name : s.name === Hyprland.focusedMonitor?.name) ?? null
        readonly property bool barOnBottom: Config.options.bar.bottom
        readonly property real outerMargin: Appearance.sizes.elevationMargin

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        anchors {
            top: !root.barOnBottom
            bottom: root.barOnBottom
            right: true
        }

        margins {
            top: root.barOnBottom ? 0 : Appearance.sizes.barHeight + 4
            bottom: root.barOnBottom ? Appearance.sizes.barHeight + 4 : 0
            right: 4
        }

        mask: Region {
            item: listview.contentItem
        }

        color: "transparent"
        implicitWidth: Appearance.sizes.notificationPopupWidth + root.outerMargin * 2
        implicitHeight: Math.min(
            listview.contentHeight + root.outerMargin * 2,
            (root.screen?.height ?? 1080) - Appearance.sizes.barHeight - 8
        )

        NotificationListView {
            id: listview
            anchors {
                fill: parent
                margins: root.outerMargin
            }
            popup: true
        }
    }
}
