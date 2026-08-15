// NotificationsPopup.qml — Notification list popup.
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.bar
import qs.core.runtime
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: notifPopup
    spacing: 0
    width: parent?.width ?? implicitWidth

    PopupHeader {
        Layout.fillWidth: true
        icon: ServiceManager.notification.silent ? NerdIconMap.notificationsOff : NerdIconMap.notifications
        title: "Notifications"
        subtitle: ServiceManager.notification.silent
            ? "Do not disturb"
            : (ServiceManager.notification.list.length === 0
                ? "All clear"
                : `${ServiceManager.notification.list.length} notification${ServiceManager.notification.list.length === 1 ? "" : "s"}`)
        tone: ServiceManager.notification.silent ? TuiStyle.warning : TuiStyle.success

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 12

            PopupActionButton {
                icon: "settings"
                onClicked: {
                    GlobalStates.barPopupType = "";
                    ServiceManager.notification.openMutedAppsEditor();
                }
            }

            PopupActionButton {
                icon: "delete_sweep"
                colorHover: TuiStyle.danger
                visible: ServiceManager.notification.list.length > 0
                onClicked: ServiceManager.notification.discardAllNotifications()
            }

            // DND Toggle Switch - unified size
            Rectangle {
                id: dndToggle
                Layout.alignment: Qt.AlignVCenter
                width: 46
                height: 26
                radius: height / 2
                color: !ServiceManager.notification.silent ? TuiStyle.accent : TuiStyle.controlMuted
                border.width: TuiStyle.borderWidth
                border.color: !ServiceManager.notification.silent ? TuiStyle.shellBorder : TuiStyle.line

                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    x: !ServiceManager.notification.silent ? parent.width - width - 3 : 3
                    color: !ServiceManager.notification.silent ? TuiStyle.bg : TuiStyle.fg
                    Behavior on x { NumberAnimation { duration: 110 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceManager.notification.toggleSilent()
                }
            }
        }

        WheelHandler {
            onWheel: (event) => notifList.scrollByDelta(event.angleDelta.y)
        }
    }

    TuiNotificationList {
        id: notifList
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 16
        showHeader: false
        showFooter: false
        showFooterDnd: false
        compactRows: true
        markReadOnVisible: true
        maxListHeight: Math.round((Quickshell.screens[0]?.height ?? 900) * 0.90)
    }
}
