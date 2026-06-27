import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    NotificationListView { // Scrollable window
        id: listview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.bottomMargin: 6

        clip: true

        popup: false
    }

    Rectangle {
        anchors.centerIn: listview
        visible: Notifications.list.length === 0
        implicitWidth: emptyText.implicitWidth + 18
        implicitHeight: 28
        radius: 0
        color: Appearance.tiling.bg
        border.width: Appearance.tiling.borderWidth
        border.color: Appearance.tiling.border

        StyledText {
            id: emptyText
            anchors.centerIn: parent
            text: "no notifications"
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.tiling.textDim
        }
    }

    Rectangle {
        id: statusRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        implicitHeight: statusLayout.implicitHeight
        radius: 0
        color: "transparent"

        RowLayout {
            id: statusLayout
            anchors.fill: parent
            spacing: 4

            NotificationStatusButton {
                Layout.fillWidth: false
                buttonIcon: "notifications_paused"
                toggled: Notifications.silent
                onClicked: () => {
                    Notifications.silent = !Notifications.silent;
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 0
                color: Appearance.tiling.bg
                border.width: Appearance.tiling.borderWidth
                border.color: Appearance.tiling.border

                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("%1 notifications").arg(Notifications.list.length)
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.tiling.textDim
                }
            }

            NotificationStatusButton {
                Layout.fillWidth: false
                buttonIcon: "delete_sweep"
                onClicked: () => {
                    Notifications.discardAllNotifications()
                }
            }
        }
    }
}
