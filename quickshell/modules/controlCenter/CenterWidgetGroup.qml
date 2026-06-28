import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.controlCenter.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 0
    color: TuiStyle.bg
    border.width: TuiStyle.borderWidth
    border.color: TuiStyle.line

    NotificationList {
        anchors.fill: parent
        anchors.margins: 6
    }
}
