import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Update times every second while visible
    Timer {
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // Japan: ja-JP locale, Asia/Tokyo timezone
            jpRow.value = d.toLocaleString("ja-JP", {
                timeZone: "Asia/Tokyo",
                month: "short",
                day: "numeric",
                weekday: "short",
                hour: "2-digit",
                minute: "2-digit",
                hour12: false
            });

            // China: zh-CN locale, Asia/Shanghai timezone
            cnRow.value = d.toLocaleString("zh-CN", {
                timeZone: "Asia/Shanghai",
                month: "short",
                day: "numeric",
                weekday: "short",
                hour: "2-digit",
                minute: "2-digit",
                hour12: false
            });

            // US: en-US locale, America/New_York timezone
            usRow.value = d.toLocaleString("en-US", {
                timeZone: "America/New_York",
                month: "short",
                day: "numeric",
                weekday: "short",
                hour: "2-digit",
                minute: "2-digit",
                hour12: true
            });
        }
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

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
            icon: "preferences-system-time-symbolic"
            label: "日本 (Tokyo):"
            value: ""
        }

        StyledPopupValueRow {
            id: cnRow
            icon: "preferences-system-time-symbolic"
            label: "中国 (Beijing):"
            value: ""
        }

        StyledPopupValueRow {
            id: usRow
            icon: "preferences-system-time-symbolic"
            label: "美国 (New York):"
            value: ""
        }
    }
}
