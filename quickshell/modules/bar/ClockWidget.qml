import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    readonly property var weekdays: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function formatDateTime(date) {
        var d = date;
        var monthStr = root.months[d.getMonth()];
        var day = d.getDate();
        var wd = root.weekdays[d.getDay()];
        var h = d.getHours().toString().padStart(2, "0");
        var m = d.getMinutes().toString().padStart(2, "0");
        return wd + " " + monthStr + " " + day + " " + h + ":" + m;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StyledText {
        id: clockText
        anchors.centerIn: parent
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Normal
        color: Appearance.colors.colBarText
        text: root.formatDateTime(clock.date)
    }

    Rectangle {
        visible: !Notifications.silent && Notifications.unread > 0
        anchors.right: clockText.right
        anchors.top: clockText.top
        anchors.rightMargin: -2
        anchors.topMargin: -2
        width: 6
        height: 6
        radius: 3
        color: Appearance.colors.colBarText
        z: 1
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            GlobalStates.barPopupType = GlobalStates.barPopupType === "notifications" ? "" : "notifications"
        }
    }
}
