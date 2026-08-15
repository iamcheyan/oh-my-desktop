pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts

Item {
    implicitWidth: Math.min(320, contentLayout.implicitWidth + 16)
    implicitHeight: contentLayout.implicitHeight + 16

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
        if (d >= dstStart && d < dstEnd)
            return -4; // EDT
        return -5; // EST
    }

    function formatTimezone(offsetHours, locale) {
        var d = new Date();
        var utc = d.getTime() + (d.getTimezoneOffset() * 60000);
        var targetDate = new Date(utc + (3600000 * offsetHours));
        var h = targetDate.getHours().toString().padStart(2, "0");
        var m = targetDate.getMinutes().toString().padStart(2, "0");

        if (locale === "ja") {
            var jaWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            var jaMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            return jaWeekdays[targetDate.getDay()] + " " + (targetDate.getMonth() + 1) + "/" + targetDate.getDate() + " " + h + ":" + m + " JST";
        } else if (locale === "zh") {
            var zhWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            var zhMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            return zhWeekdays[targetDate.getDay()] + " " + (targetDate.getMonth() + 1) + "/" + targetDate.getDate() + " " + h + ":" + m + " CST";
        } else {
            var enWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            var enMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            var tzName = (offsetHours === -4) ? "EDT" : "EST";
            return enWeekdays[targetDate.getDay()] + ", " + enMonths[targetDate.getMonth()] + " " + targetDate.getDate() + " " + h + ":" + m + " " + tzName;
        }
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                contentLayout.jpValue = root.formatTimezone(9, "ja");
                contentLayout.cnValue = root.formatTimezone(8, "zh");
                contentLayout.usValue = root.formatTimezone(root.getUSEasternOffset(), "en");
            }
        }

        property string jpValue: ""
        property string cnValue: ""
        property string usValue: ""

        StyledPopupValueRow {
            icon: NerdIconMap.circle
            label: "日本 (JST)"
            value: contentLayout.jpValue
        }
        StyledPopupValueRow {
            icon: NerdIconMap.circle
            label: "中国 (CST)"
            value: contentLayout.cnValue
        }
        StyledPopupValueRow {
            icon: NerdIconMap.circle
            label: "米国 (EST/EDT)"
            value: contentLayout.usValue
        }
    }
}
