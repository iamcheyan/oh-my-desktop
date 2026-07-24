// NotificationsPopup.qml — Notification list popup.
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

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "settings"
                iconSize: 20
                color: mutedSettingsMouse.containsMouse ? TuiStyle.fg : TuiStyle.dim

                MouseArea {
                    id: mutedSettingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        GlobalStates.barPopupType = "";
                        ServiceManager.notification.openMutedAppsEditor();
                    }
                }
            }

            // Broom button to clear notifications
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "delete_sweep"
                iconSize: 20
                color: clearMouse.containsMouse ? TuiStyle.danger : TuiStyle.dim
                visible: ServiceManager.notification.list.length > 0

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceManager.notification.discardAllNotifications()
                }
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
    }

    TuiNotificationList {
        Layout.fillWidth: true
        Layout.topMargin: visible ? 12 : 0
        visible: !ServiceManager.notification.silent
        Layout.bottomMargin: 16
        showHeader: false
        showFooter: false
        showFooterDnd: false
        compactRows: true
        markReadOnVisible: true
        maxListHeight: Math.round((Quickshell.screens[0]?.height ?? 900) * 0.72)
    }
}
