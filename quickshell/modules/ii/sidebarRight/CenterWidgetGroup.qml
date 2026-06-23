import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 0
    color: Appearance.tiling.bg
    border.width: Appearance.tiling.borderWidth
    border.color: Appearance.tiling.border

    NotificationList {
        anchors.fill: parent
        anchors.margins: 6
    }
}
