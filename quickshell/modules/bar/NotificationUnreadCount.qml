import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar

Item {
    id: root
    property color color: Appearance.colors.colBarText
    readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
    implicitWidth: notificationIcon.implicitWidth
    implicitHeight: notificationIcon.implicitHeight

    BarNerdIcon {
        id: notificationIcon
        anchors.fill: parent
        text: Notifications.silent ? NerdIconMap.notificationsOff : NerdIconMap.notifications
        color: root.color
    }

    Rectangle {
        id: notifPing
        visible: !Notifications.silent && Notifications.unread > 0
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : 1
            topMargin: root.showUnreadCount ? 0 : 3
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colBarText
        z: 1

        implicitHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitWidth, notificationCounterText.implicitHeight) : 8
        implicitWidth: implicitHeight

        StyledText {
            id: notificationCounterText
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colLayer0
            text: Notifications.unread
        }
    }
}
