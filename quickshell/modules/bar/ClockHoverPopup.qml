import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    alignRight: true

    function getUSEasternOffset() {
        var d = new Date();
        var year = d.getFullYear();
        // DST start: second Sunday of March
        var march = new Date(year, 2, 1);
        var marchSun = 14 - march.getDay();
        var dstStart = new Date(year, 2, marchSun, 2, 0, 0);

        // DST end: first Sunday of November
        var nov = new Date(year, 10, 1);
        var novSun = 7 - nov.getDay();
        var dstEnd = new Date(year, 10, novSun, 2, 0, 0);

        if (d >= dstStart && d < dstEnd) {
            return -4; // EDT
        } else {
            return -5; // EST
        }
    }

    function formatTimezone(offsetHours, locale) {
        var d = new Date();
        // Get UTC milliseconds
        var utc = d.getTime() + (d.getTimezoneOffset() * 60000);
        // Create new date object for target timezone
        var targetDate = new Date(utc + (3600000 * offsetHours));

        var month = targetDate.getMonth();
        var date = targetDate.getDate();
        var day = targetDate.getDay();
        var h = targetDate.getHours().toString().padStart(2, "0");
        var m = targetDate.getMinutes().toString().padStart(2, "0");

        if (locale === "ja") {
            var jaWeekdays = ["日", "月", "火", "水", "木", "金", "土"];
            return (month + 1) + "月" + date + "日(" + jaWeekdays[day] + ") " + h + ":" + m + " JST";
        } else if (locale === "zh") {
            var zhWeekdays = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
            return (month + 1) + "月" + date + "日 " + zhWeekdays[day] + " " + h + ":" + m + " CST";
        } else {
            var enWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            var enMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            var tzName = (offsetHours === -4) ? "EDT" : "EST";
            return enWeekdays[day] + ", " + enMonths[month] + " " + date + " " + h + ":" + m + " " + tzName;
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

        // Update times every second while visible
        Timer {
            interval: 1000
            running: root.active
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                jpRow.value = root.formatTimezone(9, "ja");
                cnRow.value = root.formatTimezone(8, "zh");
                usRow.value = root.formatTimezone(root.getUSEasternOffset(), "en");
            }
        }

        StyledPopupHeaderRow {
            Layout.fillWidth: true
            icon: "actions/appointment-new-symbolic"
            label: "WORLD CLOCK"
        }

        // Slight gap
        Item {
            Layout.preferredHeight: 2
            Layout.fillWidth: true
        }

        StyledPopupValueRow {
            id: jpRow
            icon: "apps/preferences-desktop-locale-symbolic"
            label: "日本 (东京 - JST):"
            value: ""
        }

        StyledPopupValueRow {
            id: cnRow
            icon: "apps/preferences-desktop-locale-symbolic"
            label: "中国 (北京 - CST):"
            value: ""
        }

        StyledPopupValueRow {
            id: usRow
            icon: "apps/preferences-desktop-locale-symbolic"
            label: "美国 (纽约 - EST/EDT):"
            value: ""
        }
    }
}
