pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.schedulePopup.notifications
import qs.modules.schedulePopup.calendar
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool popupMode: true

    readonly property int panelHeight: 468
    readonly property int notificationsWidth: 392
    readonly property int calendarWidth: 288

    implicitWidth: notificationsWidth + calendarWidth + 17
    implicitHeight: panelHeight

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_Q || event.key === Qt.Key_Escape) && event.modifiers === Qt.NoModifier) {
            if (root.popupMode)
                GlobalStates.barPopupType = "";
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: root.notificationsWidth
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 8
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: "Notifications"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: TuiStyle.fg
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Notifications.silent
                        ? "Do not disturb is on"
                        : (Notifications.list.length === 0
                            ? "All clear"
                            : `${Notifications.list.length} notification${Notifications.list.length === 1 ? "" : "s"}`)
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: TuiStyle.dim
                }
            }

            TuiNotificationList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                showHeader: false
                showFooter: true
                hubStyle: true
                compactRows: true
                markReadOnVisible: true
                maxListHeight: root.panelHeight - 108
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            color: TuiStyle.line
            opacity: TuiStyle.dividerOpacity
        }

        ColumnLayout {
            Layout.preferredWidth: root.calendarWidth
            Layout.fillHeight: true
            Layout.leftMargin: 8
            Layout.rightMargin: 16
            Layout.topMargin: 14
            Layout.bottomMargin: 14

            CalendarWidget {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                showTodayHero: true
                hubMode: true
            }
        }
    }
}